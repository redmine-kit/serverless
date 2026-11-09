# デプロイの設定

Redmine を 1 つ立てるごとに、設定のファイルを 1 つ書き、同じデプロイのコマンドで立てる設計です。1 つの AWS のアカウントに、Redmine をいくつでも立てられるようにします。自分で 1 つだけ立てるときも、多くの Redmine をまとめて管理するときも、設定のしかたは同じです。

<a id="approach"></a>

## 方針

- **1 つの Redmine に、1 つの設定のファイル:** 立てる Redmine(このプロジェクトでは「インスタンス」と呼ぶ)ごとに、設定のファイル `redmine.json` を 1 つ書きます。
- **名前はインスタンスの名前から作る:** AWS のリソースの名前、SSM のパス、タグは、すべてインスタンスの名前(`instance`)から作ります。固定の名前を使わないので、同じアカウントに、いくつ立てても重なりません。
- **既定は `redmine`:** インスタンスの名前を書かなければ、`redmine` になります。1 つのアカウントに Redmine を 1 つだけ立てるとき(アカウントをテナントや用途ごとに分けるときなど)は、書かなくてかまいません。同じアカウントに 2 つ目を立てるときだけ、重ならない名前を付けます。
- **秘密の値はファイルに書かない:** `SECRET_KEY_BASE` とデータベースのパスワードは、デプロイのコマンドが初めて立てるときに作り、SSM Parameter Store に置きます。設定のファイルには書きません。
- **Redmine の設定も同じファイルで:** Redmine の管理画面の設定(ホスト名、既定の言語など)と、プラグインの設定の初めの値も、同じファイルに書けるようにします。

<a id="names-derived-from-the-instance-name"></a>

## インスタンスの名前から作る名前

| リソース | 名前 |
| --- | --- |
| Lambda の関数 | `<instance>-web`、`<instance>-worker`、`<instance>-task` |
| SSM Parameter Store | `/<instance>/env/…` |
| S3 のバケット | `<instance>-files-<アカウント ID>-<リージョン>`、`-assets-`、`-mail-` も同じ形 |
| SQS のキュー | `<instance>-jobs`、`<instance>-jobs-dlq`、`<instance>-task-failures`(SES からの呼び出しの失敗の送り先) |
| データベース | `<instance>`(RDS のインスタンスの識別子) |
| CloudFront を通す添付ファイル | インスタンス自身のディストリビューションのビヘイビア(2 つめのディストリビューションは作らない)。信頼されたキーグループは `<instance>-attachments` で、その秘密鍵は `/<instance>/env/` の下の SecureString |
| CloudFormation のスタック | `<instance>`(インスタンスごと)、`<instance>-edge`(インスタンスごと。us-east-1 の CloudFront の証明書)、`redmine-shared`(共有の土台。下記)、`redmine-shared-edge`(共有の土台。us-east-1 の Lambda@Edge) |
| タグ | すべてのリソースに `redmine:instance=<instance>` を付ける。費用をインスタンスごとに分けて見られる |

ほかの資料の名前(`redmine-web`、スタックの `redmine` など)は、インスタンスの名前が既定の `redmine` のときのものです。

<a id="shared-base-and-per-instance-resources"></a>

## 共有の土台と、インスタンスごとのもの

同じアカウントに複数のインスタンスを立てるときに、まとめて 1 つにできるものは、共有の土台(CloudFormation のスタック `redmine-shared`)に置きます。

| 置き場所 | リソース | 理由 |
| --- | --- | --- |
| 共有の土台 | ECR のリポジトリ | 同じバージョンのイメージを、インスタンスのあいだで使い回す |
| 共有の土台(us-east-1) | Lambda@Edge の関数 `redmine-body-hash`(スタック `redmine-shared-edge`) | Lambda@Edge の関数は us-east-1 に作る決まり。同じコードを、インスタンスのあいだで使い回す([lambda.md](lambda.md#function-that-adds-the-body-hash-lambdaedge)) |
| 共有の土台 | VPC、プライベートのサブネット、S3 のゲートウェイのエンドポイント、VPC のエンドポイントか NAT インスタンス(`network.shared`) | エンドポイントと NAT インスタンスには月の決まった費用がかかるので、インスタンスのあいだで分け合う([rds.md](rds.md#routes-out-of-the-vpc)) |
| 共有の土台 | SES の受信のルールのセット | 有効なルールのセットは、リージョンに 1 つだけ。インスタンスごとに、セットの中にルールを足す([mail.md](mail.md#receipt-rules)) |
| インスタンスごと | Lambda の関数、RDS のインスタンス、セキュリティグループ、S3 のバケット、SQS のキュー、CloudFront、DNS のレコード、SES の ID、SSM のパラメーター、アラーム | インスタンスのデータと権限を、ほかのインスタンスと混ぜない |

- **1 つしか立てないとき:** 共有の土台とインスタンスを、1 つずつ立てます。手順は同じです。
- **us-east-1 に置くもの:** Lambda@Edge の関数のほかに、CloudFront の証明書(ACM)も us-east-1 に作ります(CloudFront の決まり)。証明書はインスタンスごとに、us-east-1 のスタック `<instance>-edge` に置きます。
- **VPC:** インスタンスごとの Lambda の関数と RDS のインスタンスは、共有のプライベートのサブネットに、それぞれのセキュリティグループで入ります。`network.shared` を `false` にすると、インスタンスごとに VPC を作ります([rds.md](rds.md))。

<a id="fields-of-redminejson"></a>

## `redmine.json` の項目

| 項目 | 必須 | 既定値 | 内容 |
| --- | --- | --- | --- |
| `instance` | | `redmine` | インスタンスの名前。英小文字、数字、`-` で 20 文字まで。同じアカウントに 2 つ目を立てるときに付ける |
| `region` | ○ | | 立てるリージョン |
| `deployRoleArn` | ○ | | デプロイのコマンドが引き受けるロール。立てるアカウントの、インフラのデプロイ用のロールを指す([iam.md](iam.md#role-for-deploying-infrastructure)) |
| `domain` | ○ | | Web とメールのホスト名(たとえば `redmine.example.com`) |
| `dns.mode` | | `route53` | `route53`(Route 53 のホストゾーンに置く)か `external`(ほかの DNS に、表示したレコードを自分で置く)([mail.md](mail.md#receiving-domain)) |
| `network.mode` | | `endpoints` | VPC の外への道。`endpoints`(VPC のエンドポイント。インターネットへの出口なし)か `nat`(NAT インスタンス。webhook や外の API に届く)([rds.md](rds.md#which-to-choose)) |
| `network.shared` | | `true` | 共有の土台のネットワークを使うか、インスタンスごとに作るか |
| `database.instanceClass` | | `db.t4g.micro` | RDS のインスタンスの種類([rds.md](rds.md#database)) |
| `database.storageGb` | | 20 | RDS のストレージ(gp3) |
| `lambda.webMemoryMb` | | 2048 | `redmine-web` のメモリ |
| `lambda.webReservedConcurrency` | | 10 | `redmine-web` の同時実行数の予約 |
| `lambda.workerReservedConcurrency` | | 3 | `redmine-worker` の同時実行数の予約。`redmine-task` は 2 で決め打ち([tasks.md](tasks.md#kinds-of-events)) |
| `lambda.warmup` | | `false` | 業務時間の温めの呼び出しをするか([lambda.md](lambda.md#waiting-for-start-up)) |
| `mail.receive` | | `true` | メールの受信を使うか |
| `mail.perProjectAddresses` | | `false` | プロジェクトごとのアドレスを使うか。`false` なら Redmine の標準と同じ([mail.md](mail.md#addresses-per-project)) |
| `mail.globalLocalPart` | | `redmine` | 全体用のアドレスの `@` の前 |
| `webhooks` | | `false` | Redmine の webhook の設定(`webhooks_enabled`)の初めの値。webhook は `network.mode` が `nat` のときだけ使える([lambda.md](lambda.md#background-jobs)) |
| `cloudfront.plan` | | `free` | CloudFront の料金のプラン。`free`、`pro`、`payg`(従量)([security.md](security.md#plan-and-cost)) |
| `waf.loginRateLimit` | | 20 | WAF のログインの回数の制限(5 分あたり。[security.md](security.md#rules)) |
| `waf.rateLimit` | | 1000 | WAF の全体の回数の制限(5 分あたり) |
| `waf.commonRuleSet` | | `count` | WAF の Common Rule Set を、`count`(数えるだけ)にするか `block`(止める)にするか |
| `waf.commonRuleSetCountOnly` | | `["SizeRestrictions_BODY"]` | `block` のときも、数えるだけにするルール |
| `cloudfront.webAclArn` | | なし | 自分で用意した Web ACL を使うとき。指定すると、`waf.*` は使わない |
| `redmine.version` | | `redmine.lock` のバージョン | 使う Redmine のバージョン。上げる前の確認の方法は [upgrade.md](upgrade.md) |
| `image` | | このプロジェクトのイメージ | 使う側が作った派生のイメージ(テーマやプラグインを足したもの)を使うとき、その置き場所と digest(`image.repository`、`image.digest`)。派生のイメージの作り方は [architecture.md](architecture.md#derived-images) |
| `redmine.settings` | | なし | Redmine の管理画面の設定の値(`host_name`、`default_language`、`mail_from` など) |
| `redmine.settingsMode` | | `initial` | `initial`(初めて立てたときだけ入れる。あとは画面で変えられる)か `enforce`(デプロイのたびに入れ直す) |
| `redmine.pluginSettings` | | なし | プラグインの設定の値。プラグインの名前(`redmine_serverless`、`redmine_serverless_s3`、`redmine_serverless_ses`、`redmine_serverless_sqs`)ごとに書く |
| `logs.retentionDays` | | 90 | CloudWatch Logs の保持の日数(Lambda@Edge のロググループを含む) |
| `retention.recordsDays` | | 90 | プラグインの記録(受け取ったメール、失敗したジョブ)を残す日数 |
| `retention.mailDays` | | 30 | メールのバケットのメール(`processed/` と `inbound/`)を残す日数 |
| `retention.noncurrentVersionDays` | | 30 | 添付ファイルの古いバージョンを残す日数 |
| `retention.backupDays` | | 7 | RDS の自動のバックアップを残す日数(35 まで)。割り当てたストレージの大きさまでは無料([rds.md](rds.md#settings)) |
| `alarms.snsTopicArn` | | なし | アラームを送る SNS のトピック |
| `tags` | | なし | すべてのリソースに足すタグ |

保持の期間の一覧は、[security.md](security.md#retention-periods) にあります。

設定のファイルの形は、JSON Schema(`schema/redmine.schema.json`)で決め、デプロイのコマンドが最初に確認します。

<a id="example"></a>

### 例

```json
{
  "region": "ap-northeast-1",
  "deployRoleArn": "arn:aws:iam::111122223333:role/redmine-infra-deploy",
  "domain": "redmine.example.com",
  "network": { "mode": "endpoints" },
  "mail": { "receive": true, "perProjectAddresses": true },
  "redmine": {
    "settings": {
      "app_title": "Redmine",
      "default_language": "ja",
      "mail_from": "redmine@redmine.example.com"
    }
  }
}
```

<a id="deployment-commands"></a>

## デプロイのコマンド

```sh
bin/deploy path/to/redmine.json --dry-run   # 変わるものを表示するだけ
bin/deploy path/to/redmine.json             # 立てる、更新する
```

| 段 | すること |
| --- | --- |
| 1 | 設定のファイルを JSON Schema で確認する |
| 2 | 共有の土台のスタック(`redmine-shared` と、us-east-1 の `redmine-shared-edge`)を、無ければ作り、あれば更新する |
| 3 | 秘密の値が SSM に無ければ作る(あれば変えない)。添付ファイルの URL のための CloudFront のキーペアの秘密鍵も含め、その公開鍵はインスタンスのスタックに入れる。RDS は作るときにデータベースのパスワードを SSM から読むので、インスタンスのスタックより先に行う |
| 4 | インスタンスのスタック(`<instance>` と、us-east-1 の `<instance>-edge`)を、作るか更新する。Lambda@Edge が各リージョンに作ったロググループに、保持の期間を当て直す([security.md](security.md#retention-periods)) |
| 5 | 使うバージョンのイメージを、そのアカウントの ECR に置く(Lambda は、同じリージョンの ECR のイメージしか使えない) |
| 6 | アセットを S3 に同期する |
| 7 | `redmine-task` のイメージを更新し、`db:migrate` と `redmine:plugins:migrate` を実行する。初めて立てるときは、これで空のデータベースにスキーマができる |
| 8 | 初めて立てるときは、`redmine-task` で初めのデータを入れる(`redmine:load_default_data`。言語は `redmine.settings.default_language`。なければ英語) |
| 9 | `redmine-web` と `redmine-worker` のイメージを更新する |
| 10 | Redmine とプラグインの設定を入れる(`redmine.settingsMode` のとおり。rake のタスク `redmine_serverless:apply_settings`) |
| 11 | デプロイしたあとの確認([testing.md](testing.md#checks-after-deployment)) |

- **2 つの使い方:** すべての段は、インフラのデプロイ用のロールで動かします(SSO の管理者か、承認の要る GitHub の Environment)。Redmine のイメージだけを更新するときは、`bin/deploy --code-only` で、段 5〜7、9、11 だけを、GitHub Actions のコードのデプロイ用のロールで動かします([iam.md](iam.md))。
- **保守の画面:** `redmine-web` と `redmine-worker` の同時実行数の予約を 0 にすると、書き込みを止められます(事故のときなど。[security.md](security.md))。`redmine-web` の同時実行数の予約が 0 のあいだ、関数 URL は要求を断ります。CloudFront のエラーの応答の設定で、そのときに S3 の保守の画面を返します。
- **同じ設定なら何もしない:** 設定のファイルとイメージが変わっていなければ、何も変えません。
- **多くのインスタンスを立てるとき:** インスタンスの数だけ、同じコマンドを繰り返します。順番(先に試す小さなインスタンスから)は、使う側で決めます。
- **イメージ:** このプロジェクトの CI が、Redmine のバージョンごとにイメージを作り、GitHub Packages のコンテナのレジストリ(`ghcr.io`)に公開します(案。[architecture.md](architecture.md#distribution))。デプロイのコマンドは、digest で指定してそのイメージを取り、立てるアカウントの ECR に置きます。


<a id="templates"></a>

### テンプレート

スタックは、`infra/` に CloudFormation で書きます。`bin/lint` が cfn-lint で検査します。

| ファイル | スタック | 今の中身 |
| --- | --- | --- |
| `infra/shared.yaml` | `redmine-shared` | ECR のリポジトリ、2 つの AZ のプライベートのサブネットを持つ VPC(インターネットゲートウェイはない)、S3 のゲートウェイのエンドポイント、`network.mode` が `endpoints` のときの、1 つの AZ の SSM と SQS のインターフェースのエンドポイント |
| `infra/instance.yaml` | `<instance>` | RDS for PostgreSQL(パラメーターグループで TLS を必須にし、暗号化、削除保護、自動のバックアップ)、SSM の `REDMINE_DB_HOST` のパラメーター、ジョブのキューと、そのデッドレターキュー、関数 URL(IAM の認証)を持つ `redmine-web` と `redmine-task`(プライベートのサブネットの中)、その実行ロールとロググループ |

- **秘密の値:** CloudFormation は SecureString のパラメーターを作れません。`bin/deploy` が `SECRET_KEY_BASE` と `REDMINE_DB_PASSWORD` を作り(手順 3)、RDS のインスタンスは、動的な参照(`{{resolve:ssm-secure:/<instance>/env/REDMINE_DB_PASSWORD}}`)でパスワードを受け取ります。
- **イメージ:** インスタンスのスタックは、そのアカウントの ECR のイメージを、digest で受け取ります(`ImageUri`)。
- **PostgreSQL のバージョン:** `DbMajorVersion` には既定の値を置きません。メジャーバージョンは、インスタンスを作るときに、RDS が出しているバージョンと照らして確認します([rds.md](rds.md#database))。
- **あとの段で足すもの:** `redmine-worker` と、その SQS のイベントソース(ジョブとメールの送信)、CloudFront、S3 のバケットと Lambda@Edge、SES、NAT インスタンス(`network.mode` が `nat`)、アラーム、us-east-1 のスタック、`bin/deploy` そのもの([architecture.md](architecture.md#order-of-work))。

<a id="to-verify"></a>

## 確認すること

- RDS のインスタンスが、作るときと更新のときに、`ssm-secure` の動的な参照でパスワードを受け取れるか(CloudFormation の資料では対応しているプロパティ。まだ試していない)
- SES の受信のルールのセットを共有の土台に置き、インスタンスのスタックからルールを足す形が、CloudFormation で作れるか
- `ghcr.io` から、立てるアカウントの ECR に、digest を変えずにイメージを写す方法(ECR のプルスルーキャッシュが `ghcr.io` に使えるかを含む)
