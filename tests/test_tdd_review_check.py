"""Protocol tests, not evidence that AI reviews are semantically correct."""
import copy
import importlib.machinery
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import pytest

ROOT = Path(__file__).resolve().parents[1]
CODEX_CLI_TEMPLATE = ROOT / 'tests/fixtures/tdd_codex_cli.py'
loader = importlib.machinery.SourceFileLoader('tdd_review_check', str(ROOT / 'bin/tdd-review-check'))
spec = importlib.util.spec_from_loader(loader.name, loader)
review = importlib.util.module_from_spec(spec)
loader.exec_module(review)


def case(identifier, refs):
    return dict(id=identifier, given='empty cart', when='add one item', then='one item exists',
                failure='invalid quantity rejected', evidence=refs)


class Worker:
    def __init__(self):
        self.inputs = []

    def __call__(self, request):
        self.inputs.append(copy.deepcopy(request))
        result = {k: request[k] for k in ('schema_version', 'run_id', 'snapshot_digest', 'phase', 'view', 'input_digest')}
        prefix = request['phase'] + ':' + request['view']
        result['unknowns'] = []
        if request['phase'] in ('derive', 'expectations'):
            result['items'] = [case(prefix + ':1', ['requirements'])]
        elif request['phase'] == 'review':
            result['rationale'] = 'Checked quantity assertions against requirements, including invalid quantity.'
            result['reviewed'] = [x['id'] for x in request['candidates']]
            result['items'] = [dict(id=prefix + ':1', kind='oracle', refs=[request['candidates'][0]['id']],
                                    detail='Check quantity independently', evidence=['requirements'])]
        else:
            result['items'] = [case(prefix + ':1', ['requirements'])]
            result['dispositions'] = [dict(ref=x['id'], status='accepted', reason='Covered by selected case',
                                          test_ids=[prefix + ':1']) for x in request['all_items']]
        return result


def setup(tmp_path):
    source = tmp_path / 'source.py'
    source.write_text('def count(cart): return len(cart)\n')
    bundle = tmp_path / 'bundle.json'
    bundle.write_text(json.dumps({'requirements': 'Adding an item increases the cart count.', 'sources': ['source.py']}))
    return bundle


def schema_request(phase):
    return {'schema_version': review.VERSION, 'run_id': 'run', 'snapshot_digest': 'snapshot',
            'phase': phase, 'view': 'contract', 'input_digest': 'input'}


@pytest.fixture
def claude_cli(tmp_path, monkeypatch):
    executable = tmp_path / 'bin/claude'
    executable.parent.mkdir()
    calls = tmp_path / 'cli-calls.jsonl'
    executable.write_text(
        f'#!{sys.executable}\n'
        'import json, sys\n'
        'from pathlib import Path\n'
        f'sys.path.insert(0, {str(ROOT / "tests")!r})\n'
        'from test_tdd_review_check import Worker\n'
        'request = json.loads(sys.stdin.read().splitlines()[-1])\n'
        f'with Path({str(calls)!r}).open("a") as log:\n'
        '    log.write(json.dumps({"args": sys.argv[1:], "phase": request["phase"]}) + "\\n")\n'
        'print(json.dumps({"structured_output": Worker()(request)}))\n'
    )
    executable.chmod(0o755)
    monkeypatch.setenv('PATH', str(executable.parent) + os.pathsep + os.environ['PATH'])
    return executable, calls


@pytest.fixture
def codex_cli(tmp_path, monkeypatch):
    executable = tmp_path / 'bin/codex'
    executable.parent.mkdir()
    calls = tmp_path / 'codex-calls.jsonl'
    executable.write_text(CODEX_CLI_TEMPLATE.read_text().replace('__PYTHON__', sys.executable)
                          .replace('__TESTS__', repr(str(ROOT / 'tests')))
                          .replace('__CALLS__', repr(str(calls))))
    executable.chmod(0o755)
    monkeypatch.setenv('PATH', str(executable.parent) + os.pathsep + os.environ['PATH'])
    monkeypatch.delenv('TDD_CODEX_FIXTURE_MODE', raising=False)
    monkeypatch.setattr(review, 'latest_codex', lambda directory: (str(executable),
        {'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest()}))
    return executable, calls


def codex_entries(calls):
    return [json.loads(line) for line in calls.read_text().splitlines()]


def codex_requests(calls):
    return [entry for entry in codex_entries(calls) if entry['kind'] == 'request']


def assert_restricted_app_server(args):
    assert '--strict-config' in args
    assert '--ignore-user-config' not in args
    assert '--ignore-rules' not in args
    assert '--disable-hooks' not in args
    assert 'features.hooks=false' not in args
    assert 'agents.enabled=false' in args
    assert 'features.multi_agent_v2=false' in args
    assert 'mcp_servers.configured={command="false",enabled=false}' in args
    assert 'mcp_servers.local_tools={command="false",enabled=false}' in args
    for feature in ('apps', 'browser_use', 'image_generation', 'view_image', 'tool_suggest',
                    'sleep_tool', 'in_app_browser', 'plugins'):
        assert f'features.{feature}=false' in args


def assert_blind_turn(turn, index):
    params = turn['params']
    assert params['threadId'] == 'thread-safe'
    assert params['environments'] == []
    request = json.loads(params['input'][0]['text'].rsplit('\n', 1)[-1])
    assert params['outputSchema'] == review.codex_response_schema(request)
    if index < 6:
        assert 'candidates' not in request and 'all_items' not in request
        assert 'expectations' not in request


class TestCodexCliAdapter:
    def test_codex_starts_fresh_restricted_app_servers_per_phase(self, tmp_path, monkeypatch, codex_cli):
        _, calls = codex_cli
        resolver = review.latest_codex
        resolutions = []
        def resolve_once(directory):
            resolutions.append(directory)
            return resolver(directory)
        monkeypatch.setattr(review, 'latest_codex', resolve_once)

        ready = review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert ready['procedural_status'] == 'ready'
        assert len(resolutions) == 1 and not resolutions[0].exists()
        assert review.verify(setup(tmp_path), tmp_path / 'out') == ready
        entries = codex_entries(calls)
        commands = [entry for entry in entries if entry['kind'] == 'command']
        app_servers = [entry for entry in commands if entry['args'][0] == 'app-server']
        assert len(app_servers) == 10
        assert len({entry['pid'] for entry in app_servers}) == 10
        for app_server in app_servers:
            sent = [entry['message'] for entry in entries
                    if entry['kind'] == 'sent' and entry['pid'] == app_server['pid']]
            completion = next(index for index, message in enumerate(sent)
                              if message.get('method') == 'turn/completed')
            turn_reply = next(index for index, message in enumerate(sent)
                              if 'turn' in message.get('result', {}))
            assert completion < turn_reply
        for entry in app_servers:
            assert_restricted_app_server(entry['args'])

    def test_codex_turn_payloads_are_blind_and_schema_constrained(self, tmp_path, codex_cli):
        _, calls = codex_cli

        ready = review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert ready['procedural_status'] == 'ready'
        requests = codex_requests(calls)
        starts = [entry['request'] for entry in requests if entry['request']['method'] == 'thread/start']
        turns = [entry['request'] for entry in requests if entry['request']['method'] == 'turn/start']
        assert len(starts) == len(turns) == 10
        assert all(start['params']['ephemeral'] is True for start in starts)
        assert all(start['params']['environments'] == [] for start in starts)
        assert all(start['params']['approvalPolicy'] == 'never' for start in starts)
        assert all(start['params']['sandbox'] == 'read-only' for start in starts)
        for index, turn in enumerate(turns):
            assert_blind_turn(turn, index)

    @pytest.mark.parametrize('mode', [
        'thread-missing-environments', 'thread-unsafe-environments',
        'thread-unsafe-sandbox', 'thread-unsafe-approval',
    ])
    def test_unsafe_or_unverified_thread_echo_blocks_before_model_turn(self, tmp_path, monkeypatch, codex_cli, mode):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', mode)

        with pytest.raises(ValueError):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        methods = [entry['request']['method'] for entry in codex_requests(calls)]
        assert 'thread/start' in methods
        assert 'turn/start' not in methods
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('mode', [
        'mcp-missing-metadata', 'mcp-active', 'mcp-tools', 'mcp-paginated-active',
    ])
    def test_unknown_or_live_mcp_metadata_blocks_before_model_turn(self, tmp_path, monkeypatch, codex_cli, mode):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', mode)

        with pytest.raises(ValueError):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        requests = [entry['request'] for entry in codex_requests(calls)]
        mcp_pages = [request for request in requests if request['method'] == 'mcpServerStatus/list']
        assert mcp_pages
        if mode == 'mcp-paginated-active':
            assert len(mcp_pages) == 2
            assert mcp_pages[1]['params']['cursor'] == 'page-2'
        assert not any(request['method'] == 'turn/start' for request in requests)

    def test_rejects_unsafe_mcp_server_name_before_starting_app_server(self, tmp_path, monkeypatch, codex_cli):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', 'unsafe-server-name')

        with pytest.raises(ValueError):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        commands = [entry['args'] for entry in (json.loads(line) for line in calls.read_text().splitlines())
                    if entry['kind'] == 'command']
        assert commands == [['--version'], ['mcp', 'list', '--json']]

    def test_new_cli_version_uses_runtime_boundary_checks(self, tmp_path, monkeypatch, codex_cli):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', 'unsupported-version')
        ready = review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))
        assert ready['procedural_status'] == 'ready'
        assert any(entry['request']['method'] == 'thread/start' for entry in codex_requests(calls))

    @pytest.mark.parametrize('mode', ['oversized-version-output', 'oversized-mcp-output'])
    def test_preflight_output_limit_terminates_child_before_flood_finishes(self, tmp_path, monkeypatch, codex_cli, mode):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', mode)
        launches = []
        original = review.subprocess.Popen

        def record(*args, **kwargs):
            process = original(*args, **kwargs)
            launches.append((process, kwargs))
            return process

        monkeypatch.setattr(review.subprocess, 'Popen', record)
        with pytest.raises(ValueError, match='preflight output too large'):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert launches and all(process.poll() is not None for process, _ in launches)
        assert all(kwargs['stderr'] is review.subprocess.DEVNULL for _, kwargs in launches)
        assert 'flood-complete' not in {entry['kind'] for entry in codex_entries(calls)}
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('mode', ['mcp-malformed', 'mcp-nonzero', 'app-eof', 'app-nonzero', 'app-malformed', 'rpc-error'])
    def test_malformed_eof_nonzero_and_protocol_errors_fail_closed(self, tmp_path, monkeypatch, codex_cli, mode):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', mode)

        with pytest.raises((ValueError, OSError, RuntimeError, json.JSONDecodeError)):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert calls.exists()
        assert not (tmp_path / 'out/ready.json').exists()

    def test_stalled_phase_times_out_and_reaps_its_process(self, tmp_path, monkeypatch, codex_cli):
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', 'app-stall')
        monkeypatch.setattr(review, 'PHASE_TIMEOUT', 0.1)
        processes = []
        original = review.subprocess.Popen
        def record(*args, **kwargs):
            process = original(*args, **kwargs)
            processes.append(process)
            return process
        monkeypatch.setattr(review.subprocess, 'Popen', record)

        with pytest.raises(ValueError, match='timed out'):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert all(process.poll() is not None for process in processes)
        assert not (tmp_path / 'out/ready.json').exists()

    def test_large_turn_input_respects_phase_deadline_when_app_server_stops_reading(self, tmp_path, monkeypatch, codex_cli):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', 'app-block-turn-input')
        monkeypatch.setattr(review, 'GUIDANCE', 'x' * (review.LIMIT // 2))
        monkeypatch.setattr(review, 'PHASE_TIMEOUT', 0.2)
        processes = []
        original = review.subprocess.Popen

        def record(*args, **kwargs):
            process = original(*args, **kwargs)
            processes.append(process)
            return process

        monkeypatch.setattr(review.subprocess, 'Popen', record)
        with pytest.raises(ValueError, match='timed out'):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert processes and all(process.poll() is not None for process in processes)
        assert 'turn-input-unblocked' not in {entry['kind'] for entry in codex_entries(calls)}
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('mode', ['server-request', 'tool-event'])
    def test_server_requests_and_tool_events_fail_closed(self, tmp_path, monkeypatch, codex_cli, mode):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', mode)

        with pytest.raises(ValueError):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        requests = [entry['request'] for entry in codex_requests(calls)]
        assert any(request['method'] == 'turn/start' for request in requests)
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('mode', ['failed-turn', 'wrong-thread', 'wrong-turn'])
    def test_failed_or_wrong_provenance_completion_is_not_accepted(self, tmp_path, monkeypatch, codex_cli, mode):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', mode)

        with pytest.raises(ValueError):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert any(entry['request']['method'] == 'turn/start' for entry in codex_requests(calls))
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('mode', ['missing-thread-turn', 'missing-thread-item'])
    def test_completion_lifecycle_event_requires_thread_provenance(self, tmp_path, monkeypatch, codex_cli, mode):
        _, calls = codex_cli
        monkeypatch.setenv('TDD_CODEX_FIXTURE_MODE', mode)

        with pytest.raises(ValueError, match='thread'):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))

        assert any(entry['request']['method'] == 'turn/start' for entry in codex_requests(calls))
        assert not (tmp_path / 'out/ready.json').exists()

    def test_release_failure_never_falls_back_to_claude(self, tmp_path, monkeypatch, claude_cli):
        _, calls = claude_cli
        def unavailable(directory):
            raise OSError('official release unavailable')
        monkeypatch.setattr(review, 'latest_codex', unavailable)
        with pytest.raises(OSError):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('codex'))
        assert not calls.exists()
        assert not (tmp_path / 'out/ready.json').exists()


class TestCodexResponseSchema:
    @pytest.mark.parametrize('phase', ['derive', 'expectations', 'review', 'integrate'])
    def test_every_codex_value_has_an_explicit_native_schema_type(self, phase):
        request = schema_request(phase)
        schema = review.codex_response_schema(request)

        def check_value(node):
            if 'anyOf' in node:
                for choice in node['anyOf']:
                    check_value(choice)
                return
            assert node.get('type') in {'string', 'integer', 'number', 'boolean', 'object', 'array', 'null'}
            for child in node.get('properties', {}).values():
                check_value(child)
            if 'items' in node:
                check_value(node['items'])

        check_value(schema)
        for name in ('schema_version', 'run_id', 'snapshot_digest', 'phase', 'view', 'input_digest'):
            field = schema['properties'][name]
            assert field['const'] == request[name]
            assert field['type'] == ('integer' if name == 'schema_version' else 'string')
            assert review.response_schema(request)['properties'][name] == {'const': request[name]}

    @pytest.mark.parametrize('phase, names', [
        ('derive', ('id', 'given', 'when', 'then', 'failure')),
        ('expectations', ('id', 'given', 'when', 'then', 'failure')),
        ('integrate', ('id', 'given', 'when', 'then', 'failure')),
    ])
    @pytest.mark.parametrize(('text', 'valid'), [
        ('', False), (' \t\n', False), ('observable outcome', True), ('  observable outcome  ', True),
    ])
    def test_contract_text_patterns_reject_only_blank_text(self, phase, names, text, valid):
        fields = review.codex_response_schema(schema_request(phase))['properties']['items']['items']['properties']
        assert all(bool(re.search(fields[name]['pattern'], text)) is valid for name in names)

    @pytest.mark.parametrize(('text', 'valid'), [
        ('', False), ('\n ', False), ('review rationale', True),
    ])
    def test_review_text_patterns_reject_only_blank_text(self, text, valid):
        schema = review.codex_response_schema(schema_request('review'))
        fields = schema['properties']['items']['items']['properties']
        patterns = (fields['id']['pattern'], fields['detail']['pattern'], schema['properties']['rationale']['pattern'])
        assert all(bool(re.search(pattern, text)) is valid for pattern in patterns)

    @pytest.mark.parametrize(('text', 'valid'), [
        ('', False), ('\t', False), ('preserves the original concern', True),
    ])
    def test_every_integrate_status_requires_nonblank_reason(self, text, valid):
        choices = review.codex_response_schema(schema_request('integrate'))['properties']['dispositions']['items']['anyOf']
        assert {choice['properties']['status']['enum'][0] for choice in choices} == {'accepted', 'rejected', 'deferred'}
        assert all(bool(re.search(choice['properties']['reason']['pattern'], text)) is valid for choice in choices)

    def test_codex_nonblank_patterns_do_not_leak_to_opaque_references_or_claude(self):
        codex_review = review.codex_response_schema(schema_request('review'))['properties']
        codex_integrate = review.codex_response_schema(schema_request('integrate'))['properties']
        review_item = codex_review['items']['items']['properties']
        dispositions = codex_integrate['dispositions']['items']['anyOf']
        opaque = [review_item['evidence']['items'], review_item['refs']['items'], codex_review['reviewed']['items'],
                  *[choice['properties']['ref'] for choice in dispositions],
                  *[choice['properties']['test_ids']['items'] for choice in dispositions]]
        claude_fields = review.response_schema(schema_request('expectations'))['properties']['items']['items']['properties']
        assert all(field.get('type') == 'string' and 'pattern' not in field for field in opaque)
        assert all('pattern' not in field for field in claude_fields.values())


class TestReviewPipeline:
    def test_blind_phases_then_complete_integration(self, tmp_path):
        worker = Worker()
        result = review.run(setup(tmp_path), tmp_path / 'out', worker)
        assert result['procedural_status'] == 'ready'
        assert len(worker.inputs) == 10
        for request in worker.inputs[:6]:
            assert 'candidates' not in request and 'all_items' not in request
            assert 'expectations' not in request
        for request in worker.inputs[6:9]:
            assert len(request['candidates']) == 3
            assert len(request['expectations']) == 1
        assert (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('fault', ['stale', 'duplicate', 'unknown_ref', 'missing_disposition', 'unknown', 'missing_review', 'malformed', 'cli_failure'])
    def test_fails_closed_and_keeps_evidence(self, tmp_path, fault):
        worker = Worker()
        def broken(request):
            result = worker(request)
            if fault == 'cli_failure':
                raise RuntimeError('CLI failed')
            if fault == 'stale':
                result['snapshot_digest'] = 'old'
            elif fault == 'duplicate':
                result['items'] *= 2
            elif fault == 'unknown_ref':
                result['items'][0]['evidence'] = ['missing']
            elif fault == 'unknown':
                result['unknowns'] = ['Unclear quantity contract']
            elif fault == 'malformed':
                return []
            elif fault == 'missing_review' and request['phase'] == 'review':
                result['reviewed'] = []
            elif fault == 'missing_disposition' and request['phase'] == 'integrate':
                result['dispositions'].pop()
            return result
        with pytest.raises((ValueError, RuntimeError)):
            review.run(setup(tmp_path), tmp_path / 'out', broken)
        assert not (tmp_path / 'out/ready.json').exists()
        assert (tmp_path / 'out/error.json').exists()

    def test_snapshot_change_blocks_release(self, tmp_path):
        worker = Worker()
        bundle = setup(tmp_path)
        def changed(request):
            result = worker(request)
            if request['phase'] == 'integrate':
                (tmp_path / 'source.py').write_text('changed')
            return result
        with pytest.raises(ValueError, match='snapshot'):
            review.run(bundle, tmp_path / 'out', changed)
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('views', [[], ['contract'], ['a', 'a', 'b'], ['a', 'b', 'c', 'd', 'e', 'f']])
    def test_requires_three_to_five_distinct_views(self, tmp_path, views):
        with pytest.raises(ValueError):
            review.run(setup(tmp_path), tmp_path / 'out', Worker(), views=views)

    def test_never_reuses_existing_output_directory(self, tmp_path):
        bundle = setup(tmp_path)
        review.run(bundle, tmp_path / 'out', Worker())
        with pytest.raises(FileExistsError):
            review.run(bundle, tmp_path / 'out', Worker())

    def test_codex_factory_identifies_its_own_runtime(self):
        worker = review.cli_worker('codex')
        try:
            assert worker.runtime == 'codex'
        finally:
            worker.close()

class TestCliBoundary:
    def test_claude_is_fresh_toolless_and_not_in_project(self, tmp_path, monkeypatch):
        calls = []
        def fake(command, **kwargs):
            calls.append((command, kwargs))
            request = json.loads(kwargs['input'].split('\n')[-1])
            assert Path(kwargs['cwd']) != tmp_path
            assert list(Path(kwargs['cwd']).iterdir()) == []
            class Result:
                returncode = 0
                stderr = ''
                stdout = json.dumps({'structured_output': Worker()(request)})
            return Result()
        monkeypatch.setattr(review.subprocess, 'run', fake)
        review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('claude'))
        for command, _ in calls:
            assert command[command.index('--tools') + 1] == ''
            assert command[command.index('--disallowedTools') + 1] == 'mcp__*'
            assert '--no-session-persistence' in command
            assert not {'--resume', '--continue', '--fork-session', '--dangerously-skip-permissions'} & set(command)

    def test_failed_cli_does_not_reach_next_phase(self, tmp_path, monkeypatch):
        calls = []
        def fake(*args, **kwargs):
            calls.append(args)
            class Result:
                returncode = 1
                stderr = 'unsupported flag'
                stdout = '{}'
            return Result()
        monkeypatch.setattr(review.subprocess, 'run', fake)
        with pytest.raises(ValueError, match='CLI failed'):
            review.run(setup(tmp_path), tmp_path / 'out', review.cli_worker('claude'))
        assert len(calls) == 1

    @pytest.mark.parametrize('path', ['../outside', '/absolute', '.env', 'secret.txt'])
    def test_rejects_unsafe_sources(self, tmp_path, path):
        bundle = tmp_path / 'bundle.json'
        bundle.write_text(json.dumps({'requirements': 'contract', 'sources': [path]}))
        with pytest.raises(ValueError):
            review.run(bundle, tmp_path / 'out', Worker())

    def test_rejects_symlink_source(self, tmp_path):
        bundle = setup(tmp_path)
        (tmp_path / 'source.py').unlink()
        (tmp_path / 'source.py').symlink_to('/etc/hostname')
        with pytest.raises(ValueError, match='symlink'):
            review.run(bundle, tmp_path / 'out', Worker())

    @pytest.mark.parametrize('source', [
        'client.pem', 'client.key', 'client.pem/', 'client.key/',
        'client.PEM//', 'keys/client.KEY///',
        'secret-dir/source.py/', 'credential-dir/source.py/',
    ])
    def test_rejects_secret_extensions_before_read_or_dispatch(self, tmp_path, source):
        target = tmp_path / source.rstrip('/')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('synthetic private-key fixture')
        bundle = tmp_path / 'bundle.json'
        bundle.write_text(json.dumps({'requirements': 'contract', 'sources': [source]}))
        worker = Worker()

        with pytest.raises(ValueError, match='secret-bearing path'):
            review.run(bundle, tmp_path / 'out', worker)

        assert worker.inputs == []
        assert not (tmp_path / 'out/snapshot.json').exists()
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize('source', ['source.py', 'src/source.py', 'src//source.py'])
    def test_preserves_safe_relative_source_ids(self, tmp_path, source):
        target = tmp_path / source
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('def count(cart): return len(cart)\n')
        bundle = tmp_path / 'bundle.json'
        bundle.write_text(json.dumps({'requirements': 'contract', 'sources': [source]}))

        ready = review.run(bundle, tmp_path / 'out', Worker())

        assert review.verify(bundle, tmp_path / 'out') == ready
        frozen = json.loads((tmp_path / 'out/snapshot.json').read_text())
        assert frozen['sources'] == [dict(id=source, content=target.read_text(),
                                          digest=review.digest(target.read_text()))]


class TestCliCommands:
    def test_run_then_verify_through_cli(self, tmp_path, claude_cli):
        _, calls = claude_cli
        bundle = setup(tmp_path)
        output = tmp_path / 'out'
        command = [str(ROOT / 'bin/tdd-review-check')]

        result = subprocess.run(command + ['run', '--bundle', str(bundle), '--output', str(output),
                                          '--runtime', 'claude'], capture_output=True, text=True, timeout=30)
        verified = subprocess.run(command + ['verify', '--bundle', str(bundle), '--output', str(output)],
                                  capture_output=True, text=True, timeout=30)

        assert result.returncode == verified.returncode == 0, result.stderr + verified.stderr
        ready = json.loads((output / 'ready.json').read_text())
        assert json.loads(result.stdout) == json.loads(verified.stdout) == {
            'run_id': ready['run_id'], 'procedural_status': 'ready'}
        invocations = [json.loads(line) for line in calls.read_text().splitlines()]
        assert [call['phase'] for call in invocations] == (
            ['derive'] * 3 + ['expectations'] * 3 + ['review'] * 3 + ['integrate'])
        for call in invocations:
            assert call['args'][call['args'].index('--tools') + 1] == ''
            assert call['args'][call['args'].index('--disallowedTools') + 1] == 'mcp__*'
            assert '--no-session-persistence' in call['args']

    def test_rejects_secret_alias_before_starting_cli(self, tmp_path, claude_cli):
        _, calls = claude_cli
        (tmp_path / 'client.pem').write_text('synthetic private-key fixture')
        bundle = tmp_path / 'bundle.json'
        bundle.write_text(json.dumps({'requirements': 'contract', 'sources': ['client.pem/']}))

        result = subprocess.run([str(ROOT / 'bin/tdd-review-check'), 'run', '--bundle', str(bundle),
                                 '--output', str(tmp_path / 'out'), '--runtime', 'claude'],
                                capture_output=True, text=True, timeout=30)

        assert result.returncode == 2
        assert result.stdout == ''
        assert 'secret-bearing path' in result.stderr
        assert not calls.exists()
        assert not (tmp_path / 'out/snapshot.json').exists()
        assert not (tmp_path / 'out/ready.json').exists()

    @pytest.mark.parametrize(('stdout', 'exit_code', 'error'), [
        ('{}', 1, 'CLI failed (exit 1)'),
        ('not json', 0, 'Expecting value'),
        ('{"is_error": true}', 0, 'CLI reported an error'),
        ('{}', 0, 'CLI did not return structured_output'),
    ])
    def test_cli_failure_blocks_following_phases(self, tmp_path, claude_cli, stdout, exit_code, error):
        executable, _ = claude_cli
        executable.write_text(f'#!{sys.executable}\nimport sys\nprint({stdout!r})\nsys.exit({exit_code})\n')

        result = subprocess.run([str(ROOT / 'bin/tdd-review-check'), 'run', '--bundle', str(setup(tmp_path)),
                                 '--output', str(tmp_path / 'out'), '--runtime', 'claude'],
                                capture_output=True, text=True, timeout=30)

        assert result.returncode == 2
        assert result.stdout == ''
        assert error in result.stderr
        assert json.loads((tmp_path / 'out/error.json').read_text())['procedural_status'] == 'blocked'
        assert not (tmp_path / 'out/expectations-contract.input.json').exists()
        assert not (tmp_path / 'out/ready.json').exists()


class TestConsumedResult:
    def test_verify_rechecks_snapshot_and_complete_protocol(self, tmp_path):
        bundle = setup(tmp_path)
        ready = review.run(bundle, tmp_path / 'out', Worker())
        assert review.verify(bundle, tmp_path / 'out') == ready
        (tmp_path / 'source.py').write_text('new source')
        with pytest.raises(ValueError, match='snapshot'):
            review.verify(bundle, tmp_path / 'out')

    def test_verify_rejects_replaced_result(self, tmp_path):
        bundle = setup(tmp_path)
        review.run(bundle, tmp_path / 'out', Worker())
        path = tmp_path / 'out/ready.json'
        result = json.loads(path.read_text())
        result['tests'][0]['then'] = 'silently weaken assertion'
        path.write_text(json.dumps(result))
        with pytest.raises(ValueError, match='ready'):
            review.verify(bundle, tmp_path / 'out')

class TestReviewEvidence:
    def test_rejected_items_cannot_support_selected_tests(self, tmp_path):
        worker = Worker()
        def reject_all(request):
            result = worker(request)
            if request['phase'] == 'integrate':
                for disposition in result['dispositions']:
                    disposition['status'] = 'rejected'
            return result
        with pytest.raises(ValueError, match='rejected'):
            review.run(setup(tmp_path), tmp_path / 'out', reject_all)

    def test_zero_findings_still_requires_review_rationale(self, tmp_path):
        worker = Worker()
        def omit_rationale(request):
            result = worker(request)
            if request['phase'] == 'review':
                result['items'] = []
                result['rationale'] = ''
            return result
        with pytest.raises(ValueError, match='rationale'):
            review.run(setup(tmp_path), tmp_path / 'out', omit_rationale)

    def test_strict_isolation_request_fails_before_invoking_cli(self, tmp_path):
        result = review.subprocess.run([str(ROOT / 'bin/tdd-review-check'), 'run', '--bundle',
                                       str(setup(tmp_path)), '--output', str(tmp_path / 'out'),
                                       '--runtime', 'claude', '--require-strict-isolation'],
                                      capture_output=True, text=True)
        assert result.returncode == 2
        assert 'strict isolation is not established' in result.stderr
        assert not (tmp_path / 'out').exists()

class TestWorkflowIntegration:
    def test_codex_adapter_opt_in_does_not_disable_basic_tdd(self):
        skill = (ROOT / 'common/skills/tdd/SKILL.md').read_text()
        assert 'explicit opt-in' in skill
        assert '通常の TDD' in skill and 'runner を必須にしない' in skill
        assert 'basic TDD へ黙って降格しない' in skill
        agent = (ROOT / 'codex/agents/test_analyst.toml').read_text()
        assert 'sandbox_mode' not in agent
        for relative in ('claude/agents/test-writer.md', 'codex/agents/test_writer.toml'):
            writer = (ROOT / relative).read_text()
            assert 'mode を明示選択した TDD' in writer
            assert '通常の basic TDD' in writer


class TestKnownOracleFixtures:
    """Execute weak/strong fixtures; this does NOT evaluate model review accuracy."""
    @staticmethod
    def correct(items):
        return tuple(items) + ('apple',)

    @staticmethod
    def faulty(items):
        return tuple(items)

    def test_weak_oracle_passes_faulty_implementation(self):
        # Merely checking the container exists misses a dropped insertion.
        assert self.faulty(()) is not None

    def test_strong_oracle_distinguishes_known_fault(self):
        assert self.correct(()) == ('apple',)
        with pytest.raises(AssertionError):
            assert self.faulty(()) == ('apple',)

    def test_representation_assumption_rejects_correct_behavior(self):
        # Contract promises an iterable, not a particular internal container type.
        with pytest.raises(AssertionError):
            assert isinstance(self.correct(()), list)
        assert list(self.correct(())) == ['apple']

class TestLatestCodexRelease:
    @pytest.mark.parametrize('fault', [None, 'digest', 'missing-digest', 'url', 'symlink', 'prerelease'])
    def test_only_verified_official_regular_executable_is_published(self, tmp_path, monkeypatch, fault):
        import io
        import tarfile
        payload = b'synthetic executable, never invoked'
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w:gz') as archive:
            entry = tarfile.TarInfo('codex-x86_64-unknown-linux-musl')
            entry.size = len(payload)
            if fault == 'symlink':
                entry.type = tarfile.SYMTYPE
                entry.linkname = '/outside'
            archive.addfile(entry, io.BytesIO(payload))
        packed = stream.getvalue()
        url = 'https://github.com/openai/codex/releases/download/rust-v99.0.0/codex-x86_64-unknown-linux-musl.tar.gz'
        metadata = {'tag_name': 'rust-v99.0.0', 'draft': False, 'prerelease': fault == 'prerelease', 'assets': [{
            'name': 'codex-x86_64-unknown-linux-musl.tar.gz', 'size': len(packed),
            'digest': None if fault == 'missing-digest' else 'sha256:' + ('0' * 64 if fault == 'digest' else hashlib.sha256(packed).hexdigest()),
            'browser_download_url': 'https://example.com/untrusted' if fault == 'url' else url}]}
        calls = []
        def download(address, target, limit):
            calls.append(address)
            target.write_bytes(json.dumps(metadata).encode() if address.endswith('/latest') else packed)
        monkeypatch.setattr(review, 'release_download', download)
        monkeypatch.setattr(review.platform, 'system', lambda: 'Linux')
        monkeypatch.setattr(review.platform, 'machine', lambda: 'x86_64')
        if fault:
            with pytest.raises(ValueError):
                review.latest_codex(tmp_path)
            assert not (tmp_path / 'codex').exists()
        else:
            executable, provenance = review.latest_codex(tmp_path)
            assert Path(executable).read_bytes() == payload
            assert Path(executable).stat().st_mode & 0o777 == 0o700
            assert provenance['release'] == 'rust-v99.0.0'
            assert provenance['executable_sha256'] == hashlib.sha256(payload).hexdigest()
            assert calls == ['https://api.github.com/repos/openai/codex/releases/latest', url]

    def test_changed_binary_blocks_next_phase_and_cleans_release(self, tmp_path, monkeypatch, codex_cli):
        executable, calls = codex_cli
        worker = review.CodexWorker()
        original = review.CodexServer.close
        def tamper(server):
            original(server)
            executable.write_text('tampered executable')
        monkeypatch.setattr(review.CodexServer, 'close', tamper)
        with pytest.raises(ValueError, match='executable changed'):
            review.run(setup(tmp_path), tmp_path / 'out', worker)
        assert len([entry for entry in codex_entries(calls) if entry['kind'] == 'command' and entry['args'][0] == 'app-server']) == 1
        assert not (tmp_path / 'out/ready.json').exists()

class TestPythonRuntime:
    def test_old_python_requests_upgrade_before_touching_inputs(self, tmp_path, monkeypatch, capsys):
        monkeypatch.setattr(review.sys, 'version_info', (3, 13, 0))
        monkeypatch.setattr(review.sys, 'argv', ['tdd-review-check', 'run', '--bundle', 'missing', '--runtime', 'codex', '--output', str(tmp_path / 'out')])
        assert review.main() == 2
        assert 'Python 3.14' in capsys.readouterr().err
        assert not (tmp_path / 'out').exists()

class TestReleaseLifecycle:
    def test_worker_does_not_allocate_release_directory_until_invocation(self, monkeypatch):
        def unexpected(**kwargs):
            pytest.fail('release directory created before input validation')
        monkeypatch.setattr(review.tempfile, 'TemporaryDirectory', unexpected)
        worker = review.CodexWorker()
        worker.close()

    def test_cleanup_failure_blocks_readiness(self, tmp_path):
        class FailedCleanup(Worker):
            def close(self):
                raise OSError('synthetic cleanup error')
        with pytest.raises(OSError, match='cleanup'):
            review.run(setup(tmp_path), tmp_path / 'out', FailedCleanup())
        assert not (tmp_path / 'out/ready.json').exists()
        assert json.loads((tmp_path / 'out/error.json').read_text())['procedural_status'] == 'blocked'

    def test_download_deadline_is_checked_between_partial_reads(self, tmp_path, monkeypatch):
        clock = [0]
        reads = []
        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read1(self, size):
                reads.append(size)
                clock[0] += 100
                return b'x'
        monkeypatch.setattr(review.time, 'monotonic', lambda: clock[0])
        monkeypatch.setattr(review.urllib.request, 'urlopen', lambda *args, **kwargs: Response())
        with pytest.raises(ValueError, match='time limit'):
            review.release_download('https://example.com/synthetic', tmp_path / 'archive', 10)
        assert len(reads) == 2
        assert (tmp_path / 'archive').read_bytes() == b'x'
