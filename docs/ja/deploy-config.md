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
| Lambda の関数 | `<instance>-web`<br>`<instance>-worker`<br>`<instance>-task` |
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

| 保存先 | リソース | 理由 |
| --- | --- | --- |
| 共有の土台 | ECR のリポジトリ | 同じバージョンのイメージを、インスタンスのあいだで使い回す |
| 共有の土台(us-east-1) | Lambda@Edge の関数 `redmine-body-hash`(スタック `redmine-shared-edge`) | Lambda@Edge の関数は us-east-1 に作る決まり。同じコードを、インスタンスのあいだで使い回す([lambda.md](lambda.md#function-that-adds-the-body-hash-lambdaedge)) |
| 共有の土台 | VPC、プライベートのサブネット、S3 のゲートウェイのエンドポイント、VPC のエンドポイントか NAT インスタンス(`network.shared`) | エンドポイントと NAT インスタンスには月の決まった費用がかかるので、インスタンスのあいだで分け合う([rds.md](rds.md#routes-out-of-the-vpc)) |
| 共有の土台 | SES の受信のルールのセット | 有効なルールのセットは、リージョンに 1 つだけ。インスタンスごとに、セットの中にルールを足す([mail.md](mail.md#receipt-rules)) |
| インスタンスごと | Lambda の関数、RDS のインスタンス、セキュリティグループ、S3 のバケット、SQS のキュー、CloudFront、DNS のレコード、SES の ID、SSM のパラメーター、アラーム | インスタンスのデータと権限を、ほかのインスタンスと混ぜない |

Redmine を 1 つだけ立てるときは、共有の土台とインスタンスを 1 つずつ立てます。手順は同じです。

Lambda@Edge の関数のほかに、CloudFront の証明書(ACM)も us-east-1 に作ります。CloudFront がそこに置くことを求めるためです。証明書はインスタンスごとに、us-east-1 のスタック `<instance>-edge` に置きます。

インスタンスごとの Lambda の関数と RDS のインスタンスは、共有のプライベートサブネットに、それぞれのセキュリティグループで入ります。`network.shared` を `false` にすると、代わりにインスタンスごとに VPC を作ります([rds.md](rds.md))。

<a id="fields-of-redminejson"></a>

## `redmine.json` の項目

| 項目 | 必須 | 既定値 | 内容 |
| --- | --- | --- | --- |
| `instance` | | `redmine` | インスタンスの名前。英小文字、数字、`-` で 20 文字まで。同じアカウントに 2 つ目を立てるときに付ける |
| `region` | ○ | | 立てるリージョン |
| `deployRoleArn` | ○ | | デプロイのコマンドが引き受けるロール。立てるアカウントの、インフラのデプロイ用のロールを指す([iam.md](iam.md#role-for-deploying-infrastructure)) |
| `domain` | ○ | | Web とメールのホスト名(たとえば `redmine.example.com`) |
| `dns.mode` | | `route53` | `route53`(Route 53 のホストゾーンに置く)か `external`(ほかの DNS に、表示したレコードを自分で置く)([mail.md](mail.md#receiving-domain)) |
| `dns.hostedZoneId` | `route53` のとき | | ドメインの Route 53 のホストゾーン |
| `account.*` | | | アカウントのスタックの設定。`bin/deploy --account` だけが使う。ロール(`ssoPermissionSet`。既定は `AdministratorAccess`。`githubRepository`。`owner/repository`。なければ GitHub Actions のロールは作らない。`githubInfraEnvironment`。既定は `infrastructure`。`githubCodeEnvironment`。既定は `production`。`githubOidcProviderArn`。アカウントに GitHub の OIDC のプロバイダーがすでにあるとき。[iam.md](iam.md#account-roles))と、アカウントのセキュリティの設定(`cloudTrail` と `accessAnalyzer`。既定では、アカウントになければ作る。`trailDays`。既定は 365。`unusedAccessAnalyzer`。既定は `false`。[aws-security.md](aws-security.md)) |
| `network.mode` | | `endpoints` | VPC の外への道。`endpoints`(VPC のエンドポイント。インターネットへの出口なし)か `nat`(NAT インスタンス。webhook や外の API に届く)([rds.md](rds.md#which-to-choose)) |
| `network.shared` | | `true` | 共有の土台のネットワークを使うか。今は `true` だけ。インスタンスごとの VPC は作っていない |
| `database.majorVersion` | ○ | | PostgreSQL のメジャーバージョン(たとえば `"17"`)。インスタンスを作るときに、RDS が出しているバージョンと照らして確認する([rds.md](rds.md#database)) |
| `database.instanceClass` | | `db.t4g.micro` | RDS のインスタンスの種類 |
| `database.storageGb` | | 20 | RDS のストレージ(gp3) |
| `lambda.webMemoryMb` | | 2048 | `redmine-web` のメモリ |
| `lambda.webReservedConcurrency` | | 10 | `redmine-web` の同時実行数の予約 |
| `lambda.workerReservedConcurrency` | | 3 | `redmine-worker` の同時実行数の予約。`redmine-task` は 2 で決め打ち([tasks.md](tasks.md#kinds-of-events)) |
| `lambda.warmup` | | `false` | 業務時間の温めの呼び出しをするか([lambda.md](lambda.md#waiting-for-start-up))。今は `false` だけ |
| `uploads.malwareScan` | | `true` | GuardDuty Malware Protection for S3 で、Redmine が読む前に、アップロードとインポートをスキャンするか([aws-security.md](aws-security.md#malware-protection-for-s3))。`false` で止める |
| `uploads.maxBytes` | | 104857600(100 MB) | 添付ファイルの大きさの上限。`/incoming/*` の CloudFront Function が、これより大きいアップロードを 413 で断る。段 10 で、Redmine の添付ファイルの最大の大きさ(`attachment_max_size`。KB)も、`redmine.settings` に書いていなければ同じ上限にする |
| `mail.receive` | | `true` | メールの受信を使うか |
| `mail.perProjectAddresses` | | `false` | プロジェクトごとのアドレスを使うか。`false` なら Redmine の標準と同じ([mail.md](mail.md#addresses-per-project)) |
| `mail.globalLocalPart` | | `redmine` | 全体用のアドレスの `@` の前 |
| `webhooks` | | `false` | Redmine の webhook の設定(`webhooks_enabled`)の初めの値。webhook は `network.mode` が `nat` のときだけ使える([lambda.md](lambda.md#background-jobs)) |
| `cloudfront.plan` | | `free` | CloudFront の料金のプラン。`free`、`pro`、`payg`(従量)([security.md](security.md#plan-and-cost)) |
| `cloudfront.webAclArn` | | なし | 自分で用意した Web ACL(us-east-1)を使うとき。指定すると、`waf.*` は使わない |
| `waf.loginRateLimit` | | 20 | WAF のログインの回数の制限(5 分あたり。[security.md](security.md#rules)) |
| `waf.rateLimit` | | 1000 | WAF の全体の回数の制限(5 分あたり) |
| `waf.commonRuleSet` | | `count` | WAF の Common Rule Set を、`count`(数えるだけ)にするか `block`(止める)にするか |
| `waf.commonRuleSetCountOnly` | | `["SizeRestrictions_BODY"]` | `block` のときも、数えるだけにするルール(1 つ) |
| `image.repository` | | `ghcr.io/redmine-kit/serverless` | 使うイメージ。使う側が作った派生のイメージ(テーマやプラグインを足したもの)は、ここで指定する([architecture.md](architecture.md#derived-images))。Redmine のバージョンはイメージで決まる。バージョンアップの前の確認の方法は [upgrade.md](upgrade.md) |
| `image.digest` | `image` を書くとき | その時点の、Redmine のバージョンのタグの digest | イメージの digest(`sha256:…`)。書かないと、`bin/deploy` は、このチェックアウトがビルドする Redmine のバージョンのタグ(たとえば `7.0.3`。`image/Dockerfile` の `ARG REDMINE_VERSION`)の、その時点の digest を使い、固定できるように表示する |
| `redmine.settings` | | なし | Redmine の管理画面の設定の値(`host_name`、`default_language`、`mail_from` など) |
| `redmine.settingsMode` | | `initial` | `initial`(まだ保存されていない設定だけ入れる。あとは画面で変えられる)か `enforce`(デプロイのたびに入れ直す) |
| `redmine.pluginSettings` | | なし | プラグインの設定の値。プラグインの名前(`redmine_serverless`、`redmine_serverless_s3`、`redmine_serverless_ses`、`redmine_serverless_sqs`)ごとに書く。保存されている設定に足し合わせる。たとえば `{"redmine_serverless_ses": {"import_spam": "0", "import_without_dmarc_pass": "0"}}` で、迷惑メールと DMARC が通らないメールを取り込まない(既定の値。[receiving.md](https://redmine-kit.github.io/redmine_serverless_ses/ja/receiving.html#spoofing-and-spam)) |
| `costExplorer.enabled` | | `false` | プラグイン `redmine_serverless_costexplorer` を足したイメージ(派生のイメージ。Serverless のイメージには入っていない)のための設定。プラグインが、Cost Explorer からアカウントの費用を取り、管理画面に出すか。`redmine-web` と `redmine-task` に `REDMINE_COSTEXPLORER_ENABLED` を渡し、`redmine-task` に `ce:GetCostAndUsage` と `ce:GetCostForecast` を許し、`redmine_serverless_costexplorer:refresh` を 1 日に 1 回動かす(プラグインの取得はこれだけ)([tasks.md](tasks.md#scheduled-runs))。Cost Explorer の API(`ce.us-east-1.amazonaws.com`)には、NAT インスタンス(`network.mode` が `nat`)を通って届く。PrivateLink の資料にはインターフェースのエンドポイント `com.amazonaws.<region>.ce` があるが、ほかのリージョンの VPC から使えるかは未確認([Redmine Serverless Cost Explorer](https://redmine-kit.github.io/redmine_serverless_costexplorer/ja/))。要求 1 回に USD 0.01 かかる([cost.md](cost.md#what-adds-cost)) |
| `costExplorer.allocationTag` | | 空 | このインスタンスの費用だけを出すための、コスト配分タグ(たとえば `redmine:instance`)。`redmine-task` に `REDMINE_COSTEXPLORER_TAG_KEY` として渡す。タグは、請求のコンソールでコスト配分タグとして有効にしておく |
| `schedule.timezone` | | `UTC` | 定期の rake のタイムゾーン([tasks.md](tasks.md#scheduled-runs)) |
| `schedule.sendReminders` | | `false` | 平日の朝に、期日の近いチケットのメール(`redmine:send_reminders`)を送るか |
| `logs.retentionDays` | | 90 | CloudWatch Logs の保持の日数(Lambda@Edge のロググループを含む) |
| `retention.recordsDays` | | 90 | プラグインの記録(受け取ったメール、失敗したジョブ)を残す日数 |
| `retention.mailDays` | | 30 | メールのバケットのメール(`processed/` と `inbound/`)を残す日数 |
| `retention.noncurrentVersionDays` | | 30 | 添付ファイルの古いバージョンを残す日数 |
| `retention.backupDays` | | 7 | RDS の自動のバックアップを残す日数(35 まで)。割り当てたストレージの大きさまでは無料([rds.md](rds.md#settings)) |
| `alarms.snsTopicArn` | | なし | アラームを送る SNS のトピック |
| `tags` | | なし | すべてのスタックに、つまりリソースに足すタグ |

`mail.perProjectAddresses`、`mail.globalLocalPart`、`webhooks`、`cloudfront.plan`、`retention.recordsDays` は、スキーマで確認するだけで、スタックはまだ使いません。あとで作るプラグインの設定と CloudFront のプランで効くようになります。

保持の期間の一覧は、[security.md](security.md#retention-periods) にあります。

設定のファイルの形は、JSON Schema(`schema/redmine.schema.json`)で決め、デプロイのコマンドが最初に確認します。

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

<a id="deployment-commands"></a>

## デプロイのコマンド

`bin/deploy` に要るのは Docker だけです。道具のイメージ(`deploy/Dockerfile`。AWS CLI、jq、OpenSSL、crane、check-jsonschema を、バージョンを固定して入れる。Python のパッケージはハッシュで固定する)を作り、その中で `deploy/deploy.sh` を動かします。AWS の認証情報は、`AWS_*` の環境変数か、`~/.aws`(読むだけ)から取ります。

```sh
bin/deploy path/to/redmine.json --account    # アカウントごとに 1 回、管理者が
bin/deploy path/to/redmine.json --dry-run    # 変わるものを表示するだけ
bin/deploy path/to/redmine.json              # 立てる、更新する
bin/deploy path/to/redmine.json --code-only  # イメージだけを更新する
```

| 段 | すること |
| --- | --- |
| 1 | 設定のファイルを JSON Schema で確認し、`deployRoleArn` を引き受ける(認証情報がすでにそのロールのものなら、そのまま) |
| 2 | 共有の土台のスタック(`redmine-shared` と、us-east-1 の `redmine-shared-edge`)を、作るか更新する。`mail.receive` なら、共有の受信のルールのセットを有効にする |
| 3 | 秘密の値が SSM に無ければ作る。あれば変えない(下の「秘密の値」)。RDS は作るときにデータベースのパスワードを SSM から読むので、インスタンスのスタックより先に行う |
| 4 | us-east-1 の `<instance>-edge`(証明書と Web ACL)を、作るか更新する。Lambda@Edge が各リージョンに作ったロググループに、`logs.retentionDays` を当てる([security.md](security.md#retention-periods)) |
| 5 | イメージを、crane で digest のまま、そのアカウントの ECR にコピーする(Lambda は、同じリージョンの ECR のイメージしか使えない)。リポジトリのタグは変えられないので、タグは digest から作る(`sha256-<hex>`)。すでにあるイメージはコピーしない |
| 6 | イメージの中のアセットを、保守の画面(`deploy/maintenance.html`)と一緒に S3(`/assets/`)に同期する。ブラウザーで開いたままのページのために、古いファイルは残す |
| 7 | 初めてのときは、インスタンスのスタック `<instance>` を、そのイメージで作る。2 回目からは、`redmine-task` が今動かしているイメージのままスタックを更新し、そのあと `redmine-task` に新しいイメージを入れる。それから `redmine-task` で `db:migrate` と `redmine:plugins:migrate` を実行する |
| 8 | 初めてのときは、`redmine-task` で初めのデータを入れる(`redmine:load_default_data`。言語は `redmine.settings.default_language`。なければ英語) |
| 9 | `redmine-web` と `redmine-worker` に新しいイメージを入れる。スタックがイメージを持つように、スタックを通して入れる |
| 10 | Redmine とプラグインの設定を、`redmine-task` の `rails runner` で入れる(`redmine.settingsMode` のとおり)。値は JSON を 16 進にして渡すので、Ruby に引用符の問題は届かない |
| 11 | デプロイしたあとの確認。`/login` が `Strict-Transport-Security` 付きの 200 を返し、署名のない `/files/` が 403 を返すこと。要求は、ドメインのホスト名のまま、ディストリビューションそのものの名前に送るので、DNS を待たない([testing.md](testing.md#checks-after-deployment))。`dns.mode` が `external` なら、足すレコードを表示する |

<a id="options"></a>

### オプション

| オプション | 内容 |
| --- | --- |
| `--account` | `infra/account.yaml`(スタック `redmine-account`)を、管理者の自分の認証情報で適用する。それより前には、デプロイ用のロールも CloudFormation のサービスロールもないため。アカウントごとに 1 回、最初のデプロイの前に実行する |
| `--dry-run` | 段 1〜4 とインスタンスのスタックについて、変更セットを作って表示し、消す。作られるはずのスタックも消す。秘密の値、イメージ、アセット、関数の呼び出しなど、ほかは何も変えない(そのまま渡すには大きすぎるテンプレートだけは、テンプレートのバケットに置く) |
| `--code-only` | 段 5〜7、9、11 を、スタックを変えずに、渡された認証情報で実行する(たとえば、GitHub Actions のコードのデプロイ用のロール。[iam.md](iam.md#role-for-deploying-code-github-actions))。関数は直接更新する。デプロイ済みのインスタンスが要る |

<a id="how-the-steps-behave"></a>

### 手順の動き

Web と worker が新しいイメージになるのは、マイグレーションのあとです。そのため、データベースより新しいコードが動くことはありません。マイグレーションが失敗すると、デプロイはそこで止まり、Web と worker は前のイメージのままです。

どのスタックも、サービスロール `redmine-cfn-exec` を付けた変更セットで適用します。デプロイ用のロールは、自分ではリソースを作れません([iam.md](iam.md#role-for-deploying-infrastructure))。同じ設定でもう一度実行しても、何も変わりません。変更のない変更セットは消してスタックはそのままにし、イメージはコピーし直さず、マイグレーションも何もしません。

このプロジェクトの CI が、イメージを GitHub Packages のコンテナのレジストリ(`ghcr.io`)に公開します([architecture.md](architecture.md#distribution))。デプロイのコマンドは digest のままコピーするので、ECR のイメージも同じ digest です。

多くのインスタンスを立てるときは、インスタンスの数だけ同じコマンドを繰り返します。順番(たとえば、試すための小さなインスタンスから)は、使う側で決めます。

<a id="maintenance-page"></a>

### 保守の画面

`redmine-web` と `redmine-worker` の同時実行数の予約を 0 にすると、書き込みを止められます(事故のときなど。[security.md](security.md))。CloudFront は、関数 URL からの 502、503、504 に対して、S3 の保守の画面(`/assets/maintenance.html`)を返します。ただし、`redmine-web` の同時実行数の予約が 0 のあいだは関数 URL が 429 を返し、CloudFront のエラーの応答の設定は 429 を置き換えられないので、ブラウザーにはその 429 が届きます(下の「未確認の事項」)。

<a id="secrets"></a>

### 秘密の値

CloudFormation は SecureString のパラメーターを作れないので、`bin/deploy` が段 3 で作ります。値を表示することも、コマンドラインに置くこともありません。値は、標準入力の JSON で AWS CLI に渡します。

| パラメーター | 種類 | 値 |
| --- | --- | --- |
| `/<instance>/env/SECRET_KEY_BASE` | SecureString | 64 バイトの乱数の 16 進 |
| `/<instance>/env/REDMINE_DB_PASSWORD` | SecureString | 32 バイトの乱数の 16 進(RDS が断る文字を含まない)。RDS は動的な参照(`{{resolve:ssm-secure:…}}`)で受け取る |
| `/<instance>/env/REDMINE_CLOUDFRONT_PRIVATE_KEY` | SecureString | 添付ファイルの署名付き URL のキーペアの秘密鍵(RSA 2048) |
| `/<instance>/deploy/CLOUDFRONT_PUBLIC_KEY` | String | その公開鍵。インスタンスのスタックが CloudFront に登録する(キーグループ `<instance>-attachments`)。`env/` の下ではないので、関数は読み込まない |

<a id="templates"></a>

### テンプレート

スタックは、`infra/` に CloudFormation で書きます。`bin/lint` が cfn-lint で検査します。

| ファイル | スタック | 内容 |
| --- | --- | --- |
| `infra/account.yaml` | `redmine-account` | 権限の境界 `redmine-boundary`、CloudFormation のサービスロール `redmine-cfn-exec`、ロール `redmine-infra-deploy` と `redmine-github-deploy`、要るときは GitHub の OIDC のプロバイダー([iam.md](iam.md#account-roles))。アカウントになければ、CloudTrail の証跡と IAM Access Analyzer のアナライザー([aws-security.md](aws-security.md)) |
| `infra/shared.yaml` | `redmine-shared` | ECR のリポジトリ、そのまま渡すには大きすぎるテンプレートのためのバケット、2 つの AZ のプライベートのサブネットを持つ VPC、S3 のゲートウェイのエンドポイント、共有の SES の受信のルールのセット、外への道。外への道は、1 つの AZ の SSM、SQS、SES のインターフェースのエンドポイント(`network.mode` が `endpoints`)か、NAT インスタンス(`nat`。インターネットゲートウェイ、パブリックのサブネット、起動のときに Elastic IP と経路を引き継ぐ 1 台の Auto Scaling グループ。[rds.md](rds.md#setup-2-nat-instance)) |
| `infra/shared-edge.yaml` | `redmine-shared-edge`(us-east-1) | Lambda@Edge の関数 `redmine-body-hash`(Node.js 24。コードは `edge/body-hash/index.js` をそのまま埋め込む)と、そのバージョン。コードが変わると、新しいバージョンを作る |
| `infra/instance-edge.yaml` | `<instance>-edge`(us-east-1) | ドメインの ACM の証明書(DNS で検証)と、`cloudfront.webAclArn` がなければ AWS WAF の Web ACL([security.md](security.md#rules)) |
| `infra/instance.yaml` | `<instance>` | RDS for PostgreSQL。添付ファイル、アセット、メールのバケット。ジョブのキュー、そのデッドレターキュー、失敗したタスクの呼び出しのキュー。3 つの関数と、そのロールとロググループ。worker の SQS のイベントソース。CloudFront(OAC、本文のハッシュの関数、署名付き URL の添付ファイルのビヘイビア、CloudFront Function `<instance>-incoming-size`、保守の画面)。DNS のレコード。SES の ID と受信のルール。EventBridge Scheduler のスケジュール。アラーム。`incoming/` と `imports/` の GuardDuty Malware Protection for S3([aws-security.md](aws-security.md#malware-protection-for-s3)) |

- **イメージ:** インスタンスのスタックは、そのアカウントの ECR のイメージを、digest で受け取ります(`ImageUri`)。
- **PostgreSQL のバージョン:** `DbMajorVersion` には既定の値を置きません([rds.md](rds.md#database))。
- **ロール:** スタックが作るロールは、どれもパス `/redmine/` と権限の境界 `redmine-boundary` を持ちます([iam.md](iam.md#account-roles))。

<a id="to-verify"></a>

## 未確認の事項

- SES の受信のルールのセットを共有の土台に置き、インスタンスのスタックからルールを足す形が、CloudFormation で作れるか
- RDS のインスタンスが、作るときと更新のときに、`ssm-secure` の動的な参照でパスワードを受け取れるか(CloudFormation の資料では対応しているプロパティ。まだ試していない)
- crane が `ghcr.io` からコピーしたイメージ(同じ digest)を、Lambda が動かせるか。初めてコピーするときにかかる時間
- 本物のアカウントでの `bin/deploy` の全体。今は、偽の AWS CLI と LocalStack でだけテストしている([testing.md](testing.md#deployment-tests))
- `redmine-web` の同時実行数の予約が 0 のあいだ、ブラウザーに何が見えるか(CloudFront を通った関数 URL の 429)。保守の画面を出す別の方法が要るか
