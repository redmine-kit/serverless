"""Checks the environment of the three functions in infra/instance.yaml:
each has REDMINE_IMAGE set to the ImageUri parameter (the digest URI that
bin/deploy passes), which redmine_aws_lambda shows on the Status tab.
Prints each problem; prints nothing when the template matches. Run by
test/deploy/run.sh with python3.13 of the tools image, whose ruamel.yaml
reads the CloudFormation tags."""
import sys

from ruamel.yaml import YAML

template = YAML(typ='rt').load(open(sys.argv[1]))
problems = []

for name in ('Web', 'Worker', 'Task'):
    variables = template['Resources'][name]['Properties']['Environment']['Variables']
    image = variables.get('REDMINE_IMAGE')
    if not (getattr(image, 'tag', None) is not None and image.tag.value == '!Ref' and image.value == 'ImageUri'):
        problems.append(f'{name}: REDMINE_IMAGE is {image!r}, not !Ref ImageUri')

for problem in problems:
    print(problem)
