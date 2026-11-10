"""Checks the cache behaviors of the distribution in infra/instance.yaml
against the decisions in docs/lambda.md: within the 5 behaviors of the Free
flat-rate plan, and /favicons/* (the favicon of Redmine 7.1) cached from
Redmine without cookies, a body or the body-hash function. Prints each
problem; prints nothing when the template matches. Run by test/deploy/run.sh
with python3.13 of the tools image, whose ruamel.yaml reads the
CloudFormation tags."""
import sys

from ruamel.yaml import YAML

CACHING_OPTIMIZED = '658327ea-f89d-4fab-a63d-7e88639e58f6'
SECURITY_HEADERS = '67f7725c-6f97-4210-82d7-5512b31e9d03'

template = YAML(typ='rt').load(open(sys.argv[1]))
config = template['Resources']['Distribution']['Properties']['DistributionConfig']
behaviors = {b['PathPattern']: b for b in config['CacheBehaviors']}
problems = []

if len(behaviors) + 1 > 5:
    problems.append(f'{len(behaviors) + 1} cache behaviors with the default one; the Free plan allows 5')

favicons = behaviors.get('/favicons/*')
if favicons is None:
    problems.append('no /favicons/* behavior')
else:
    expected = {
        'TargetOriginId': 'redmine',
        'ViewerProtocolPolicy': 'redirect-to-https',
        'AllowedMethods': ['GET', 'HEAD'],
        'CachedMethods': ['GET', 'HEAD'],
        'CachePolicyId': CACHING_OPTIMIZED,
        'ResponseHeadersPolicyId': SECURITY_HEADERS,
    }
    for key, value in expected.items():
        actual = favicons.get(key)
        if (list(actual) if isinstance(value, list) and actual is not None else actual) != value:
            problems.append(f'/favicons/*: {key} is {actual}, not {value}')
    for key in ('OriginRequestPolicyId', 'LambdaFunctionAssociations', 'FunctionAssociations', 'TrustedKeyGroups'):
        if key in favicons:
            problems.append(f'/favicons/*: {key} is set')

for problem in problems:
    print(problem)
