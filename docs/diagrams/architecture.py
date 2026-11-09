"""The AWS resources of one instance, drawn with the AWS Architecture Icons.

What is drawn follows infra/*.yaml. bin/diagrams runs this file and writes
architecture.svg (English) and architecture.ja.svg (Japanese labels).
"""

import os
import sys

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2Instance, ECR, LambdaFunction
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.engagement import SimpleEmailServiceSes
from diagrams.aws.general import Users
from diagrams.aws.integration import EventbridgeScheduler, SimpleQueueServiceSqsQueue
from diagrams.aws.management import Cloudwatch, SystemsManagerParameterStore
from diagrams.aws.network import CloudFront, Endpoint, Route53
from diagrams.aws.security import CertificateManager, Guardduty, WAF
from diagrams.aws.storage import SimpleStorageServiceS3Bucket
from diagrams.onprem.vcs import Github

LANG = sys.argv[1] if len(sys.argv) > 1 else "en"
OUT = sys.argv[2] if len(sys.argv) > 2 else "architecture"

TEXT = {
    "en": {
        "title": "",
        "functions": "Lambda functions (one image)",
        "dns_query": "DNS",
        "apis": "AWS APIs",
        "settings": "settings, secrets",
        "logs": "logs",
        "image": "image",
        "users": "Users",
        "dns": "Route 53\n(optional)",
        "cloudfront": "CloudFront",
        "edge": "us-east-1 (edge)",
        "waf": "AWS WAF",
        "acm": "Certificate\n(ACM)",
        "body_hash": "Lambda@Edge\nbody-hash",
        "region": "ap-northeast-1 (instance)",
        "vpc": "VPC",
        "private": "Private subnets",
        "public": "Public subnet",
        "web": "redmine-web\n(function URL)",
        "worker": "redmine-worker",
        "task": "redmine-task",
        "rds": "RDS for PostgreSQL",
        "nat": "NAT instance\n(network: nat)",
        "endpoints": "VPC endpoints\nS3, SSM, SES, SQS\n(network: endpoints)",
        "files": "files bucket\n(attachments)",
        "assets": "assets bucket",
        "mail": "mail bucket",
        "guardduty": "GuardDuty\nMalware Protection\n(incoming/, imports/)",
        "jobs": "SQS jobs\n(+ dead-letter)",
        "schedules": "EventBridge\nScheduler",
        "ses": "Amazon SES\n(send, receive)",
        "ssm": "SSM\nParameter Store",
        "ecr": "Amazon ECR",
        "cloudwatch": "CloudWatch\nlogs, alarms",
        "ghcr": "ghcr.io\n(published image)",
        "https": "HTTPS",
        "pages": "pages",
        "files_edge": "files, uploads",
        "scan": "scan",
        "enqueue": "jobs",
        "run": "rake",
        "mail_in": "received mail",
        "copy": "bin/deploy copies",
    },
    "ja": {
        "title": "",
        "functions": "Lambda の関数(1 つのイメージ)",
        "dns_query": "DNS",
        "apis": "AWS の API",
        "settings": "設定、秘密の値",
        "logs": "ログ",
        "image": "イメージ",
        "users": "利用者",
        "dns": "Route 53\n(任意)",
        "cloudfront": "CloudFront",
        "edge": "us-east-1(エッジ)",
        "waf": "AWS WAF",
        "acm": "証明書\n(ACM)",
        "body_hash": "Lambda@Edge\nbody-hash",
        "region": "ap-northeast-1(インスタンス)",
        "vpc": "VPC",
        "private": "プライベートのサブネット",
        "public": "パブリックのサブネット",
        "web": "redmine-web\n(関数 URL)",
        "worker": "redmine-worker",
        "task": "redmine-task",
        "rds": "RDS for PostgreSQL",
        "nat": "NAT インスタンス\n(network: nat)",
        "endpoints": "VPC エンドポイント\nS3、SSM、SES、SQS\n(network: endpoints)",
        "files": "files のバケット\n(添付ファイル)",
        "assets": "assets のバケット",
        "mail": "mail のバケット",
        "guardduty": "GuardDuty\nMalware Protection\n(incoming/、imports/)",
        "jobs": "SQS のジョブ\n(+ デッドレター)",
        "schedules": "EventBridge\nScheduler",
        "ses": "Amazon SES\n(送受信)",
        "ssm": "SSM\nParameter Store",
        "ecr": "Amazon ECR",
        "cloudwatch": "CloudWatch\nログ、アラーム",
        "ghcr": "ghcr.io\n(公開のイメージ)",
        "https": "HTTPS",
        "pages": "画面",
        "files_edge": "ファイル、アップロード",
        "scan": "スキャン",
        "enqueue": "ジョブ",
        "run": "rake",
        "mail_in": "受信したメール",
        "copy": "bin/deploy がコピー",
    },
}[LANG]

FONT = "Noto Sans CJK JP"
FUNCTIONS = "cluster_" + TEXT["functions"]

# The colors of the AWS Architecture Icons' groups.
AWS_CLOUD = {"bgcolor": "white", "pencolor": "#232F3E", "fontcolor": "#232F3E"}
REGION = {"bgcolor": "white", "pencolor": "#00A4A6", "fontcolor": "#00A4A6", "style": "dashed"}
VPC = {"bgcolor": "white", "pencolor": "#8C4FFF", "fontcolor": "#8C4FFF"}
PRIVATE = {"bgcolor": "#E6F6F7", "pencolor": "#00A4A6", "fontcolor": "#00A4A6"}
FUNCTION_GROUP = {"bgcolor": "white", "pencolor": "#ED7100", "fontcolor": "#ED7100", "style": "dashed"}
PUBLIC = {"bgcolor": "#F2F6E8", "pencolor": "#7AA116", "fontcolor": "#7AA116"}


def group(label, colors):
    return Cluster(label, graph_attr={"fontname": FONT, "fontsize": "13", "labeljust": "l", "margin": "16", **colors})


def flow(label="", **attrs):
    return Edge(label=label, color="#545B64", fontcolor="#545B64", fontname=FONT, fontsize="11", **attrs)


def from_functions(target, label="", **attrs):
    """One edge from the group of the three functions, not three edges."""
    worker >> Edge(ltail=FUNCTIONS, label=label, color="#545B64", fontcolor="#545B64", fontname=FONT,
                   fontsize="11", **attrs) >> target


with Diagram(
    TEXT["title"],
    filename=OUT,
    outformat="svg",
    show=False,
    direction="LR",
    graph_attr={"fontname": FONT, "pad": "0.3", "nodesep": "0.45", "ranksep": "1.0", "compound": "true", "splines": "spline",
                "newrank": "true"},
    node_attr={"fontname": FONT, "fontsize": "11"},
    edge_attr={"fontname": FONT},
):
    users = Users(TEXT["users"])

    with group("AWS Cloud", AWS_CLOUD):
        dns = Route53(TEXT["dns"])
        cloudfront = CloudFront(TEXT["cloudfront"])

        with group(TEXT["edge"], REGION):
            waf = WAF(TEXT["waf"])
            acm = CertificateManager(TEXT["acm"])
            body_hash = LambdaFunction(TEXT["body_hash"])

        with group(TEXT["region"], REGION):
            files = SimpleStorageServiceS3Bucket(TEXT["files"])
            assets = SimpleStorageServiceS3Bucket(TEXT["assets"])
            guardduty = Guardduty(TEXT["guardduty"])
            schedules = EventbridgeScheduler(TEXT["schedules"])
            ses = SimpleEmailServiceSes(TEXT["ses"])
            mail = SimpleStorageServiceS3Bucket(TEXT["mail"])

            with group(TEXT["vpc"], VPC):
                with group(TEXT["private"], PRIVATE):
                    with group(TEXT["functions"], FUNCTION_GROUP):
                        web = LambdaFunction(TEXT["web"])
                        worker = LambdaFunction(TEXT["worker"])
                        task = LambdaFunction(TEXT["task"])
                    rds = RDSPostgresqlInstance(TEXT["rds"])
                    endpoints = Endpoint(TEXT["endpoints"])
                with group(TEXT["public"], PUBLIC):
                    nat = EC2Instance(TEXT["nat"])

            jobs = SimpleQueueServiceSqsQueue(TEXT["jobs"])
            ssm = SystemsManagerParameterStore(TEXT["ssm"])
            ecr = ECR(TEXT["ecr"])
            cloudwatch = Cloudwatch(TEXT["cloudwatch"])

    ghcr = Github(TEXT["ghcr"])

    users >> flow(TEXT["dns_query"], style="dashed") >> dns
    users >> flow(TEXT["https"]) >> cloudfront
    cloudfront - flow(style="dotted") - waf
    cloudfront - flow(style="dotted") - acm
    cloudfront - flow(style="dotted") - body_hash
    cloudfront >> flow(TEXT["pages"]) >> web
    cloudfront >> flow(TEXT["files_edge"]) >> files
    cloudfront >> flow() >> assets
    files >> flow(TEXT["scan"]) >> guardduty
    web >> flow(TEXT["enqueue"]) >> jobs
    jobs >> flow() >> worker
    schedules >> flow(TEXT["run"]) >> task
    ses >> flow(TEXT["mail_in"]) >> mail
    ses >> flow() >> task
    from_functions(rds)
    from_functions(endpoints, TEXT["apis"])
    from_functions(nat, TEXT["apis"], style="dashed")
    from_functions(ssm, TEXT["settings"])
    from_functions(cloudwatch, TEXT["logs"])
    ghcr >> flow(TEXT["copy"]) >> ecr
    ecr >> Edge(lhead=FUNCTIONS, label=TEXT["image"], color="#545B64", fontcolor="#545B64", fontname=FONT,
                fontsize="11") >> worker
