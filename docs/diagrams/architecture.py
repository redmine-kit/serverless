"""The AWS resources of one instance, drawn with the AWS Architecture Icons.

What is drawn follows infra/*.yaml. bin/diagrams runs this file:
  python architecture.py <lang> <output name>
and writes architecture.svg (English) and architecture.ja.svg (Japanese).
Edges show the paths a reader follows: a request, an upload, a job and an
incoming mail. What every function uses (the image, settings, logs) is one
group with one edge.
"""

import sys

import diagrams
from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECR, LambdaFunction
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.engagement import SimpleEmailServiceSes
from diagrams.aws.general import Users
from diagrams.aws.integration import EventbridgeScheduler, SimpleQueueServiceSqsQueue
from diagrams.aws.management import Cloudwatch, SystemsManagerParameterStore
from diagrams.aws.network import CloudFront, Endpoint
from diagrams.aws.security import CertificateManager, Guardduty, WAF
from diagrams.aws.storage import SimpleStorageServiceS3Bucket

LANG = sys.argv[1] if len(sys.argv) > 1 else "en"
OUT = sys.argv[2] if len(sys.argv) > 2 else "architecture"

TEXT = {
    "en": {
        "users": "Users",
        "cloudfront": "CloudFront\n(Route 53 optional)",
        "edge": "us-east-1 (for CloudFront)",
        "waf": "AWS WAF",
        "acm": "ACM certificate",
        "body_hash": "Lambda@Edge\nbody-hash",
        "region": "ap-northeast-1",
        "vpc": "VPC",
        "private": "Private subnets",
        "functions": "Lambda (one image)",
        "web": "redmine-web\nfunction URL",
        "worker": "redmine-worker",
        "task": "redmine-task",
        "rds": "RDS for\nPostgreSQL",
        "network": "VPC endpoints\nor\nNAT instance",
        "files": "Attachments\nbucket",
        "assets": "Assets bucket",
        "mail": "Mail bucket",
        "guardduty": "GuardDuty\nmalware scan",
        "jobs": "SQS queue",
        "schedules": "EventBridge\nScheduler",
        "ses": "Amazon SES",
        "shared": "Used by every function",
        "ssm": "SSM\nParameter Store",
        "ecr": "ECR (image)",
        "cloudwatch": "CloudWatch",
        "https": "HTTPS",
        "pages": "pages",
        "uploads": "files",
        "assets_edge": "assets",
        "scan": "uploads",
        "enqueue": "jobs",
        "run": "rake",
        "mail_in": "mail",
    },
    "ja": {
        "users": "利用者",
        "cloudfront": "CloudFront\n(Route 53 は任意)",
        "edge": "us-east-1(CloudFront 用)",
        "waf": "AWS WAF",
        "acm": "ACM の証明書",
        "body_hash": "Lambda@Edge\nbody-hash",
        "region": "ap-northeast-1",
        "vpc": "VPC",
        "private": "プライベートサブネット",
        "functions": "Lambda(同じイメージ)",
        "web": "redmine-web\n関数 URL",
        "worker": "redmine-worker",
        "task": "redmine-task",
        "rds": "RDS for\nPostgreSQL",
        "network": "VPC エンドポイント\nまたは\nNAT インスタンス",
        "files": "添付ファイルの\nバケット",
        "assets": "アセットの\nバケット",
        "mail": "メールの\nバケット",
        "guardduty": "GuardDuty\nマルウェアスキャン",
        "jobs": "SQS のキュー",
        "schedules": "EventBridge\nScheduler",
        "ses": "Amazon SES",
        "shared": "すべての関数が使う",
        "ssm": "SSM\nParameter Store",
        "ecr": "ECR(イメージ)",
        "cloudwatch": "CloudWatch",
        "https": "HTTPS",
        "pages": "画面",
        "uploads": "ファイル",
        "assets_edge": "アセット",
        "scan": "アップロード",
        "enqueue": "ジョブ",
        "run": "rake",
        "mail_in": "メール",
    },
}[LANG]

FONT = "Noto Sans CJK JP"
FUNCTIONS = "cluster_" + TEXT["functions"]
SHARED = "cluster_" + TEXT["shared"]
GRAY = "#545B64"

# Smaller nodes than the library's default, so that the diagram stays legible
# at the width of a documentation page.
diagrams.Node._height = 1.2

# The colors of the AWS Architecture Icons' groups.
AWS_CLOUD = {"bgcolor": "white", "pencolor": "#232F3E", "fontcolor": "#232F3E"}
REGION = {"bgcolor": "white", "pencolor": "#00A4A6", "fontcolor": "#00A4A6", "style": "dashed"}
VPC = {"bgcolor": "white", "pencolor": "#8C4FFF", "fontcolor": "#8C4FFF"}
PRIVATE = {"bgcolor": "#E6F6F7", "pencolor": "#00A4A6", "fontcolor": "#00A4A6"}
FUNCTION_GROUP = {"bgcolor": "#FFFFFF", "pencolor": "#ED7100", "fontcolor": "#ED7100", "style": "dashed"}
SHARED_GROUP = {"bgcolor": "#F7F8F8", "pencolor": "#879196", "fontcolor": GRAY, "style": "dashed"}


def group(label, colors):
    return Cluster(label, graph_attr={"fontname": FONT, "fontsize": "12", "labeljust": "l", "margin": "10", **colors})


def flow(label="", **attrs):
    return Edge(label=label, color=GRAY, fontcolor=GRAY, fontname=FONT, fontsize="11", **attrs)


def hidden():
    return Edge(style="invis")


with Diagram(
    "",
    filename=OUT,
    outformat="svg",
    show=False,
    direction="LR",
    graph_attr={"fontname": FONT, "pad": "0.2", "nodesep": "0.25", "ranksep": "0.55", "compound": "true",
                "splines": "spline", "newrank": "true"},
    node_attr={"fontname": FONT, "fontsize": "11", "width": "0.9", "imagepos": "tc"},
    edge_attr={"fontname": FONT, "arrowsize": "0.7"},
):
    users = Users(TEXT["users"])

    with group("AWS Cloud", AWS_CLOUD):
        cloudfront = CloudFront(TEXT["cloudfront"])
        with group(TEXT["edge"], REGION):
            waf = WAF(TEXT["waf"])
            acm = CertificateManager(TEXT["acm"])
            body_hash = LambdaFunction(TEXT["body_hash"])

        with group(TEXT["region"], REGION):
            ses = SimpleEmailServiceSes(TEXT["ses"])
            schedules = EventbridgeScheduler(TEXT["schedules"])
            files = SimpleStorageServiceS3Bucket(TEXT["files"])
            assets = SimpleStorageServiceS3Bucket(TEXT["assets"])
            guardduty = Guardduty(TEXT["guardduty"])
            mail = SimpleStorageServiceS3Bucket(TEXT["mail"])
            jobs = SimpleQueueServiceSqsQueue(TEXT["jobs"])

            with group(TEXT["vpc"], VPC):
                with group(TEXT["private"], PRIVATE):
                    with group(TEXT["functions"], FUNCTION_GROUP):
                        web = LambdaFunction(TEXT["web"])
                        task = LambdaFunction(TEXT["task"])
                        worker = LambdaFunction(TEXT["worker"])
                    rds = RDSPostgresqlInstance(TEXT["rds"])
                network = Endpoint(TEXT["network"])

            with group(TEXT["shared"], SHARED_GROUP):
                ecr = ECR(TEXT["ecr"])
                ssm = SystemsManagerParameterStore(TEXT["ssm"])
                cloudwatch = Cloudwatch(TEXT["cloudwatch"])

    # A request, and the services CloudFront uses in us-east-1 (a row).
    users >> flow(TEXT["https"]) >> cloudfront
    cloudfront >> hidden() >> waf >> hidden() >> acm >> hidden() >> body_hash
    cloudfront >> flow(style="dotted", constraint="false", arrowhead="none") >> waf
    cloudfront >> flow(TEXT["pages"]) >> web
    # Uploads and downloads go to S3 through CloudFront; uploads are scanned.
    cloudfront >> flow(TEXT["uploads"]) >> files >> flow(TEXT["scan"]) >> guardduty
    cloudfront >> flow(TEXT["assets_edge"]) >> assets
    # A job.
    web >> flow(TEXT["enqueue"]) >> jobs >> flow() >> worker
    # Incoming mail, and the scheduled tasks.
    ses >> flow(TEXT["mail_in"]) >> mail
    ses >> flow() >> task
    schedules >> flow(TEXT["run"]) >> task
    # The database and the AWS APIs, from the group of functions.
    worker >> Edge(ltail=FUNCTIONS, color=GRAY) >> rds
    worker >> Edge(ltail=FUNCTIONS, color=GRAY, style="dashed") >> network
    # What every function uses, as a row under the functions.
    ecr >> hidden() >> ssm >> hidden() >> cloudwatch
    task >> Edge(ltail=FUNCTIONS, lhead=SHARED, color=GRAY, style="dashed", arrowhead="none") >> ssm
