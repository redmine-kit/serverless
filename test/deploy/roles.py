"""Checks the mail bucket permissions of the roles in infra/instance.yaml that
import email: redmine-task (received email and re-imports with
redmine_aws_ses:receive_mail MESSAGE_ID=…) and redmine-worker ("Fetch again"
on the "Email receiving" tab) read both inbound/ and processed/, where
redmine_aws_ses looks for a message. Prints each problem; prints nothing when
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


for role in ('TaskRole', 'WorkerRole'):
    resources = allowed(role, 's3:GetObject')
    for prefix in ('inbound', 'processed'):
        resource = f'${{MailBucket.Arn}}/{prefix}/*'
        if resource not in resources:
            problems.append(f'{role}: s3:GetObject is not allowed on {resource}')

for problem in problems:
    print(problem)
