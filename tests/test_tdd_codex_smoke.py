"""Offline checks of smoke evidence classification, not live CLI evidence."""
import importlib.util
import json
from pathlib import Path

import pytest


SCRIPT = Path(__file__).with_name('smoke_tdd_codex.py')
spec = importlib.util.spec_from_file_location('smoke_tdd_codex', SCRIPT)
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class TestDenialEvidence:
    @pytest.mark.parametrize('items', [
        [],
        [{'type': 'agentMessage', 'name': 'apply_patch',
          'output': 'No usable execution environment is available.'}],
        [{'type': 'functionCallOutput', 'name': 'other',
          'output': 'No usable execution environment is available.'}],
    ])
    def test_refusal_or_unrelated_tool_is_not_denial_evidence(self, items):
        assert smoke.denial_status(items, 'apply_patch') == 'skipped'

    def test_runtime_tool_output_confirms_denial(self):
        items = [{'type': 'functionCallOutput', 'name': 'apply_patch', 'output':
                  'No usable execution environment is available. Wait for an environment to become available before using this tool.'}]
        assert smoke.denial_status(items, 'apply_patch') == 'passed'

    @pytest.mark.parametrize('output', [
        'Done.', 'permission denied', None,
        'Process exited with code 0\nFinal output: No usable execution environment is available.',
        [{'type': 'text', 'text': 'No usable execution environment is available.'}],
    ])
    def test_other_results_do_not_prove_environment_denial(self, output):
        items = [{'type': 'functionCallOutput', 'name': 'apply_patch', 'output': output}]
        assert smoke.denial_status(items, 'apply_patch') == 'failed'

    def test_one_denial_does_not_hide_another_success(self):
        denial = ('No usable execution environment is available. '
                  'Wait for an environment to become available before using this tool.')
        items = [{'type': 'functionCallOutput', 'name': 'apply_patch', 'output': output}
                 for output in (denial, 'Done.')]
        assert smoke.denial_status(items, 'apply_patch') == 'failed'


class TestFaultEvidence:
    def test_unrelated_send_failure_is_not_successful_fault_injection(self, tmp_path, monkeypatch):
        output = tmp_path / 'failure'
        output.mkdir()
        (output / 'error.json').write_text(json.dumps({'procedural_status': 'blocked'}))
        (output / 'derive-contract.input.json').write_text('{}')

        def failed_send(*args):
            smoke.ObservedServer.records = [{'turns': [{}], 'reaped': True}]
            raise BrokenPipeError('unrelated broken pipe before kill')

        monkeypatch.setattr(smoke.review, 'run', failed_send)
        with pytest.raises(AssertionError, match='fault not injected'):
            smoke.process_failure(output)
