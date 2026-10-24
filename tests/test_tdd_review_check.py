"""Protocol tests, not evidence that AI reviews are semantically correct."""
import copy
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

import pytest

ROOT = Path(__file__).resolve().parents[1]
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

    def test_codex_without_read_isolation_is_blocked(self):
        with pytest.raises(ValueError, match='isolation'):
            review.cli_worker('codex')

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

    def test_unsupported_codex_never_starts_claude(self, tmp_path, claude_cli):
        _, calls = claude_cli

        result = subprocess.run([str(ROOT / 'bin/tdd-review-check'), 'run', '--bundle', str(setup(tmp_path)),
                                 '--output', str(tmp_path / 'out'), '--runtime', 'codex'],
                                capture_output=True, text=True, timeout=30)

        assert result.returncode == 2
        assert result.stdout == ''
        assert 'no fallback is selected' in result.stderr
        assert not calls.exists()
        assert not (tmp_path / 'out').exists()

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
    def test_unsupported_codex_does_not_disable_basic_tdd(self):
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
