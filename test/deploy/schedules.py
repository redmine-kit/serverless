"""Checks the events that EventBridge Scheduler sends to redmine-task in
infra/instance.yaml (docs/tasks.md#scheduled-runs): each Input is a command
event that the handler accepts (image/handler.rb: rake or runner, env names
in ALLOWED_ENV), rake tasks take their parameters as upper-case environment
variables, never rake's bracket arguments (AGENTS.md of the organization,
"Rake tasks"), and the plugins' prune tasks get DAYS from the RecordsDays
parameter (retention.recordsDays). Prints each problem; prints nothing when
the template matches. Run by test/deploy/run.sh with python3.13 of the tools
image, whose ruamel.yaml reads the CloudFormation tags."""
import json
import re
import sys

from ruamel.yaml import YAML

template = YAML(typ='rt').load(open(sys.argv[1]))
handler = open(sys.argv[2]).read()
allowed_env = set(re.search(r'ALLOWED_ENV = %w\[([^\]]*)\]', handler).group(1).split())
SAMPLE = '90'
PRUNE = {'redmine_kit:aws:ses:prune', 'redmine_kit:aws:sqs:prune'}
problems = []
pruned = set()

for name, resource in template['Resources'].items():
    if resource['Type'] != 'AWS::Scheduler::Schedule':
        continue
    target = resource['Properties']['Target']
    arn = target['Arn']
    if not (getattr(arn, 'tag', None) is not None and arn.tag.value == '!GetAtt' and arn.value == 'Task.Arn'):
        continue
    raw = target['Input']
    substituted = getattr(raw, 'tag', None) is not None and raw.tag.value == '!Sub'
    text = str(raw.value if hasattr(raw, 'value') else raw)
    parameters = set(re.findall(r'\$\{(\w+)\}', text))
    try:
        event = json.loads(re.sub(r'\$\{\w+\}', SAMPLE, text))
    except json.JSONDecodeError as error:
        problems.append(f'{name}: Input is not JSON ({error})')
        continue
    if event.get('command') not in ('rake', 'runner'):
        problems.append(f"{name}: command is {event.get('command')!r}, not rake or runner")
    args = event.get('args', [])
    env = event.get('env', {})
    unknown = set(env) - allowed_env
    if unknown:
        problems.append(f'{name}: env {sorted(unknown)} not in the handler\'s ALLOWED_ENV')
    if event.get('command') == 'rake':
        for arg in args:
            if '[' in arg:
                problems.append(f'{name}: {arg} takes bracket arguments; pass an upper-case environment variable')
            if '=' in arg:
                problems.append(f'{name}: {arg} sets a variable in args; pass it in env')
    for task in PRUNE.intersection(args):
        pruned.add(task)
        if not (substituted and env.get('DAYS') == SAMPLE and parameters == {'RecordsDays'}):
            problems.append(f'{name}: {task} does not get DAYS from ${{RecordsDays}}')

for task in sorted(PRUNE - pruned):
    problems.append(f'no schedule runs {task}')

for problem in problems:
    print(problem)
