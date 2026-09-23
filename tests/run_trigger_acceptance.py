"""Opt-in live Codex acceptance; not part of verify.sh or ordinary unit tests."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / 'tests/trigger-acceptance-2026-09-23.json'
OUTPUT = ROOT / '.tmp/advisor-trigger'


def prepare(case):
    workspace = OUTPUT / case['id']
    workspace.mkdir(parents=True, exist_ok=True)
    (workspace / 'uart.c').write_text('unsigned baud(unsigned clock, unsigned divisor) { return clock / (16u * divisor); }\n', encoding='utf-8')
    (workspace / 'config.py').write_text('TIMEOUT_MS = 100\n', encoding='utf-8')
    (workspace / 'sample.py').write_text('def value():\n    total = 0\n    for i in range(4):\n        total += i\n    return total\n', encoding='utf-8')
    for name in ('parser_a', 'parser_b'):
        (workspace / f'{name}.py').write_text('def parse(values):\n    return values[len(values)] if values else None\n', encoding='utf-8')
    (workspace / 'protocol.txt').write_text('READY + timeout -> RETRY; RETRY + ack -> DONE; send acknowledgement at most once per tick.\n', encoding='utf-8')
    (workspace / 'communication.c').write_text('int step(int state,int timeout,int ack){if(state==1 && timeout)return 3;if(state==2 && ack)return 3;return state;}\n', encoding='utf-8')
    (workspace / 'retry.c').write_text('void tick(int timeout,int retry){if(timeout)send_ack();if(retry)send_ack();}\n', encoding='utf-8')
    (workspace / 'init.c').write_text('/* BOOT-17: regulator readiness is required before peripheral initialization. */\nint init(int ready){return ready ? 0 : -17;}\n', encoding='utf-8')
    for n in range(3):
        lines = [f'{i:06d} module{n} OK ready=1' for i in range(2000)]
        if n != 1:
            lines[733] = '000733 module0 INIT_FAIL code=-17 ready=0'
        (workspace / f'boot{n}.log').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    (workspace / 'queue.log').write_text('received=1000 consumed=1000 dropped=0 max_depth=3 capacity=64\n', encoding='utf-8')
    (workspace / 'filters.txt').write_text('required CAN ID=0x321; configured ID=0x320 mask=0x7FF\n', encoding='utf-8')
    for n in range(5):
        (workspace / f'interface{n}.txt').write_text('\n'.join(f'fn_{n}_{i}(uint8 input) -> uint16 output' for i in range(300)), encoding='utf-8')
    (workspace / 'producer.py').write_text('def encode(value):\n    return value.to_bytes(2, "little")\n', encoding='utf-8')
    (workspace / 'consumer.py').write_text('def decode(data):\n    assert len(data) == 1\n    return data[0]\n', encoding='utf-8')
    (workspace / 'states.txt').write_text('READY->RUN on start; RUN->RETRY on timeout; any state->CANCEL on cancel; recover currently returns CANCEL->RUN. Module A permits retry, B treats CANCEL as terminal, C publishes RUN while recovery pending.\n', encoding='utf-8')
    if case['id'] in ('T13', 'T14', 'T16'):
        policy = workspace / '.agent/authorizations.json'
        policy.parent.mkdir(exist_ok=True)
        policy.write_text('{invalid' if case['id']=='T16' else json.dumps({'schemaVersion':1,'authorizations':{'solAdvisor':{'implicitDelegation':False}}}), encoding='utf-8')
    return workspace


def run(case):
    workspace = prepare(case)
    prompt = case['prompt']
    additions = {
        'T01': '文件是 uart.c，核对 clock=16000000, divisor=10 的结果。',
        'T02': '日志为 boot0.log、boot1.log、boot2.log，源码为 init.c。',
        'T03': '协议在 protocol.txt，状态机在 communication.c，独立配置表在 filters.txt。',
        'T04': '补丁实现是 retry.c。',
        'T05': '证据为 queue.log 和 filters.txt。',
        'T06': '文件为 parser_a.py 和 parser_b.py；约定非空列表返回最后一项，空列表返回 None；可用 Python 执行断言。',
        'T07': '文件为 interface0.txt 至 interface4.txt，输出到 interfaces.csv。',
        'T10': '三条文案是：提交、失败、重试。',
        'T11': '函数在 sample.py。',
        'T12': '日志为 boot0.log 和 boot2.log。',
        'T13': '日志为 boot0.log 至 boot2.log，源码为 init.c。',
        'T14': '日志为 boot0.log 和 boot2.log。',
        'T15': '实现为 producer.py、consumer.py，规格要求双字节小端无符号整数。',
        'T16': '实现为 producer.py、consumer.py，规格要求双字节小端无符号整数。',
        'T17': '仅允许指定不存在的角色 sol_advisor_missing_probe；如果不可用，请明确告知并自行只读核对 init.c。',
        'T18': '实现为 producer.py、consumer.py；分别安排有界调查并交换证据。',
        'T19': '已知约束在 states.txt，先列出矛盾和不能确定的接口语义，不改实现。',
        'T21': '本任务没有已有代理：先派一个 Scout 只读检查 producer.py，完成后续派同一代理检查 consumer.py，最后综合结论。',
    }
    prompt += '\n' + additions.get(case['id'],'')
    prompt += '\n仅处理当前工作目录内的样例；不构建、不操作硬件、不安装、不修改全局配置、不联网检索。'
    cmd = [shutil.which('codex.cmd') or shutil.which('codex'), '--no-daemon','-a','never','exec','--ephemeral','--json','-s','workspace-write','-m','gpt-6-sol','-c','model_reasoning_effort=medium','-C',str(workspace),'--skip-git-repo-check','-']
    if case.get('v2'):
        cmd[1:1]=['--enable','multi_agent_v2']
    started=time.time()
    label=case.get('run_label','')
    prefix=case['id'] + ('.'+label if label else '')
    events=OUTPUT/f"{prefix}.events.jsonl"
    errors=OUTPUT/f"{prefix}.stderr.txt"
    with events.open('w',encoding='utf-8') as out, errors.open('w',encoding='utf-8') as err:
        proc=subprocess.run(cmd,input=prompt,encoding='utf-8',stdout=out,stderr=err)
    record={'id':case['id'],'exitCode':proc.returncode,'seconds':round(time.time()-started,1),'events':str(events),'stderr':str(errors),'status':'EXECUTED_REQUIRES_EVENT_REVIEW'}
    (OUTPUT/f"{prefix}.run.json").write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(record,ensure_ascii=False),flush=True)
    return record


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases',nargs='+',required=True)
    parser.add_argument('--jobs',type=int,choices=(1,2),default=1)
    parser.add_argument('--label',default='')
    parser.add_argument('--v2',action='store_true')
    args=parser.parse_args()
    cases={x['id']:x for x in json.loads(PLAN.read_text(encoding='utf-8'))['cases']}
    selected=[{**cases[x],'run_label':args.label,'v2':args.v2} for x in args.cases]
    if args.jobs==1:
        for case in selected:
            if run(case)['exitCode'] != 0:
                raise SystemExit('Live runtime failure; stopping remaining cases.')
    else:
        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(run,selected))
