"""Checks the cache behaviors and the Redmine origin of the distribution in
infra/instance.yaml against the decisions in docs/lambda.md: within the 5
behaviors of the Free flat-rate plan, /favicons/* (the favicon of Redmine
7.1) cached from Redmine without cookies, a body or the body-hash function,
and the origin custom headers that give Redmine its domain and scheme
(X-Forwarded-Host with the Domain parameter, X-Forwarded-Proto https), which
replace headers of the same names sent by the viewer. Prints each problem;
prints nothing when the template matches. Run by test/deploy/run.sh
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

# The function URL, behind the default behavior and /favicons/*.
origins = {o['Id']: o for o in config['Origins']}
redmine = origins.get('redmine', {})
headers = {h['HeaderName'].lower(): h['HeaderValue'] for h in redmine.get('OriginCustomHeaders', [])}
host = headers.get('x-forwarded-host')
if not (getattr(host, 'tag', None) is not None and host.tag.value == '!Ref' and host.value == 'Domain'):
    problems.append(f'redmine origin: X-Forwarded-Host is {host!r}, not !Ref Domain')
if headers.get('x-forwarded-proto') != 'https':
    problems.append(f"redmine origin: X-Forwarded-Proto is {headers.get('x-forwarded-proto')!r}, not https")

for problem in problems:
    print(problem)
