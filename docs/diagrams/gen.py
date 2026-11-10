"""Writes the draw.io diagram of the AWS resources that infra/*.yaml create
(docs/architecture.md#aws-resources), laid out by hand with the AWS
Architecture Icons.

  python3 gen.py en architecture.drawio
  python3 gen.py ja architecture.ja.drawio

AWS_ICONS is the unpacked icon package (Icon-package_07312026 from
https://aws.amazon.com/architecture/icons/). bin/diagrams runs this and exports
the result with draw.io. Labels are plain text (html=0), so that the exported
SVG holds SVG text and no foreignObject.
"""

import base64
import glob
import os
import sys
from xml.sax.saxutils import escape, quoteattr

LANG, OUT = sys.argv[1], sys.argv[2]
ICONS = os.environ.get("AWS_ICONS") or sys.exit("AWS_ICONS: the unpacked AWS Architecture Icons package")

T = {
    "en": dict(
        users="Users", senders="Email\nsenders", webhooks="Webhook\ndestinations",
        cloud="AWS Cloud", cloudfront="CloudFront", cff="CloudFront\nFunctions",
        waf="AWS WAF", acm="ACM certificate", edgefn="Lambda@Edge",
        assets="Assets", files="Attachments", guardduty="GuardDuty\nMalware\nProtection",
        dlq="Dead-letter queue", jobs="Job queue", ses="Amazon SES", mail="Received email",
        scheduler="EventBridge\nScheduler", failures="On-failure\ndestination",
        vpc="VPC", public="Public subnet", private="Private subnets",
        functions="Lambda (one image)", web="redmine-web\n(function URL)", worker="redmine-worker",
        task="redmine-task", nat="NAT instance\n(Auto Scaling group)", igw="Internet\ngateway",
        either="or", interface="Interface endpoints", s3gw="S3 (gateway)", rds="RDS for\nPostgreSQL",
        shared="Used by every function", ecr="Amazon ECR", ssm="Parameter Store",
        cloudwatch="CloudWatch\n(logs, alarms)", account="Account", iam="IAM roles",
        trail="CloudTrail", analyzer="IAM Access\nAnalyzer", ghcr="ghcr.io",
        https="HTTPS", default="Default (*)", files_e="/files/*, /tmp/*", assets_e="/assets/*",
        jobs_e="jobs", smtp="email", event="invoke", rake="rake", sql="SQL", copy="bin/deploy copies",
    ),
    "ja": dict(
        users="利用者", senders="メール\n送信者", webhooks="Webhook\n送信先",
        cloud="AWS Cloud", cloudfront="CloudFront", cff="CloudFront\nFunctions",
        waf="AWS WAF", acm="ACM 証明書", edgefn="Lambda@Edge",
        assets="アセット", files="添付ファイル", guardduty="GuardDuty\nMalware\nProtection",
        dlq="デッドレターキュー", jobs="ジョブキュー", ses="Amazon SES", mail="受信メール",
        scheduler="EventBridge\nScheduler", failures="失敗時の送信先",
        vpc="VPC", public="パブリックサブネット", private="プライベートサブネット",
        functions="Lambda (同じイメージ)", web="redmine-web\n(関数 URL)", worker="redmine-worker",
        task="redmine-task", nat="NAT インスタンス\n(Auto Scaling グループ)", igw="インターネット\nゲートウェイ",
        either="または", interface="インターフェイスエンドポイント", s3gw="S3 (ゲートウェイ)",
        rds="RDS for\nPostgreSQL",
        shared="すべての関数が使う", ecr="Amazon ECR", ssm="Parameter Store",
        cloudwatch="CloudWatch\n(ログ、アラーム)", account="アカウント", iam="IAM ロール",
        trail="CloudTrail", analyzer="IAM Access\nAnalyzer", ghcr="ghcr.io",
        https="HTTPS", default="デフォルト (*)", files_e="/files/*, /tmp/*", assets_e="/assets/*",
        jobs_e="ジョブ", smtp="メール", event="呼び出し", rake="rake", sql="SQL", copy="bin/deploy がコピー",
    ),
}[LANG]

FONT = "fontFamily=Noto Sans CJK JP,Noto Sans JP,Hiragino Sans,Hiragino Kaku Gothic ProN,Yu Gothic,Meiryo,Helvetica,Arial,sans-serif;"
INK, LINE, GREY = "#232F3E", "#545B64", "#5A6C86"


def icon_uri(name):
    """An icon of the package as a data URI for a draw.io image style."""
    found = sorted(p for p in glob.glob(os.path.join(ICONS, "**", name + ".svg"), recursive=True) if "__MACOSX" not in p)
    if not found:
        sys.exit(f"no icon {name}")
    return "data:image/svg+xml," + base64.b64encode(open(found[0], "rb").read()).decode()


cells = []
box = {}  # id: absolute (x, y, w, h)


def add(id, value, style, x, y, w, h, parent="1"):
    box[id] = (x, y, w, h)
    px, py = box[parent][:2] if parent in box else (0, 0)
    value = escape(value).replace("\n", "&#xa;")
    cells.append(f'<mxCell id="{id}" value="{value}" style={quoteattr(style)} vertex="1" parent="{parent}">'
                 f'<mxGeometry x="{x - px}" y="{y - py}" width="{w}" height="{h}" as="geometry"/></mxCell>')


GROUP = ("rounded=0;html=0;fontSize=12;verticalAlign=top;align=left;spacingLeft=30;spacingTop=4;"
         "container=1;collapsible=0;recursiveResize=0;pointerEvents=0;" + FONT)
GROUPS = {
    # The AWS groups' colors and icons, as in the icon package and draw.io's aws4 library.
    "cloud": ("fillColor=none;strokeColor=#232F3E;fontColor=#232F3E;", "AWS-Cloud-logo_32"),
    "region": ("fillColor=none;strokeColor=#00A4A6;fontColor=#147EBA;dashed=1;", "Region_32"),
    "vpc": ("fillColor=none;strokeColor=#8C4FFF;fontColor=#8C4FFF;", "Virtual-private-cloud-VPC_32"),
    "public": ("fillColor=#F2F6E8;strokeColor=none;fontColor=#248814;", "Public-subnet_32"),
    "private": ("fillColor=#E6F6F7;strokeColor=none;fontColor=#147EBA;", "Private-subnet_32"),
    "generic": ("fillColor=none;strokeColor=#5A6C86;dashed=1;fontColor=#5A6C86;spacingLeft=8;", None),
}


def group(id, kind, label, x, y, w, h, parent="1"):
    colors, mark = GROUPS[kind]
    add(id, label, GROUP + colors, x, y, w, h, parent)
    if mark:
        add(id + "-icon", "", "shape=image;aspect=fixed;imageAspect=0;image=" + icon_uri(mark) + ";", x, y, 24, 24, id)


def tile(id, name, label, cx, cy, parent="1", on_line=False):
    """An icon at 48 px, centered on (cx, cy), its label under it. on_line: the
    tile sits on a group's border, and its label hides the border."""
    style = ("shape=image;aspect=fixed;imageAspect=0;html=0;verticalLabelPosition=bottom;verticalAlign=top;"
             "labelPosition=center;align=center;spacingTop=-2;fontSize=12;fontColor=" + INK + ";" + FONT +
             "image=" + icon_uri(name) + ";" + ("labelBackgroundColor=#ffffff;" if on_line else ""))
    add(id, label, style, cx - 24, cy - 24, 48, 48, parent)


def text(id, label, cx, cy, parent="1"):
    add(id, label, "text;html=0;align=center;verticalAlign=middle;fontSize=12;fontColor=" + INK + ";" + FONT,
        cx - 50, cy - 10, 100, 20, parent)


n = 0


def edge(src, dst, pts, label="", at=None, style="solid", arrow=True):
    """pts: the corners in absolute coordinates, from a point on src's border
    to a point on dst's border. at: the point of the line where the label sits."""
    global n
    n += 1

    def rel(id, p):
        x, y, w, h = box[id]
        return round((p[0] - x) / w, 4), round((p[1] - y) / h, 4)

    ex, ey = rel(src, pts[0])
    nx, ny = rel(dst, pts[-1])
    s = (f"edgeStyle=none;rounded=0;html=0;strokeColor={LINE};fontColor={LINE};fontSize=11;"
         f"labelBackgroundColor=#ffffff;exitX={ex};exitY={ey};exitDx=0;exitDy=0;exitPerimeter=0;"
         f"entryX={nx};entryY={ny};entryDx=0;entryDy=0;entryPerimeter=0;" + FONT)
    s += "endArrow=block;endFill=1;endSize=5;" if arrow else "endArrow=none;"
    s += {"solid": "", "dashed": "dashed=1;", "dotted": "dashed=1;dashPattern=1 3;"}[style]
    x = 0
    if label:
        # The label's position along the line, from -1 (source) to 1 (target).
        seg = [abs(a[0] - b[0]) + abs(a[1] - b[1]) for a, b in zip(pts, pts[1:])]
        total, walked = sum(seg), 0
        for (a, b), length in zip(zip(pts, pts[1:]), seg):
            if min(a[0], b[0]) <= at[0] <= max(a[0], b[0]) and min(a[1], b[1]) <= at[1] <= max(a[1], b[1]):
                walked += abs(at[0] - a[0]) + abs(at[1] - a[1])
                break
            walked += length
        x = round(walked / total * 2 - 1, 4)
    way = "".join(f'<mxPoint x="{p[0]}" y="{p[1]}"/>' for p in pts[1:-1])
    geo = (f'<mxGeometry x="{x}" relative="1" as="geometry">'
           + (f'<Array as="points">{way}</Array>' if way else "") + "</mxGeometry>")
    value = escape(label)
    cells.append(f'<mxCell id="e{n}" value="{value}" style={quoteattr(s)} edge="1" parent="1" '
                 f'source="{src}" target="{dst}">{geo}</mxCell>')


# The grid. Rows: the centers of the icons in the region. Columns: users and
# senders (X_OUT), CloudFront (X_CF) and the line of its behaviors (X_CB), two
# columns outside the VPC (X_1, X_2), the functions (X_FN) and the column right
# of them (X_R).
W, H = 1180, 1165
ROW = dict(a=260, b=370, c=480, d=590, e=700, f=810, g=920, h=1050)
X_OUT, X_CF, X_CB, X_1, X_2, X_FN, X_R = 42, 165, 210, 365, 475, 635, 855

add("bg", "", "rounded=0;fillColor=#FFFFFF;strokeColor=none;", 0, 0, W, H)

group("cloud", "cloud", T["cloud"], 110, 15, 940, 1140)
group("edge", "region", "us-east-1", 345, 40, 360, 130, "cloud")
group("region", "region", "ap-northeast-1", 230, 205, 800, 935, "cloud")
group("vpc", "vpc", T["vpc"], 535, 220, 450, 690, "region")
group("public", "public", T["public"], 550, 250, 420, 105, "vpc")
group("private", "private", T["private"], 550, 370, 420, 525, "vpc")
group("fns", "generic", T["functions"], 555, 420, 160, 450, "private")
group("interface", "generic", T["interface"], 755, 405, 200, 105, "private")
group("shared", "generic", T["shared"], 260, 990, 450, 130, "region")
group("account", "generic", T["account"], 730, 990, 270, 130, "region")

# Outside AWS.
tile("users", "Res_Users_48_Light", T["users"], X_OUT, 105)
tile("senders", "Res_Email_48_Light", T["senders"], X_OUT, ROW["e"])
tile("webhooks", "Res_Internet_48_Light", T["webhooks"], 1115, 285)
tile("ghcr", "Res_Generic-Application_48_Light", T["ghcr"], X_OUT, ROW["h"])

# CloudFront, and what it takes from us-east-1.
tile("cloudfront", "Arch_Amazon-CloudFront_48", T["cloudfront"], X_CF, 105, "cloud")
tile("cff", "Arch_Amazon-CloudFront_48", T["cff"], 270, 105, "cloud")
tile("waf", "Arch_AWS-WAF_48", T["waf"], 405, 105, "edge")
tile("acm", "Arch_AWS-Certificate-Manager_48", T["acm"], 525, 105, "edge")
tile("edgefn", "Arch_AWS-Lambda_48", T["edgefn"], 645, 105, "edge")

# The region, outside the VPC.
tile("assets", "Arch_Amazon-Simple-Storage-Service_48", T["assets"], X_1, ROW["a"], "region")
tile("files", "Arch_Amazon-Simple-Storage-Service_48", T["files"], X_1, ROW["b"], "region")
tile("guardduty", "Arch_Amazon-GuardDuty_48", T["guardduty"], X_2, ROW["b"], "region")
tile("dlq", "Arch_Amazon-Simple-Queue-Service_48", T["dlq"], X_1, ROW["d"], "region")
tile("jobs", "Arch_Amazon-Simple-Queue-Service_48", T["jobs"], X_2, ROW["d"], "region")
tile("ses", "Arch_Amazon-Simple-Email-Service_48", T["ses"], X_1, ROW["e"], "region")
tile("mail", "Arch_Amazon-Simple-Storage-Service_48", T["mail"], X_2, ROW["e"], "region")
tile("scheduler", "Arch_Amazon-EventBridge_48", T["scheduler"], X_1, ROW["f"], "region")
tile("failures", "Arch_Amazon-Simple-Queue-Service_48", T["failures"], X_2, ROW["g"], "region")

# The VPC. Only one of the NAT instance and the interface endpoints is created
# (network.mode).
tile("nat", "Arch_Amazon-EC2_48", T["nat"], X_R, 285, "public")
tile("igw", "Arch_Amazon-Virtual-Private-Cloud_48", T["igw"], 985, 285, "region", on_line=True)
text("either", T["either"], X_R, 387, "private")
tile("ssm_ep", "Arch_AWS-PrivateLink_48", "SSM", X_R - 65, 457, "interface")
tile("ses_ep", "Arch_AWS-PrivateLink_48", "SES", X_R, 457, "interface")
tile("sqs_ep", "Arch_AWS-PrivateLink_48", "SQS", X_R + 65, 457, "interface")
tile("s3_ep", "Arch_Amazon-Virtual-Private-Cloud_48", T["s3gw"], X_R, ROW["d"], "private")
tile("rds", "Arch_Amazon-RDS_48", T["rds"], X_R, ROW["e"], "private")
tile("web", "Arch_AWS-Lambda_48", T["web"], X_FN, ROW["c"], "fns")
tile("worker", "Arch_AWS-Lambda_48", T["worker"], X_FN, ROW["d"], "fns")
tile("task", "Arch_AWS-Lambda_48", T["task"], X_FN, ROW["f"], "fns")

# Used by every function, and the account's resources.
tile("ecr", "Arch_Amazon-Elastic-Container-Registry_48", T["ecr"], X_1, ROW["h"], "shared")
tile("ssm", "Arch_AWS-Systems-Manager_48", T["ssm"], 500, ROW["h"], "shared")
tile("cloudwatch", "Arch_Amazon-CloudWatch_48", T["cloudwatch"], 640, ROW["h"], "shared")
tile("iam", "Arch_AWS-Identity-and-Access-Management_48", T["iam"], 785, ROW["h"], "account")
tile("trail", "Arch_AWS-CloudTrail_48", T["trail"], 865, ROW["h"], "account")
tile("analyzer", "Arch_AWS-Identity-and-Access-Management_48", T["analyzer"], 945, ROW["h"], "account")

# A request: CloudFront's behaviors leave from one line right of it.
edge("users", "cloudfront", [(X_OUT + 24, 105), (X_CF - 24, 105)], T["https"], at=(88, 105))
edge("cloudfront", "cff", [(X_CF + 24, 105), (246, 105)], style="dotted", arrow=False)
edge("cloudfront", "edge", [(X_CF, 81), (X_CF, 60), (345, 60)], style="dotted", arrow=False)
for target, row, label in (("assets", ROW["a"], "assets_e"), ("files", ROW["b"], "files_e")):
    edge("cloudfront", target, [(X_CF + 24, 124), (X_CB, 124), (X_CB, row), (X_1 - 24, row)], T[label],
         at=(X_1 - 80, row))
edge("cloudfront", "web", [(X_CF + 24, 124), (X_CB, 124), (X_CB, 468), (X_FN - 24, 468)], T["default"],
     at=(X_1 - 70, 468))
edge("files", "guardduty", [(X_1 + 24, ROW["b"]), (X_2 - 24, ROW["b"])])
# A job, and the jobs that used up their tries.
edge("web", "jobs", [(X_FN - 24, 492), (X_2, 492), (X_2, ROW["d"] - 24)], T["jobs_e"], at=(X_2 + 32, 492))
edge("jobs", "worker", [(X_2 + 24, ROW["d"]), (X_FN - 24, ROW["d"])])
edge("jobs", "dlq", [(X_2 - 24, ROW["d"]), (X_1 + 24, ROW["d"])])
# Received email: stored in S3, then imported by the task. Scheduled rake.
edge("senders", "ses", [(X_OUT + 24, ROW["e"]), (X_1 - 24, ROW["e"])], T["smtp"], at=(165, ROW["e"]))
edge("ses", "mail", [(X_1 + 24, ROW["e"]), (X_2 - 24, ROW["e"])])
edge("ses", "task", [(X_1, ROW["e"] - 24), (X_1, 652), (X_FN, 652), (X_FN, ROW["f"] - 24)], T["event"],
     at=(X_2 + 32, 652))
edge("scheduler", "task", [(X_1 + 24, ROW["f"]), (X_FN - 24, ROW["f"])], T["rake"], at=(X_2 + 32, ROW["f"]))
edge("task", "failures", [(X_FN - 24, 829), (X_2, 829), (X_2, ROW["g"] - 24)])
# From the functions: the NAT instance or the interface endpoints, S3, the database.
edge("fns", "nat", [(715, 450), (738, 450), (738, 285), (X_R - 24, 285)], style="dashed")
edge("fns", "interface", [(715, 470), (755, 470)], style="dashed")
edge("nat", "igw", [(X_R + 24, 285), (961, 285)])
edge("igw", "webhooks", [(1009, 285), (1091, 285)])
edge("fns", "s3_ep", [(715, ROW["d"]), (X_R - 24, ROW["d"])], style="dashed")
edge("fns", "rds", [(715, ROW["e"]), (X_R - 24, ROW["e"])], T["sql"], at=(780, ROW["e"]))
edge("fns", "shared", [(X_FN, 870), (X_FN, 990)], style="dashed", arrow=False)
# The image.
edge("ghcr", "ecr", [(X_OUT + 24, ROW["h"]), (X_1 - 24, ROW["h"])], T["copy"], at=(165, ROW["h"]))

xml = ('<mxfile host="gen.py"><diagram id="aws" name="AWS"><mxGraphModel dx="1200" dy="1200" grid="0" gridSize="10" '
       'guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="0" pageScale="1" background="#ffffff" '
       'math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>' + "".join(cells)
       + "</root></mxGraphModel></diagram></mxfile>")
open(OUT, "w", encoding="utf-8").write(xml)
