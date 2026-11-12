"""Checks the mail bucket permissions of the roles in infra/instance.yaml that
import email: redmine-task (received email and re-imports with
redmine_aws_ses:receive_mail MESSAGE_ID=…) and redmine-worker ("Fetch again"
on the "Email receiving" tab). They read both inbound/ and processed/, where
redmine_aws_ses looks for a message, write processed/ and delete in inbound/
only (MailBucket#move_to_processed), and nothing more. Prints each problem; prints nothing when
the template matches. Run by test/deploy/run.sh with python3.13 of the tools
image, whose ruamel.yaml reads the CloudFormation tags."""
import sys

from ruamel.yaml import YAML

template = YAML(typ='rt').load(open(sys.argv[1]))
problems = []


def as_list(value):
    return list(value) if isinstance(value, list) else [value]


def allowed(role, action):
    """The resources of the role's inline policies that allow the action, as
    the strings of their !Sub tags."""
    resources = set()
    for policy in template['Resources'][role]['Properties'].get('Policies', []):
        for statement in policy['PolicyDocument']['Statement']:
            if statement['Effect'] == 'Allow' and action in as_list(statement['Action']):
                resources.update(getattr(resource, 'value', resource)
                                 for resource in as_list(statement['Resource']))
    return resources


# The prefixes of the mail bucket that each action must be allowed on, exactly.
EXPECTED = {
    's3:GetObject': {'inbound', 'processed'},
    's3:PutObject': {'processed'},
    's3:DeleteObject': {'inbound'},
}

for role in ('TaskRole', 'WorkerRole'):
    for action, prefixes in EXPECTED.items():
        expected = {f'${{MailBucket.Arn}}/{prefix}/*' for prefix in prefixes}
        actual = {resource for resource in allowed(role, action)
                  if isinstance(resource, str) and resource.startswith('${MailBucket.Arn}')}
        if actual != expected:
            problems.append(f'{role}: {action} is allowed on {sorted(actual)}, not {sorted(expected)}')

for problem in problems:
    print(problem)
