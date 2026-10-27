#!/usr/bin/env python3
"""Explicit real-Codex smoke; never collected by pytest or run by default CI."""
from __future__ import annotations

import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
import hashlib
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shlex
import signal
import socket
import subprocess
import sys
import tempfile
import tarfile
from unittest.mock import patch
import uuid


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'tests/fixtures/tdd_codex_smoke/bundle.json'
loader = importlib.machinery.SourceFileLoader('smoke_review_adapter', str(ROOT / 'bin/tdd-review-check'))
spec = importlib.util.spec_from_loader(loader.name, loader)
review = importlib.util.module_from_spec(spec)
loader.exec_module(review)
FAILURES = (AssertionError, ValueError, OSError, RuntimeError, KeyError, TypeError, subprocess.TimeoutExpired, tarfile.TarError)
DENIAL = ('No usable execution environment is available. '
          'Wait for an environment to become available before using this tool.')
LIVE_CHECKS = ('pipeline', 'io_read_process_network', 'io_write', 'process_failure')


def denial_status(items: list, tool: str) -> str:
    outputs = [item.get('output') for item in items
               if item.get('type') == 'functionCallOutput' and item.get('name') == tool]
    if not outputs:
        return 'skipped'
    return 'passed' if all(output == DENIAL for output in outputs) else 'failed'


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


class ObservedServer(review.CodexServer):
    """Observe the actual adapter transport, without replacing CLI responses."""

    records: list = []

    def __init__(self, command: list, directory: str) -> None:
        super().__init__(command, directory)
        self.record = {'pid': self.process.pid, 'turns': [], 'mcp': [], 'completed': []}
        self.records.append(self.record)

    def send(self, message: dict) -> None:
        if message.get('method') == 'turn/start':
            params = message['params']
            request = json.loads(params['input'][0]['text'].rsplit('\n', 1)[-1])
            self.record['turns'].append(request)
        super().send(message)

    def receive(self) -> dict:
        message = super().receive()
        if message.get('method') == 'turn/completed':
            self.record['completed'].append(message['params']['turn']['status'])
        return message

    def rpc(self, method: str, params: dict) -> dict:
        result = super().rpc(method, params)
        if method == 'thread/start':
            self.record['thread'] = result
        if method == 'mcpServerStatus/list':
            self.record['mcp'].extend(result['data'])
        return result

    def close(self) -> None:
        super().close()
        self.record['reaped'] = self.process.poll() is not None


def pipeline(output: Path) -> dict:
    ObservedServer.records = []
    with patch.object(review, 'CodexServer', ObservedServer):
        ready = review.run(FIXTURE, output, review.cli_worker('codex'))
    check(review.verify(FIXTURE, output) == ready, 'verify differs from ready')
    records = ObservedServer.records
    expected = [(phase, view) for phase in ('derive', 'expectations', 'review') for view in review.VIEWS]
    expected.append(('integrate', 'combined'))
    check(len(records) == len({record['pid'] for record in records}) == 10, 'phase processes not independent')
    check(len({record['thread']['thread']['id'] for record in records}) == 10, 'threads were reused')
    for record, (phase, view) in zip(records, expected):
        check(len(record['turns']) == 1, 'phase did not have exactly one turn')
        request = record['turns'][0]
        check((request['phase'], request['view']) == (phase, view), 'phase order differs')
        saved = review.read_json(output / f'{phase}-{view}.input.json')
        check(request == saved, 'actual wire disclosure differs from verified input')
        check(record['completed'] == ['completed'] and record['reaped'], 'turn/cleanup incomplete')
        check_mcp_canary(record['mcp'])
    # Keep metadata, not native diagnostics or model text, in the shareable report.
    return {'processes': [{'pid': record['pid'], 'thread_id': record['thread']['thread']['id'],
                          'phase': request['phase'], 'view': request['view'],
                          'input_digest': request['input_digest'], 'payload_keys': sorted(request),
                          'turn_status': record['completed'][0], 'reaped': record['reaped'],
                          'mcp_canary': 'disabled-empty'}
                         for record in records for request in record['turns']],
            'ready_and_verify': True}


def check_mcp_canary(servers: list) -> None:
    canary = [server for server in servers if server['name'] == 'smoke_canary']
    check(len(canary) == 1 and canary[0]['runtimeStatus'] == 'disabled'
          and canary[0]['tools'] == {} and canary[0]['resources'] == []
          and canary[0]['resourceTemplates'] == [], 'configured MCP canary not demonstrably disabled')


def boundary_preflight(command: list) -> dict:
    ObservedServer.records = []
    with tempfile.TemporaryDirectory(prefix='tdd-smoke-preflight-') as directory:
        server = ObservedServer(command, directory)
        try:
            server.start(directory)
        finally:
            server.close()
    record = server.record
    check(record['reaped'] and not record['turns'], 'preflight cleanup failed or model turn started')
    check_mcp_canary(record['mcp'])
    return {'pid': record['pid'], 'thread_id': server.thread_id,
            'ephemeral': record['thread']['thread']['ephemeral'],
            'environments': record['thread']['thread']['environments'],
            'sandbox': record['thread']['sandbox'], 'approval_policy': record['thread']['approvalPolicy'],
            'mcp_canary': 'disabled-empty', 'model_turns': 0, 'reaped': True}


class ProbeServer(review.CodexServer):
    """Only the diagnostic probe observes handler rejection beyond the normal guard."""

    def notice(self, message: dict) -> None:
        params = message.get('params', {})
        if message.get('method') in ('item/started', 'item/completed'):
            item = params.get('item', {})
            if item.get('type') == 'functionCallOutput':
                check(params.get('threadId') == self.thread_id, 'foreign probe tool output')
                if message['method'] == 'item/completed':
                    self.events.append(message)
                    check(len(review.encoded(self.events).encode()) <= review.LIMIT, 'probe output too large')
                return
        super().notice(message)


def probe_turn(command: list, prompt: str) -> list:
    with tempfile.TemporaryDirectory(prefix='tdd-smoke-probe-') as directory:
        server = ProbeServer(command, directory)
        try:
            server.start(directory)
            started = server.rpc('turn/start', {'threadId': server.thread_id, 'environments': [],
                                                'input': [{'type': 'text', 'text': prompt}]})
            turn_id = started['turn']['id']
            while not any(event.get('method') == 'turn/completed' for event in server.events):
                server.notice(server.receive())
            completed = [event['params']['turn'] for event in server.events if event['method'] == 'turn/completed']
            check(len(completed) == 1 and completed[0]['id'] == turn_id
                  and completed[0]['status'] == 'completed' and not completed[0].get('error'), 'probe turn incomplete')
            streamed = [event['params']['item'] for event in server.events if event['method'] == 'item/completed']
            check(all(event['params'].get('turnId') == turn_id for event in server.events
                      if event['method'] == 'item/completed'), 'foreign probe turn output')
            return completed[0].get('items', []) + streamed
        finally:
            server.close()


def io_probes(command: list, directory: Path) -> dict:
    canary = directory / 'outside.txt'
    token = 'synthetic-' + uuid.uuid4().hex
    canary.write_text(token)
    process_marker = directory / 'process-started'
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        listener.listen(1)
        listener.setblocking(False)
        code = (f'from pathlib import Path; import socket; print(Path({str(canary)!r}).read_text()); '
                f'Path({str(process_marker)!r}).touch(); '
                f'socket.create_connection(("127.0.0.1", {listener.getsockname()[1]}), timeout=1).close()')
        command_text = shlex.join([sys.executable, '-c', code])
        prompts = {
            'io_read_process_network': ('exec_command', 'Call exec_command once with this exact command: ' + command_text),
            'io_write': ('apply_patch', 'Call apply_patch once with this exact patch:\n*** Begin Patch\n'
                         f'*** Update File: {canary}\n@@\n-{token}\n+synthetic-changed\n*** End Patch'),
        }
        results = {}
        for name, (tool, instruction) in prompts.items():
            # Synthetic targets only; production flags and environment checks stay intact.
            try:
                items = probe_turn(command, 'This is a disposable I/O boundary test. ' + instruction
                                   + '\nDo not retry, use other tools, or access other targets. Report the result briefly.')
                status = denial_status(items, tool)
                results[name] = {'status': status, 'tool': tool,
                                 'detail': 'runtime denial observed' if status == 'passed' else
                                           'no matching runtime denial; unexercised tools are unverified'}
                if name == 'io_read_process_network':
                    check(token not in review.encoded(items), 'outside canary was disclosed')
            except FAILURES as error:
                results[name] = {'status': 'failed', 'detail': str(error)}
        connected = False
        try:
            connection, _ = listener.accept()
        except BlockingIOError:
            pass
        else:
            connection.close()
            connected = True
        unchanged = canary.is_file() and canary.read_text() == token and not process_marker.exists() and not connected
        for result in results.values():
            result['canaries_unchanged'] = unchanged
            if not unchanged:
                result.update(status='failed', detail='synthetic file/process/network side effect observed')
        return results


def process_failure(output: Path) -> dict:
    class InterruptedServer(ObservedServer):
        def send(self, message: dict) -> None:
            super().send(message)
            if message.get('method') == 'turn/start':
                check(self.process.poll() is None, 'app-server exited before fault injection')
                self.process.kill()
                self.process.wait(timeout=5)
                self.record['fault_injected'] = self.process.returncode == -signal.SIGKILL
    ObservedServer.records = []
    try:
        with patch.object(review, 'CodexServer', InterruptedServer):
            review.run(FIXTURE, output, review.cli_worker('codex'))
    except FAILURES:
        records = ObservedServer.records
        check(len(records) == 1 and len(records[0]['turns']) == 1 and records[0]['reaped']
              and records[0].get('fault_injected') is True, 'fault not injected/reaped')
        check(review.read_json(output / 'error.json')['procedural_status'] == 'blocked', 'missing blocked result')
        check(not (output / 'ready.json').exists() and len(list(output.glob('*.input.json'))) == 1,
              'failure released readiness or reached later phases')
        return {'interrupted_after_turn_send': True, 'process_reaped': True, 'later_phases': 0, 'ready': False}
    raise AssertionError('interrupted app-server did not block')


def smoke(auth_file: Path | None, output: Path, model: str | None) -> dict:
    report = {'recorded_at': datetime.now(timezone.utc).isoformat(), 'checks': {},
              'adapter_sha256': hashlib.sha256((ROOT / 'bin/tdd-review-check').read_bytes()).hexdigest(),
              'fixture_snapshot_digest': review.digest(review.snapshot(FIXTURE)),
              'scope': 'runner inputs are synthetic; no review-quality or global-isolation claim'}
    checks = report['checks']
    for name in LIVE_CHECKS:
        checks[name] = {'status': 'skipped', 'detail': 'compatible CLI and explicit authentication required'}
    with ExitStack() as stack, tempfile.TemporaryDirectory(prefix='tdd-codex-smoke-') as temporary:
        directory = Path(temporary)
        isolated_home = directory / 'home'
        isolated_home.mkdir(mode=0o700)
        marker = directory / 'mcp-started'
        mcp_script = directory / 'mcp_canary.py'
        mcp_script.write_text(f'from pathlib import Path\nPath({str(marker)!r}).touch()\n')
        config = (f'cli_auth_credentials_store = "file"\n[mcp_servers.smoke_canary]\n'
                  f'command = {json.dumps(sys.executable)}\nargs = [{json.dumps(str(mcp_script))}]\nenabled = true\n')
        if model:
            config = 'model = ' + json.dumps(model) + '\n' + config
        (isolated_home / 'config.toml').write_text(config)
        # Carry transport/proxy settings only. Never inherit user rules, projects or hooks.
        environment = {key: value for key, value in os.environ.items()
                       if key.upper().endswith('_PROXY') or key in ('SSL_CERT_FILE', 'SSL_CERT_DIR', 'SYSTEMROOT')}
        environment.update(PATH=os.defpath,
                           HOME=str(isolated_home), CODEX_HOME=str(isolated_home),
                           XDG_CONFIG_HOME=str(isolated_home / 'config'), XDG_DATA_HOME=str(isolated_home / 'data'))
        with patch.dict(os.environ, environment, clear=True):
            release_directory = directory / 'release'
            release_directory.mkdir()
            binary, provenance = review.latest_codex(release_directory)
            report['runtime'] = provenance
            report['cli_version'] = review.codex_output([binary, '--version']).strip()
            # Reuse the single resolved release for all phases, through the existing resolver seam.
            release_patch = patch.object(review, 'latest_codex', lambda unused: (binary, provenance))
            stack.enter_context(release_patch)
            if auth_file is not None:
                check(auth_file.stat().st_size <= review.LIMIT, 'authentication file too large')
                auth_copy = isolated_home / 'auth.json'
                auth_copy.touch(mode=0o600)
                auth_copy.write_bytes(auth_file.read_bytes())
            command = review.codex_command(binary)
            checks['release_integrity'] = {'status': 'passed', 'detail': 'latest official asset SHA-256 verified'}
            try:
                checks['boundary_preflight'] = {'status': 'passed', **boundary_preflight(command)}
                check(not marker.exists(), 'disabled MCP server actually launched')
                checks['mcp_canary'] = {'status': 'passed', 'detail': 'real disabled/empty status; launch marker absent'}
            except FAILURES as error:
                checks['boundary_preflight'] = {'status': 'failed', 'detail': str(error)}
                return report
            if auth_file is None:
                return report
            for name, action in (('pipeline', lambda: pipeline(output / 'pipeline')),
                                 ('process_failure', lambda: process_failure(output / 'process-failure'))):
                try:
                    checks[name] = {'status': 'passed', **action()}
                except FAILURES as error:
                    checks[name] = {'status': 'failed', 'detail': str(error)}
            checks.update(io_probes(command, directory))
            if marker.exists():
                checks['mcp_canary'] = {'status': 'failed', 'detail': 'disabled MCP server actually launched'}
            elif checks['boundary_preflight']['status'] == 'passed':
                checks['mcp_canary'] = {'status': 'passed', 'detail': 'configured MCP launch marker absent'}
            else:
                checks['mcp_canary'] = {'status': 'skipped', 'detail': 'marker absent but pipeline boundary not verified'}
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--auth-file', type=Path, help='explicit auth.json only; copied privately, never logged')
    parser.add_argument('--model', help='optional runtime model selection, not a test oracle')
    parser.add_argument('--output', type=Path, required=True, help='new directory for synthetic reports')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    try:
        report = smoke(args.auth_file, args.output, args.model)
    except FAILURES as error:
        report = {'checks': {name: {'status': 'skipped', 'detail': 'preflight did not complete'} for name in LIVE_CHECKS}}
        report['checks']['preflight'] = {'status': 'failed', 'detail': str(error)}
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    statuses = {result['status'] for result in report['checks'].values()}
    return 1 if 'failed' in statuses else 77 if 'skipped' in statuses else 0


if __name__ == '__main__':
    sys.exit(main())
