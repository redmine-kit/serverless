"""Checks the environment of the three functions in infra/instance.yaml:
each has REDMINE_LAMBDA_IMAGE set to the ImageUri parameter (the digest URI that
bin/deploy passes), which redmine_kit_aws_lambda shows on the Status tab; the
web and worker functions have REDMINE_KIT_PDF_LAMBDA_FUNCTION set to the
PdfFunctionArn parameter (redmine_kit_pdf's renderer), the task none.
Prints each problem; prints nothing when the template matches. Run by
test/deploy/run.sh with python3.13 of the tools image, whose ruamel.yaml
reads the CloudFormation tags."""
import sys

from ruamel.yaml import YAML

template = YAML(typ='rt').load(open(sys.argv[1]))
problems = []

for name in ('Web', 'Worker', 'Task'):
    variables = template['Resources'][name]['Properties']['Environment']['Variables']
    image = variables.get('REDMINE_LAMBDA_IMAGE')
    if not (getattr(image, 'tag', None) is not None and image.tag.value == '!Ref' and image.value == 'ImageUri'):
        problems.append(f'{name}: REDMINE_LAMBDA_IMAGE is {image!r}, not !Ref ImageUri')

for name in ('Web', 'Worker'):
    pdf = template['Resources'][name]['Properties']['Environment']['Variables'].get('REDMINE_KIT_PDF_LAMBDA_FUNCTION')
    if not (getattr(pdf, 'tag', None) is not None and pdf.tag.value == '!Ref' and pdf.value == 'PdfFunctionArn'):
        problems.append(f'{name}: REDMINE_KIT_PDF_LAMBDA_FUNCTION is {pdf!r}, not !Ref PdfFunctionArn')
if 'REDMINE_KIT_PDF_LAMBDA_FUNCTION' in template['Resources']['Task']['Properties']['Environment']['Variables']:
    problems.append('Task: REDMINE_KIT_PDF_LAMBDA_FUNCTION is set, but the task makes no PDF')

for problem in problems:
    print(problem)
