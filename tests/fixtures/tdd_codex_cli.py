#!__PYTHON__
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, __TESTS__)
from test_tdd_review_check import Worker

CALLS = Path(__CALLS__)
MODE = os.environ.get('TDD_CODEX_FIXTURE_MODE', 'success')


def log(kind, **fields):
    with CALLS.open('a') as output:
        output.write(json.dumps({'kind': kind, 'pid': os.getpid(), **fields}) + '\n')


def send(message):
    print(json.dumps(message), flush=True)
    log('sent', message=message)


def safe_status(name='configured'):
    return {
        'name': name,
        'authStatus': 'unsupported',
        'runtimeStatus': 'disabled',
        'tools': {},
        'resources': [],
        'resourceTemplates': [],
    }


def flood_preflight_output():
    for _ in range(16):
        print('x' * 65536, flush=True)
    log('flood-complete')
    time.sleep(10)


args = sys.argv[1:]
plugins_disabled = 'features.plugins=false' in args
log('command', args=args)
if args == ['--version']:
    if MODE == 'oversized-version-output':
        flood_preflight_output()
    else:
        print('codex-cli 9.0.0' if MODE == 'unsupported-version' else 'codex-cli 0.164.0')
    sys.exit(0)
if args == ['mcp', 'list', '--json']:
    if MODE == 'mcp-malformed':
        print('not json')
    elif MODE == 'mcp-nonzero':
        print('[]')
        sys.exit(7)
    elif MODE == 'unsafe-server-name':
        print(json.dumps([{'name': 'bad"; injected=true'}]))
    elif MODE == 'oversized-mcp-output':
        flood_preflight_output()
    else:
        print(json.dumps([{'name': 'configured'}, {'name': 'local_tools'}]))
    sys.exit(0)

if not args or args[0] != 'app-server':
    print('unexpected command', file=sys.stderr)
    sys.exit(11)
if MODE == 'app-nonzero':
    print('fixture app-server failed', file=sys.stderr)
    sys.exit(9)
if MODE == 'app-eof':
    sys.exit(0)
if MODE == 'app-stall':
    time.sleep(10)

status_calls = 0
for raw in sys.stdin:
    if MODE == 'app-malformed':
        print('not json', flush=True)
        sys.exit(0)
    request = json.loads(raw)
    log('request', request=request)
    method = request.get('method')
    request_id = request.get('id')
    if method == 'initialized':
        continue
    if MODE == 'rpc-error':
        send({'id': request_id, 'error': {'message': 'fixture protocol error'}})
        continue
    if method == 'initialize':
        send({'id': request_id, 'result': {}})
        continue
    if method == 'thread/start':
        thread = {'id': 'thread-safe', 'ephemeral': True, 'environments': []}
        if MODE == 'thread-missing-environments':
            thread.pop('environments')
        elif MODE == 'thread-unsafe-environments':
            thread['environments'] = [{'id': 'outside'}]
        sandbox = {'type': 'readOnly', 'networkAccess': False}
        if MODE == 'thread-unsafe-sandbox':
            sandbox = {'type': 'workspaceWrite', 'networkAccess': False}
        approval = 'on-request' if MODE == 'thread-unsafe-approval' else 'never'
        send({'id': request_id, 'result': {
            'thread': thread, 'sandbox': sandbox, 'approvalPolicy': approval,
        }})
        continue
    if method == 'mcpServerStatus/list':
        status_calls += 1
        if MODE == 'mcp-missing-metadata':
            data = [{'name': 'configured'}]
        elif MODE == 'mcp-active':
            data = [{**safe_status(), 'runtimeStatus': 'connected'}]
        elif MODE == 'mcp-tools':
            data = [{**safe_status(), 'tools': {'read_file': {'name': 'read_file'}}}]
        elif MODE == 'mcp-paginated-active' and status_calls == 1:
            send({'id': request_id, 'result': {'data': [safe_status()], 'nextCursor': 'page-2'}})
            continue
        elif MODE == 'mcp-paginated-active':
            data = [{**safe_status('later'), 'runtimeStatus': 'connected'}]
        else:
            data = [safe_status(), safe_status('local_tools')]
            if not plugins_disabled:
                data.append({**safe_status('plugin_tools'), 'runtimeStatus': 'connected'})
        send({'id': request_id, 'result': {'data': data, 'nextCursor': None}})
        if MODE == 'app-block-turn-input':
            time.sleep(10)
            log('turn-input-unblocked')
        continue
    if method == 'turn/start':
        params = request['params']
        thread_id = params['threadId']
        turn_id = 'turn-' + str(len([1 for _ in CALLS.read_text().splitlines() if 'turn/start' in _]))
        if MODE == 'server-request':
            send({'id': 'server-request', 'method': 'mcpServer/tool/call', 'params': {
                'server': 'configured', 'tool': 'read_file', 'threadId': thread_id,
            }})
            sys.exit(0)
        if MODE == 'tool-event':
            send({'method': 'item/started', 'params': {
                'threadId': thread_id, 'turnId': turn_id,
                'item': {'id': 'tool-1', 'type': 'mcpToolCall', 'server': 'configured', 'tool': 'read_file'},
            }})
            sys.exit(0)
        prompt = params['input'][0]['text']
        protocol_request = json.loads(prompt.rsplit('\n', 1)[-1])
        output = Worker()(protocol_request)
        completed_thread = 'other-thread' if MODE == 'wrong-thread' else thread_id
        completed_turn = 'other-turn' if MODE == 'wrong-turn' else turn_id
        status = 'failed' if MODE == 'failed-turn' else 'completed'
        items = [] if MODE == 'failed-turn' else [{
            'id': 'message-' + turn_id, 'type': 'agentMessage', 'text': json.dumps(output),
        }]
        if MODE == 'missing-thread-item':
            send({'method': 'item/completed', 'params': {
                'turnId': turn_id,
                'item': {'id': 'reasoning-' + turn_id, 'type': 'reasoning'},
            }})
        completion_params = {'threadId': completed_thread, 'turn': {
            'id': completed_turn, 'status': status, 'items': items,
        }}
        if MODE == 'missing-thread-turn':
            completion_params.pop('threadId')
        send({'method': 'turn/completed', 'params': completion_params})
        send({'id': request_id, 'result': {'turn': {
            'id': turn_id, 'status': 'inProgress', 'items': [],
        }}})
        continue
    send({'id': request_id, 'error': {'message': 'unexpected method'}})
