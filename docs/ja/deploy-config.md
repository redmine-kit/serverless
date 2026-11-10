# デプロイ設定

Redmine を 1 つ構築するごとに設定ファイルを 1 つ書き、同じデプロイコマンドで構築する設計です。1 つの AWS アカウントに、Redmine をいくつでも構築できるようにします。自分で 1 つだけ構築する場合も、多数の Redmine をまとめて管理する場合も、設定方法は同じです。

<a id="approach"></a>

## 方針

- **1 つの Redmine に 1 つの設定ファイル:** 構築する Redmine (このプロジェクトでは「インスタンス」と呼ぶ) ごとに、設定ファイル `redmine.json` を 1 つ書きます。
- **名前はインスタンス名から決める:** AWS リソースの名前、SSM のパス、タグは、すべてインスタンス名 (`instance`) から決めます。固定の名前を使わないので、同じアカウントにいくつ構築しても重複しません。
- **デフォルトは `redmine`:** インスタンス名を書かなければ、`redmine` になります。1 つのアカウントに Redmine を 1 つだけ構築する場合 (アカウントをテナントや用途ごとに分ける場合など) は、書かなくてかまいません。同じアカウントに 2 つ目を構築する場合だけ、重複しない名前を付けます。
- **シークレットはファイルに書かない:** `SECRET_KEY_BASE` とデータベースパスワードは、デプロイコマンドが初回の構築時に生成し、SSM Parameter Store に保存します。設定ファイルには書きません。
- **Redmine の設定も同じファイルで:** Redmine の管理画面の設定 (ホスト名、デフォルトの言語など) と、プラグイン設定の初期値も、同じファイルに書けるようにします。

<a id="names-derived-from-the-instance-name"></a>

## インスタンス名から決まる名前

| リソース | 名前 |
| --- | --- |
| Lambda 関数 | `<instance>-web`<br>`<instance>-worker`<br>`<instance>-task` |
| SSM Parameter Store | `/<instance>/env/…` |
| S3 バケット | `<instance>-files-<アカウント ID>-<リージョン>`。`-assets-`、`-mail-` も同じ形式 |
| SQS キュー | `<instance>-jobs`、`<instance>-jobs-dlq`、`<instance>-task-failures` (SES からの呼び出しが失敗したときの送信先) |
| データベース | `<instance>` (RDS インスタンスの識別子) |
| CloudFront 経由の添付ファイル | インスタンス自身のディストリビューションのビヘイビア (2 つ目のディストリビューションは作らない)。信頼されたキーグループは `<instance>-attachments` で、その秘密鍵は `/<instance>/env/` の下の SecureString |
| CloudFormation スタック | `<instance>` (インスタンス別)、`<instance>-edge` (インスタンス別。us-east-1 の CloudFront の証明書)、`redmine-shared` (共有基盤。下記)、`redmine-shared-edge` (共有基盤。us-east-1 の Lambda@Edge) |
| タグ | すべてのリソースに `redmine:instance=<instance>` を付ける。費用をインスタンスごとに分けて確認できる |

ほかの資料にある名前 (`redmine-web`、スタックの `redmine` など) は、インスタンス名がデフォルトの `redmine` の場合のものです。

<a id="shared-base-and-per-instance-resources"></a>

## 共有基盤とインスタンス別のリソース

同じアカウントに複数のインスタンスを構築するときに 1 つにまとめられるものは、共有基盤 (CloudFormation スタック `redmine-shared`) に配置します。

| 配置先 | リソース | 理由 |
| --- | --- | --- |
| 共有基盤 | ECR リポジトリ | 同じバージョンのイメージを、インスタンス間で共用する |
| 共有基盤 (us-east-1) | Lambda@Edge 関数 `redmine-body-hash` (スタック `redmine-shared-edge`) | Lambda@Edge 関数は us-east-1 に作成する必要がある。同じコードを、インスタンス間で共用する ([lambda.md](lambda.md#function-that-adds-the-body-hash-lambdaedge)) |
| 共有基盤 | VPC、プライベートサブネット、S3 のゲートウェイエンドポイント、VPC エンドポイントか NAT インスタンス (`network.shared`) | エンドポイントと NAT インスタンスには月額の固定費がかかるので、インスタンス間で共用する ([rds.md](rds.md#routes-out-of-the-vpc)) |
| 共有基盤 | SES の受信ルールセット | アクティブな受信ルールセットは、リージョンに 1 つだけ。インスタンスごとに、ルールセットにルールを追加する ([mail.md](mail.md#receipt-rules)) |
| インスタンス別 | Lambda 関数、RDS インスタンス、セキュリティグループ、S3 バケット、SQS キュー、CloudFront、DNS レコード、SES の ID、SSM パラメーター、アラーム | インスタンスのデータと権限を、ほかのインスタンスと混在させない |

Redmine を 1 つだけ構築する場合も、共有基盤とインスタンスを 1 つずつ構築します。手順は同じです。

Lambda@Edge 関数のほかに、CloudFront の証明書 (ACM) も us-east-1 に作成します。CloudFront がこのリージョンの証明書を求めるためです。証明書はインスタンスごとに、us-east-1 のスタック `<instance>-edge` に配置します。

インスタンス別の Lambda 関数と RDS インスタンスは、共有のプライベートサブネットに、それぞれのセキュリティグループで配置します。`network.shared` を `false` にすると、代わりにインスタンスごとに VPC を作成します ([rds.md](rds.md))。

<a id="fields-of-redminejson"></a>

## `redmine.json` の項目

| 項目 | 必須 | デフォルト値 | 内容 |
| --- | --- | --- | --- |
| `instance` | | `redmine` | インスタンス名。英小文字、数字、`-` で 20 文字まで。同じアカウントに 2 つ目を構築する場合に付ける |
| `region` | ○ | | 構築先のリージョン |
| `deployRoleArn` | ○ | | デプロイコマンドが引き受けるロール。構築先アカウントの、インフラデプロイ用ロールを指定する ([iam.md](iam.md#role-for-deploying-infrastructure)) |
| `domain` | ○ | | Web とメールのホスト名 (たとえば `redmine.example.com`) |
| `dns.mode` | | `route53` | `route53` (Route 53 ホストゾーンにレコードを作成する) か `external` (ほかの DNS に、表示されたレコードを自分で登録する)([mail.md](mail.md#receiving-domain)) |
| `dns.hostedZoneId` | `route53` の場合 | | ドメインの Route 53 ホストゾーン |
| `account.*` | | | アカウントのスタックの設定。`bin/deploy --account` だけが使う。ロール (`ssoPermissionSet`。デフォルトは `AdministratorAccess`。`githubRepository`。`owner/repository`。なければ GitHub Actions のロールは作成しない。`githubInfraEnvironment`。デフォルトは `infrastructure`。`githubCodeEnvironment`。デフォルトは `production`。`githubOidcProviderArn`。アカウントに GitHub の OIDC プロバイダーがすでにある場合。[iam.md](iam.md#account-roles)) と、アカウントのセキュリティ設定 (`cloudTrail` と `accessAnalyzer`。デフォルトでは、アカウントになければ作成する。`trailDays`。デフォルトは 365。`unusedAccessAnalyzer`。デフォルトは `false`。[aws-security.md](aws-security.md)) |
| `network.mode` | | `endpoints` | VPC 外への経路。`endpoints` (VPC エンドポイント。インターネットへの出口なし) か `nat` (NAT インスタンス。webhook や外部の API に接続できる)([rds.md](rds.md#which-to-choose)) |
| `network.shared` | | `true` | 共有基盤のネットワークを使うか。現在は `true` だけ。インスタンス別の VPC は未実装 |
| `database.majorVersion` | ○ | | PostgreSQL のメジャーバージョン (たとえば `"17"`)。インスタンスの作成時に、RDS が提供しているバージョンと照合して確認する ([rds.md](rds.md#database)) |
| `database.instanceClass` | | `db.t4g.micro` | RDS のインスタンスクラス |
| `database.storageGb` | | 20 | RDS のストレージ (gp3) |
| `lambda.webMemoryMb` | | 2048 | `redmine-web` のメモリ |
| `lambda.webReservedConcurrency` | | 10 | `redmine-web` の予約された同時実行 |
| `lambda.workerReservedConcurrency` | | 3 | `redmine-worker` の予約された同時実行。`redmine-task` は 2 で固定 ([tasks.md](tasks.md#kinds-of-events)) |
| `lambda.warmup` | | `false` | 業務時間にウォームアップの呼び出しを行うか ([lambda.md](lambda.md#waiting-for-start-up))。現在は `false` だけ |
| `uploads.malwareScan` | | `true` | GuardDuty Malware Protection for S3 で、Redmine が読み込む前に、アップロードとインポートをスキャンするか ([aws-security.md](aws-security.md#malware-protection-for-s3))。`false` で無効にする |
| `uploads.maxBytes` | | 104857600 (100 MB) | 添付ファイルのサイズ上限。`/tmp/*` の CloudFront Function が、これより大きいアップロード (`/tmp/incoming/`) を 413 で拒否する。手順 10 で、Redmine の添付ファイルの最大サイズ (`attachment_max_size`。KB) も、`redmine.settings` に指定がなければ同じ上限にする |
| `mail.receive` | | `true` | メール受信を使うか |
| `mail.perProjectAddresses` | | `false` | プロジェクト別のアドレスを使うか。`false` なら Redmine の標準と同じ ([mail.md](mail.md#addresses-per-project)) |
| `mail.globalLocalPart` | | `redmine` | 全体用アドレスの `@` の前の部分 |
| `webhooks` | | `false` | Redmine の webhook の設定 (`webhooks_enabled`) の初期値。webhook は `network.mode` が `nat` の場合だけ使える ([lambda.md](lambda.md#background-jobs)) |
| `cloudfront.plan` | | `free` | CloudFront の料金プラン。`free`、`pro`、`payg` (従量課金)([security.md](security.md#plan-and-cost)) |
| `cloudfront.webAclArn` | | なし | 自分で用意した Web ACL (us-east-1) を使う場合。指定すると、`waf.*` は使わない |
| `waf.loginRateLimit` | | 20 | WAF のログイン回数制限 (5 分あたり。[security.md](security.md#rules)) |
| `waf.rateLimit` | | 1000 | WAF の全体のリクエスト数制限 (5 分あたり) |
| `waf.commonRuleSet` | | `count` | WAF の Common Rule Set を、`count` (カウントのみ) にするか `block` (ブロック) にするか |
| `waf.commonRuleSetCountOnly` | | `["SizeRestrictions_BODY"]` | `block` の場合も、カウントのみにするルール (1 つ) |
| `image.repository` | | `ghcr.io/redmine-kit/serverless` | 使用するイメージ。アダプタが作成した派生イメージは、ここで指定する ([architecture.md](architecture.md#derived-images))。Redmine のバージョンはイメージで決まる。バージョンアップ前の確認方法は [upgrade.md](upgrade.md) |
| `image.digest` | `image.repository` を指定する場合 | その時点の、Redmine のバージョンタグの digest | イメージの digest (`sha256:…`)。指定しない場合、`bin/deploy` は、このチェックアウトがビルドする Redmine のバージョンタグ (たとえば `7.0.3`。`image/Dockerfile` の `ARG REDMINE_VERSION`) の、その時点の digest を使い、固定できるように表示する |
| `image.plugins` | | なし | イメージに追加するプラグイン。`bin/deploy` は、上のイメージをベースに、これらを追加した派生イメージをビルドする (下の「プラグインとテーマの追加」)。各要素には、`name` (`plugins/` 内のプラグインのディレクトリ名で、プラグインの ID) と、取得元を 1 つ指定する。取得元は、`version` (gem `name` のそのバージョン。RubyGems か、`source` に指定した `https://rubygems.pkg.github.com/<owner>` などから取得)、`git` と `ref` (HTTPS のリポジトリの、タグか完全なコミットハッシュ)、`path` (`redmine.json` からの相対パスのディレクトリ) のどれか |
| `image.themes` | | なし | 追加するテーマ。`themes/<name>/` に配置する。各要素には、`name` と、`git` と `ref`、または `path` を指定する |
| `redmine.settings` | | なし | Redmine の管理画面の設定値 (`host_name`、`default_language`、`mail_from` など) |
| `redmine.settingsMode` | | `initial` | `initial` (まだ保存されていない設定だけ書き込む。その後は画面で変更できる) か `enforce` (デプロイのたびに書き込み直す) |
| `redmine.pluginSettings` | | なし | プラグインの設定値。プラグイン名 (`redmine_serverless`、`redmine_serverless_s3`、`redmine_serverless_ses`、`redmine_serverless_sqs`) ごとに書く。保存されている設定にマージする。たとえば `{"redmine_serverless_ses": {"import_spam": "0", "import_without_dmarc_pass": "0"}}` で、迷惑メールと DMARC に合格しないメールを取り込まない (デフォルト値。[receiving.md](https://redmine-kit.github.io/redmine_serverless_ses/ja/receiving.html#spoofing-and-spam)) |
| `costExplorer.enabled` | | `false` | プラグイン `redmine_serverless_costexplorer` を追加したイメージ (派生イメージ。Serverless のイメージには含まれていない) のための設定。プラグインが、Cost Explorer からアカウントの費用を取得し、管理画面に表示するか。`redmine-web` と `redmine-task` に `REDMINE_COSTEXPLORER_ENABLED` を渡し、`redmine-task` に `ce:GetCostAndUsage` と `ce:GetCostForecast` を許可し、`redmine_serverless_costexplorer:refresh` を 1 日に 1 回実行する (プラグインの取得はこれだけ)([tasks.md](tasks.md#scheduled-runs))。Cost Explorer の API (`ce.us-east-1.amazonaws.com`) には、NAT インスタンス (`network.mode` が `nat`) 経由で接続する。PrivateLink のドキュメントにはインターフェイスエンドポイント `com.amazonaws.<region>.ce` があるが、ほかのリージョンの VPC から使えるかは未確認 ([Redmine Serverless Cost Explorer](https://redmine-kit.github.io/redmine_serverless_costexplorer/ja/))。リクエスト 1 回に USD 0.01 かかる ([cost.md](cost.md#what-adds-cost)) |
| `costExplorer.allocationTag` | | 空 | このインスタンスの費用だけを表示するための、コスト配分タグ (たとえば `redmine:instance`)。`redmine-task` に `REDMINE_COSTEXPLORER_TAG_KEY` として渡す。タグは、請求コンソールでコスト配分タグとして有効にしておく |
| `schedule.timezone` | | `UTC` | 定期実行する rake のタイムゾーン ([tasks.md](tasks.md#scheduled-runs)) |
| `schedule.sendReminders` | | `false` | 平日の朝に、期日が近いチケットのメール (`redmine:send_reminders`) を送信するか |
| `logs.retentionDays` | | 90 | CloudWatch Logs の保持日数 (Lambda@Edge のロググループを含む) |
| `retention.recordsDays` | | 90 | プラグインの記録 (受信したメール、失敗したジョブ) の保持日数 |
| `retention.mailDays` | | 30 | メールバケットのメール (`processed/` と `inbound/`) の保持日数 |
| `retention.noncurrentVersionDays` | | 30 | 添付ファイルの古いバージョンの保持日数 |
| `retention.backupDays` | | 7 | RDS の自動バックアップの保持日数 (35 まで)。割り当てたストレージのサイズまでは無料 ([rds.md](rds.md#settings)) |
| `alarms.snsTopicArn` | | なし | アラームの通知先の SNS トピック |
| `tags` | | なし | すべてのスタック、つまりすべてのリソースに追加するタグ |

`mail.perProjectAddresses`、`mail.globalLocalPart`、`webhooks`、`cloudfront.plan`、`retention.recordsDays` は、スキーマで検証するだけで、スタックではまだ使いません。今後作るプラグインの設定と CloudFront のプランで有効になります。

保持期間の一覧は、[security.md](security.md#retention-periods) にあります。

設定ファイルの形式は JSON Schema (`schema/redmine.schema.json`) で定義し、デプロイコマンドが最初に検証します。

<a id="example"></a>

### 例

```json
{
  "region": "ap-northeast-1",
  "deployRoleArn": "arn:aws:iam::111122223333:role/redmine-infra-deploy",
  "domain": "redmine.example.com",
  "dns": { "hostedZoneId": "Z0123456789ABCDEFGHIJ" },
  "database": { "majorVersion": "17" },
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

<a id="adding-plugins-and-themes"></a>

### プラグインとテーマの追加

プラグインとテーマは、インスタンスごとに `image.plugins` と `image.themes` で追加します。どれもバージョンを固定して指定します。gem はバージョンを完全に指定し、Git のリポジトリはタグかコミットを指定し、ディレクトリは `redmine.json` の隣に置きます。ブランチは指定できないので、同じ設定からは毎回同じプラグインがビルドされます。

```json
{
  "image": {
    "plugins": [
      { "name": "redmine_example", "version": "1.2.0" },
      { "name": "redmine_example_private", "version": "0.3.1", "source": "https://rubygems.pkg.github.com/example" },
      { "name": "redmine_example_git", "git": "https://github.com/example/redmine_example_git.git", "ref": "v2.0.1" },
      { "name": "redmine_example_local", "path": "plugins/redmine_example_local" }
    ],
    "themes": [
      { "name": "example", "git": "https://github.com/example/redmine-theme-example.git", "ref": "3f2c9a1e5b7d4c6a8e0f1b2d3c4e5f6a7b8c9d0e" },
      { "name": "example-local", "path": "themes/example-local" }
    ]
  },
  "redmine": {
    "pluginSettings": { "redmine_example": { "enabled": "1" } }
  }
}
```

どちらかのリストが空でなければ、`bin/deploy` は、下の手順の前に、実行しているマシンで派生イメージをビルドします。ベースは `image.repository` と `image.digest` のイメージです (指定がなければ、リストがないときと同じく Redmine のバージョンのタグ)。`bin/build-derived-image` は、プラグインを `plugins/` に、テーマを `themes/` に配置し、プラグインの gem とプラグインの Gemfile にある gem を、ベースイメージのロックに追加します。gem のプラグインは、ベースイメージと同じく `plugins/` にリンクし、アセットを再生成します (`assets:precompile`)。そのあと、追加したプラグインとテーマの確認を加えたイメージテストを実行し ([testing.md](testing.md#image-tests))、手順 5 でアカウントの ECR にプッシュします。続く手順で、テーマのアセットを含めて S3 にアップロードし、追加したプラグインのマイグレーション (`redmine:plugins:migrate`) を実行し、関数のイメージを更新します。追加したプラグインの設定も、ほかのプラグインと同じく `redmine.pluginSettings` で指定できます。

派生イメージでも、ベースイメージの gem のバージョンは変えません。追加したプラグインが、このプロジェクトでテストした内容を変えないようにするためです。Bundler は、追加する gem のバージョンを、ベースイメージの gem と両立するものから選びます。追加したプラグインがベースイメージの gem の別のバージョンを必要とする場合は、ビルドが失敗し、その gem の名前を表示します。ベースイメージの gem で動くバージョンのプラグインを選ぶか、プラグインが必要とするバージョンを持つベースイメージを使います。

Git の取得元には、HTTPS の公開リポジトリだけを指定できます。ビルドでは、BuildKit が `refs/tags/<ref>` かそのコミットを、認証情報なしで取得します。認証情報が必要なリポジトリは取得できず、ビルドはその旨のメッセージを表示して止まります。非公開のプラグインやテーマは、`redmine.json` の隣にチェックアウトして `path` で指定するか、プラグインなら gem として公開します。

RubyGems の gem には、認証情報は不要です。GitHub Packages 用の Bundler の認証情報は、環境変数 `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` (`x-access-token:<read:packages を持つトークン>`) から取得します。この変数がなく、`gh` がインストールされていれば、`gh` のログインから取得します。BuildKit のシークレットとしてビルドに渡すので、レイヤーにも `redmine.json` にも残りません。リストがなければ何もビルドせず、これまでどおりイメージをコピーします。

デプロイせずに派生イメージをビルドしてテストするには、同じスクリプトを実行します。

```sh
bin/build-derived-image path/to/redmine.json ghcr.io/redmine-kit/serverless@sha256:<digest> redmine-derived:local
bin/test-image redmine-derived:local path/to/redmine.json
```

`image.repository` に、このプロジェクトのイメージをベースにした独自のテストを持つイメージを指定する場合は、`DERIVED_IMAGE_TESTS` に、`bin/test-image` の代わりに派生イメージをテストするコマンドを指定します。コマンドには、イメージと `redmine.json` を引数として渡します。

リストで表せないものは、これまでどおり、このプロジェクトのイメージをベースにした Dockerfile を自分で書き、`image.repository` で指定できます ([architecture.md](architecture.md#derived-images))。

<a id="deployment-commands"></a>

## デプロイコマンド

`bin/deploy` に必要なのは Docker だけです。ツールのイメージ (`deploy/Dockerfile`。AWS CLI、jq、OpenSSL、crane、check-jsonschema を、バージョンを固定してインストールする。Python のパッケージはハッシュで固定する) をビルドし、その中で `deploy/deploy.sh` を実行します。AWS 認証情報は、`AWS_*` 環境変数か、`~/.aws` (読み取り専用) から取得します。`image.plugins` か `image.themes` を指定する場合は、派生イメージのビルドとテストのために、Docker Buildx、jq、curl も必要です。

```sh
bin/deploy path/to/redmine.json --account    # アカウントごとに 1 回、管理者が
bin/deploy path/to/redmine.json --dry-run    # 変わるものを表示するだけ
bin/deploy path/to/redmine.json              # 作成する、更新する
bin/deploy path/to/redmine.json --code-only  # イメージだけを更新する
```

| 手順 | 内容 |
| --- | --- |
| 1 | 設定ファイルを JSON Schema で検証し、`deployRoleArn` のロールを引き受ける (認証情報がすでにそのロールのものなら、そのまま) |
| 2 | 共有基盤のスタック (`redmine-shared` と、us-east-1 の `redmine-shared-edge`) を作成または更新する。`mail.receive` が有効なら、共有の受信ルールセットをアクティブにする |
| 3 | シークレットが SSM になければ生成する。あれば変更しない (下の「シークレット」)。RDS は作成時にデータベースパスワードを SSM から読み込むので、インスタンスのスタックより先に行う |
| 4 | us-east-1 の `<instance>-edge` (証明書と Web ACL) を作成または更新する。Lambda@Edge が各リージョンに作成したロググループに、`logs.retentionDays` を適用する ([security.md](security.md#retention-periods)) |
| 5 | イメージを、crane で digest のまま、そのアカウントの ECR にコピーする (Lambda は、同じリージョンの ECR イメージしか使えない)。`image.plugins` と `image.themes` の派生イメージは、手順 1 の前にビルドしてテストしたものをプッシュする。リポジトリのタグはイミュータブルなので、タグは digest から作る (`sha256-<hex>`)。すでにあるイメージはコピーしない |
| 6 | イメージ内のアセットを、メンテナンス画面 (`deploy/maintenance.html`) と一緒に S3 (`/assets/`) に同期する。ブラウザーで開いたままのページのために、古いファイルは残す |
| 7 | 初回は、インスタンスのスタック `<instance>` を、そのイメージで作成する。2 回目以降は、`redmine-task` が現在使っているイメージのままスタックを更新し、そのあと `redmine-task` を新しいイメージに更新する。それから `redmine-task` で `db:migrate` と `redmine:plugins:migrate` を実行する |
| 8 | 初回は、`redmine-task` で初期データを投入する (`redmine:load_default_data`。言語は `redmine.settings.default_language`。なければ英語) |
| 9 | `redmine-web` と `redmine-worker` を新しいイメージに更新する。スタックがイメージを管理するように、スタック経由で更新する |
| 10 | Redmine とプラグインの設定を、`redmine-task` の `rails runner` で書き込む (`redmine.settingsMode` のとおり)。値は JSON を 16 進数にして渡すので、引用符の問題は Ruby に影響しない |
| 11 | デプロイ後の確認。`/login` が `Strict-Transport-Security` 付きの 200 を返し、署名のない `/files/` が 403 を返すこと。リクエストは、ドメインのホスト名のまま、ディストリビューション自体のドメイン名に送るので、DNS の反映を待たない ([testing.md](testing.md#checks-after-deployment))。`dns.mode` が `external` なら、追加するレコードを表示する |

<a id="options"></a>

### オプション

| オプション | 内容 |
| --- | --- |
| `--account` | `infra/account.yaml` (スタック `redmine-account`) を、管理者自身の認証情報で適用する。それより前には、デプロイ用ロールも CloudFormation のサービスロールもないため。アカウントごとに 1 回、最初のデプロイの前に実行する |
| `--dry-run` | 手順 1〜4 とインスタンスのスタックについて、変更セットを作成して表示し、削除する。新規に作成されるはずのスタックも削除する。シークレット、イメージ、アセット、関数の呼び出しなど、ほかは何も変更しない (直接渡すには大きすぎるテンプレートだけは、テンプレートバケットに置く)。派生イメージは、ローカルのマシンでビルドしてテストするので、ビルドできないプラグインはここでわかる |
| `--code-only` | 手順 5〜7、9、11 を、スタックを変更せずに、渡された認証情報で実行する (たとえば、GitHub Actions のコードデプロイ用ロール。[iam.md](iam.md#role-for-deploying-code-github-actions))。関数は直接更新する。デプロイ済みのインスタンスが必要 |

<a id="how-the-steps-behave"></a>

### 手順の動作

Web と worker が新しいイメージになるのは、マイグレーションのあとです。そのため、データベースより新しいコードが動くことはありません。マイグレーションが失敗すると、デプロイはそこで止まり、Web と worker は前のイメージのままです。

どのスタックも、サービスロール `redmine-cfn-exec` を指定した変更セットで適用します。デプロイ用ロールは、自身ではリソースを作成できません ([iam.md](iam.md#role-for-deploying-infrastructure))。同じ設定でもう一度実行しても、何も変わりません。変更のない変更セットは削除してスタックはそのままにし、イメージは再コピーせず、マイグレーションも何もしません。例外は、Docker のビルドキャッシュがない場合 (別のマシンや、キャッシュを削除したあと) の派生イメージです。新しい digest でビルドし直すので、関数のイメージが更新されます。

このプロジェクトの CI が、イメージを GitHub Packages のコンテナレジストリ (`ghcr.io`) に公開します ([architecture.md](architecture.md#distribution))。デプロイコマンドは digest のままコピーするので、ECR のイメージも同じ digest です。

多数のインスタンスを構築するときは、インスタンスの数だけ同じコマンドを繰り返します。順序 (たとえば、検証用の小さなインスタンスから) は、アダプタが決めます。

<a id="maintenance-page"></a>

### メンテナンス画面

`redmine-web` と `redmine-worker` の予約された同時実行を 0 にすると、書き込みを止められます (インシデント対応時など。[security.md](security.md))。CloudFront は、関数 URL からの 502、503、504 に対して、S3 のメンテナンス画面 (`/assets/maintenance.html`) を返します。ただし、`redmine-web` の予約された同時実行が 0 のあいだは関数 URL が 429 を返し、CloudFront のカスタムエラーレスポンスでは 429 を置き換えられないので、ブラウザーにはその 429 が返ります (下の「未確認の事項」)。

<a id="secrets"></a>

### シークレット

CloudFormation は SecureString パラメーターを作成できないので、`bin/deploy` が手順 3 で作成します。値を表示することも、コマンドラインに置くこともありません。値は、標準入力の JSON で AWS CLI に渡します。

| パラメーター | タイプ | 値 |
| --- | --- | --- |
| `/<instance>/env/SECRET_KEY_BASE` | SecureString | 64 バイトの乱数の 16 進数 |
| `/<instance>/env/REDMINE_DB_PASSWORD` | SecureString | 32 バイトの乱数の 16 進数 (RDS が受け付けない文字を含まない)。RDS は動的参照 (`{{resolve:ssm-secure:…}}`) で受け取る |
| `/<instance>/env/REDMINE_CLOUDFRONT_PRIVATE_KEY` | SecureString | 添付ファイルの署名付き URL 用のキーペアの秘密鍵 (RSA 2048) |
| `/<instance>/deploy/CLOUDFRONT_PUBLIC_KEY` | String | その公開鍵。インスタンスのスタックが CloudFront に登録する (キーグループ `<instance>-attachments`)。`env/` の下ではないので、関数は読み込まない |

<a id="templates"></a>

### テンプレート

スタックは、`infra/` に CloudFormation で記述します。`bin/lint` が cfn-lint で検査します。

| ファイル | スタック | 内容 |
| --- | --- | --- |
| `infra/account.yaml` | `redmine-account` | アクセス許可の境界 `redmine-boundary`、CloudFormation のサービスロール `redmine-cfn-exec`、ロール `redmine-infra-deploy` と `redmine-github-deploy`、必要な場合は GitHub の OIDC プロバイダー ([iam.md](iam.md#account-roles))。アカウントになければ、CloudTrail の証跡と IAM Access Analyzer のアナライザー ([aws-security.md](aws-security.md)) |
| `infra/shared.yaml` | `redmine-shared` | ECR リポジトリ、直接渡すには大きすぎるテンプレート用のバケット、2 つの AZ のプライベートサブネットを持つ VPC、S3 のゲートウェイエンドポイント、共有の SES 受信ルールセット、外部への経路。外部への経路は、1 つの AZ の SSM、SQS、SES のインターフェイスエンドポイント (`network.mode` が `endpoints`) か、NAT インスタンス (`nat`。インターネットゲートウェイ、パブリックサブネット、起動時に Elastic IP とルートを引き継ぐ 1 台構成の Auto Scaling グループ。[rds.md](rds.md#setup-2-nat-instance)) |
| `infra/shared-edge.yaml` | `redmine-shared-edge` (us-east-1) | Lambda@Edge 関数 `redmine-body-hash` (Node.js 24。コードは `edge/body-hash/index.js` をそのまま埋め込む) と、そのバージョン。コードが変わると、新しいバージョンを作成する |
| `infra/instance-edge.yaml` | `<instance>-edge` (us-east-1) | ドメインの ACM 証明書 (DNS 検証) と、`cloudfront.webAclArn` がなければ AWS WAF の Web ACL ([security.md](security.md#rules)) |
| `infra/instance.yaml` | `<instance>` | RDS for PostgreSQL。添付ファイル、アセット、メールのバケット。ジョブキュー、そのデッドレターキュー、失敗したタスク呼び出しのキュー。3 つの関数と、そのロールとロググループ。worker の SQS イベントソース。CloudFront (OAC、リクエスト本文のハッシュを追加する関数、署名付き URL の添付ファイルのビヘイビア、CloudFront Function `<instance>-incoming-size`、メンテナンス画面)。DNS レコード。SES の ID と受信ルール。EventBridge Scheduler のスケジュール。アラーム。`tmp/incoming/` と `imports/` の GuardDuty Malware Protection for S3 ([aws-security.md](aws-security.md#malware-protection-for-s3)) |

- **イメージ:** インスタンスのスタックは、そのアカウントの ECR のイメージを digest で受け取ります (`ImageUri`)。
- **PostgreSQL のバージョン:** `DbMajorVersion` にはデフォルト値を設定しません ([rds.md](rds.md#database))。
- **ロール:** スタックが作成するロールは、どれもパス `/redmine/` とアクセス許可の境界 `redmine-boundary` を持ちます ([iam.md](iam.md#account-roles))。

<a id="to-verify"></a>

## 未確認の事項

- SES の受信ルールセットを共有基盤に置き、インスタンスのスタックからルールを追加する構成を、CloudFormation で作成できるか
- RDS インスタンスが、作成時と更新時に、`ssm-secure` の動的参照でパスワードを受け取れるか (CloudFormation のドキュメントでは対応しているプロパティ。まだ試していない)
- crane が `ghcr.io` からコピーしたイメージ (同じ digest) を、Lambda が実行できるか。初回のコピーにかかる時間
- 実際の AWS で、派生イメージを tarball から ECR にプッシュできるか (手順 5)。LocalStack の ECR でだけテストしていて、プッシュしたイメージを LocalStack の Lambda が実行する ([testing.md](testing.md#lambda-integration-tests))
- 実際のアカウントでの `bin/deploy` 全体の動作。現在は、AWS CLI のスタブと LocalStack でだけテストしている ([testing.md](testing.md#deployment-tests))
- `redmine-web` の予約された同時実行が 0 のあいだ、ブラウザーに何が表示されるか (CloudFront 経由の関数 URL の 429)。メンテナンス画面を表示する別の方法が必要か
