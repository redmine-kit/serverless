# 出典

この資料で参照した情報です。

- 確認日は、行に書いたもののほかは、2026-11-08 です。
- 仕様は変わることがあります。作るときに最新の内容を見直し、確認日を更新してください。

<a id="redmine"></a>

## Redmine

| ページ | 確認したこと |
| --- | --- |
| [Download](https://www.redmine.org/projects/redmine/wiki/Download) | 最新の安定バージョンは 7.0.3(2026-11-01)。6.1 はバグの修正とセキュリティだけ |
| [RedmineInstall](https://www.redmine.org/projects/redmine/wiki/RedmineInstall) | 7.0 の Ruby(3.2〜4.0)、Rails 8.1、データベース(PostgreSQL 14、MySQL 8.0〜8.4 など)、ImageMagick、Ghostscript、Pandoc、ジョブの `:async` は本番に勧めないこと |
| [Changelog 7.0](https://www.redmine.org/projects/redmine/wiki/Changelog_7_0) | 7.0.0〜7.0.3 の日付 |
| [Roadmap](https://www.redmine.org/projects/redmine/roadmap) | 7.1.0 と 7.0.4 が開発中 |
| [EmailConfiguration](https://www.redmine.org/projects/redmine/wiki/EmailConfiguration) | `email_delivery` の書き方 |
| [redmine/redmine の 7.0-stable](https://github.com/redmine/redmine/tree/7.0-stable)(d718d63)。OAuth 2 のプロバイダー(`Gemfile` の doorkeeper、`config/initializers/doorkeeper.rb`)、メーラーのヘッダー(`X-Redmine-Project`)、取り込みのプロジェクトの決め方(`MailHandler#target_project`) | 添付ファイルの処理(`app/models/attachment.rb`、`app/controllers/attachments_controller.rb`、`app/assets/javascripts/attachments.js`)、インポートの一時ファイル、アセットの自動の書き出し、ジョブ、セッション |
| [Docker Hub の redmine](https://hub.docker.com/_/redmine) | 7.0.3 のタグ、arm64 のビルド(2026-11-06 に更新) |
| [docker-library/redmine の 7.0 の Dockerfile(trixie)](https://github.com/docker-library/redmine/blob/master/7.0/trixie/Dockerfile) | 公式のイメージの土台(`ruby:4.0-slim-trixie`)、入っているツール、権限、入口。Redmine 7.0.3 の tar.gz の SHA256 |

<a id="redmines-s3-plugin-reference"></a>

## Redmine の S3 のプラグイン(参考)

| ページ | 確認したこと |
| --- | --- |
| [hgyoon-w/redmine5_amazon_s3](https://github.com/hgyoon-w/redmine5_amazon_s3) | 1.0.0、最後のコミットは 2025-12-17、Redmine 5.0 以上。保存、削除、ダウンロードとサムネイルのリダイレクト、`thumbnail_tag` の差し替え。digest を保存の時刻に置き換える |
| [redmine_cloud_attachment_pro](https://www.redmine.org/plugins/redmine_cloud_attachment_pro) | 0.0.1、Redmine 4.0〜6.1。`diskfile` のたびに S3 から一時ファイルに取る |
| [ka8725/redmine_s3](https://github.com/ka8725/redmine_s3) | 古くからある S3 のプラグイン(Redmine 3 系のころ) |

<a id="rails"></a>

## Rails

| ページ | 確認したこと |
| --- | --- |
| [railties の configuration.rb(v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/configuration.rb) | キャッシュの既定(ファイル)、`SECRET_KEY_BASE` の読み方 |
| [activejob の railtie(v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activejob/lib/active_job/railtie.rb) | ジョブのアダプターの既定は `:async` |
| [mail_delivery_job.rb(v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionmailer/lib/action_mailer/mail_delivery_job.rb) | メールのジョブは、例外をメーラーの `handle_exception` に渡す(処理がなければ例外のまま) |
| [Propshaft の railtie(v1.3.1)](https://github.com/rails/propshaft/blob/v1.3.1/lib/propshaft/railtie.rb) | アセットの出力先 `public/assets` |
| [active_record.rb(v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record.rb) | `dump_schema_after_migration` の既定は `true` |
| [databases.rake(v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/railties/databases.rake) | `db:migrate` のあとにスキーマを書き出す |
| [bootstrap.rb(v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/bootstrap.rb) | キャッシュは `initialize_cache` で、アプリの initializer より前に作る |

<a id="aws-lambda"></a>

## AWS Lambda

| ページ | 確認したこと |
| --- | --- |
| [Lambda runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html) | `ruby4.0` と `ruby3.4`(Amazon Linux 2023)と非推奨の日付 |
| [Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html) | 同期の呼び出しの要求と応答は 6 MB。コンテナイメージは 10 GB、zip は展開後 250 MB。`/tmp` は 512〜10,240 MB |
| [Execution environment lifecycle](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html) | 初期化は 10 秒まで。超えると最初の呼び出しでやり直す |
| [SnapStart](https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html) | Java、Python、.NET だけ。Ruby は対象外 |
| [Response streaming](https://docs.aws.amazon.com/lambda/latest/dg/configuration-response-streaming.html) | ストリーミングの応答は 200 MB まで。この設計は、圧縮を使うためにストリーミングにしない(`AWS_LWA_INVOKE_MODE` を buffered。[lambda.md](lambda.md#lambda-web-adapter-settings)) |
| [Building Lambda functions with Ruby](https://docs.aws.amazon.com/lambda/latest/dg/lambda-ruby.html) | Rails には YJIT を勧める(`RUBY_YJIT_ENABLE=1`) |
| [Configuring S3 Files access](https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem-s3files.html) | 検討して使わなかった S3 Files の条件(マウントターゲットと同じ VPC、NFS) |
| [File systems](https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem.html) | Event Functions は EFS か S3 Files のどちらかをマウントできる |
| [Lambda Managed Instances](https://docs.aws.amazon.com/lambda/latest/dg/lambda-managed-instances-runtimes.html) | 対応する言語に Ruby がない。最小の環境の数 |
| [Web Functions の runtimes](https://docs.aws.amazon.com/lambda/latest/dg/web-functions-runtimes.html) | `nodejs24.x` だけ |
| [Web Functions の revisions](https://docs.aws.amazon.com/lambda/latest/dg/web-functions-revisions.html) | ファイルシステムの設定項目がない |
| [AWS Lambda Web Adapter](https://github.com/aws/aws-lambda-web-adapter) | 1.1.0(2026-09-18)、準備の確認(`tcp`)、`AWS_LWA_ASYNC_INIT`、HTTP ではないイベントの扱い |
| [Lambda Web Adapter 1.1.0 のソース](https://github.com/aws/aws-lambda-web-adapter/tree/v1.1.0/src) | 読む環境変数の一覧(止める設定はない)。拡張機能として `{"events": []}` で登録し、Runtime API とのやり取りも自分で行う(`src/main.rs`、`src/lib.rs` の `register_extension_internal`) |
| [Using the Lambda Extensions API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-extensions-api.html) | `Lambda-Extension-Name` はファイルの名前と同じ。`events` は必須でない。拡張機能が失敗すると環境を作り直す |
| [Create a Lambda Event Function using a container image](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html) | 読み取り専用のファイルシステム、既定のユーザーがすべてのファイルを読める必要、1 つのアーキテクチャのイメージだけ、数週間呼ばれないと `Inactive`、ECR のイメージが消えると `Failed` |
| [Control access to Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html) | 2025 年 10 月から、関数 URL には `lambda:InvokeFunctionUrl` と `lambda:InvokeFunction` の両方が要る。この設計では、OAC のために CloudFront に、ディストリビューションの `AWS:SourceArn` で両方を許す([iam.md](iam.md#resource-based-policies)) |
| [Lambda の Ruby のベースイメージ](https://gallery.ecr.aws/lambda/ruby) | `/lambda-entrypoint.sh` と `curl` がある。`ruby:4.0` は Ruby 4.0.9、Amazon Linux 2023。手元の Docker で動かして確認した(arm64)。ImageMagick 6.9.12、ghostscript 9.56.1、libpq 15.0、ipa-gothic-fonts、gcc、make が標準のリポジトリにある(`microdnf repoquery`)。Pandoc はない |
| [Lambda S3 Files の発表](https://aws.amazon.com/about-aws/whats-new/2026/04/aws-lambda-amazon-s3/) | 2026 年 4 月。Lambda としての追加の料金はない |

<a id="s3-cloudfront-and-databases"></a>

## S3、CloudFront、データベース

| ページ | 確認したこと |
| --- | --- |
| [S3 Files の同期](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-synchronization.html) | 検討して使わなかった理由の一つ。書き込みが 60 秒止まってから S3 に書き出す |
| [S3 の料金](https://aws.amazon.com/s3/pricing/) | S3 Files の料金の考え方。東京の単価は価格表(AmazonS3)で、載っているデータ 1 GB あたり月 0.36 ドル |
| [GetObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html) | (署名付きの)GET で上書きできるのは `response-content-type`、`-language`、`-expires`、`-cache-control`、`-disposition`、`-encoding` だけなので、CSP は付けられない。添付ファイルを CloudFront に通す理由 |
| [Implementing secure file uploads to Amazon S3 at the edge: Choosing the right pattern](https://aws.amazon.com/blogs/networking-and-content-delivery/implementing-secure-file-uploads-to-amazon-s3-at-the-edge-choosing-the-right-pattern/) | AWS のブログ、2026-02-24。オリジンアクセスコントロールは POST のポリシーに署名しないので、CloudFront を通したアップロードは PUT にする |
| [Checking object integrity for data uploads](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity-upload.html) | アップロードの `x-amz-checksum-sha256` と、`ChecksumMode` を付けた `HeadObject` がチェックサムを返すこと([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html#upload)) |
| [関数 URL のオリジンを OAC で守る](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-lambda.html) | PUT と POST に `x-amz-content-sha256` が要る。Lambda は署名のない本文を受けない。関数 URL は `AWS_IAM`。CloudFront に `lambda:InvokeFunctionUrl` と `lambda:InvokeFunction` を、ディストリビューションの `AWS:SourceArn` で許す(2026-11-09 に確認) |
| [CloudFront Functions のイベントの形](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/functions-event-structure.html) | 要求のデータは、メソッド、URI、クエリー、ヘッダー、Cookie だけで、本文がない(2026-11-09 に確認)。[lambda.md](lambda.md#cloudfront-and-function-urls) |
| [Lambda@Edge の制限](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-at-edge-function-restrictions.html) | 本文は base64 で渡る。オリジンへの要求では 1 MB、ビューアーからの要求では 40 KB で切り詰める。us-east-1、Node.js と Python、コンテナイメージと arm64 は使えない。実行ロールは `edgelambda.amazonaws.com` にも引き受けを許す(2026-11-09 に確認) |
| [CloudFront の定額プランの新しい機能(AWS のブログ)](https://aws.amazon.com/blogs/networking-and-content-delivery/amazon-cloudfront-flat-rate-pricing-plans-new-features-and-expanded-capabilities/) | 2026-03-24。Lambda@Edge が、すべての定額プランで使えるようになった。呼び出しは、プランとは別に従量で払う |
| [CloudFront + Lambda 関数 URL 構成で POST/PUT リクエストを行うため Lambda@Edge でコンテンツハッシュを計算する(クラスメソッド)](https://dev.classmethod.jp/articles/cloudfront-lambda-url-with-post-put-request) | 公式でない実践の記録(2024-07-29)。Lambda@Edge で `x-amz-content-sha256` を入れ、OAC の署名で関数 URL が POST を受けた。本文を文字列にしてから計算しているので、この設計ではバイト列のまま計算する |
| 価格表(AWSLambda、東京、2026-10-30 公開) | Lambda@Edge は 100 万件あたり 0.60 ドル、1 GB 秒あたり 0.00005001 ドル |
| [Route 53 の価格表](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRoute53/current/index.json) | ホストゾーン 1 つで月 0.50 ドル(25 個まで)、別名のレコードへの AWS の中の問い合わせは無料、ほかの問い合わせは 100 万件あたり 0.40 ドル(2026-11-04 公開) |
| [Cloudflare の CNAME の平坦化の設定](https://developers.cloudflare.com/dns/cname-flattening/set-up-cname-flattening/) | 頂点とプロキシを通すレコードは、どのプランでも平坦化される。有料のプランでは、すべての CNAME か、レコードごとに平坦化できる。同じ名前の MX については書かれていない |
| 価格表(東京。AmazonEC2 2026-11-07、AmazonECS 2026-10-19、AWSELB 2026-11-05、AmazonLightsail 2026-09-15 公開) | EC2 t4g.small 1 時間 0.0216 ドル、gp3 1 GB あたり月 0.096 ドル、Fargate の Arm の vCPU 1 時間 0.04045 ドルとメモリ 1 GB 1 時間 0.00442 ドル、ALB 1 時間 0.0243 ドルと LCU 1 時間 0.008 ドル、Lightsail 2 GB 1 時間 0.01612 ドル(パブリック IPv4 を含む)。[comparison.md](comparison.md) |
| [Redmine の DB を MySQL から PostgreSQL へ移行(Qiita)](https://qiita.com/SKYS/items/2004c60000ddfeaa20b3) | 公式でない実践の記録(@SKYS 氏、2026-08-09)。Redmine 6.1、MySQL 8.0 から PostgreSQL 18。スキーマは Redmine の migration で作り、Embulk でデータだけをコピーする。`schema_migrations` を除く、シーケンスを直す、`wiki_content_versions.data` を base64 でコピーする。pgloader 3.6.9 では上手くいかなかった。[migration.md](migration.md#migrating-from-mysql) |
| [dimitri/pgloader](https://github.com/dimitri/pgloader) | 最後のリリースは v3.6.9(2022-10-24)。リポジトリは更新が続いている(2026-09-14) |
| [CloudFront の料金](https://aws.amazon.com/cloudfront/pricing/) | 定額プランの Free は月 0 ドル、月 100 万リクエストと 100 GB、WAF のルール 5 つまで。ログ、独自のキャッシュのルール、VPC の中のオリジンは含まれない |
| [CloudFront の quotas](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html) | オリジンの応答の待ち時間は 1〜120 秒 |
| [Aurora Serverless v2 の自動の一時停止](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html) | 対応するバージョン、再開に約 15 秒、24 時間を超えると 30 秒以上、接続があると止まらない |
| [RDS の停止](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_StopInstance.html) | 7 日まで止められる。開始に時間がかかることがある |
| [IAM のデータベース認証](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html) | 300〜1,000 MiB の追加のメモリ |
| [SQLite をネットワークの上で使う](https://www.sqlite.org/useovernet.html) | ロックの問題で壊れた例がある |
| [SES の VPC エンドポイント](https://docs.aws.amazon.com/ses/latest/dg/send-email-set-up-vpc-endpoints.html) | API 用(`email`)と SMTP 用のインターフェイスエンドポイント。API は 443 番 |
| [SES のエンドポイントとクォータ](https://docs.aws.amazon.com/general/latest/gr/ses.html) | 東京の受信の宛先 `inbound-smtp.ap-northeast-1.amazonaws.com` |
| [SES の受信の考え方](https://docs.aws.amazon.com/ses/latest/dg/receiving-email-concepts.html) | 確認済みの ID 宛てだけを受ける、S3 に置けるのは 40 MB まで、`X-SES-Spam-Verdict`、`X-SES-Virus-Verdict`、`Authentication-Results` のヘッダー |
| [SES と リージョン](https://docs.aws.amazon.com/ses/latest/dg/regions.html) | 受信に使う Lambda は SES と同じリージョン。有効なルールのセットはリージョンごとに 1 つ |

<a id="prices"></a>

## 料金

価格表の公開日は [cost.md](cost.md#sources-of-the-prices) にあります。

<a id="gems-and-tools"></a>

## gem とツール

| ページ | 確認したこと |
| --- | --- |
| [aws/aws-actionmailer-ses-ruby](https://github.com/aws/aws-actionmailer-ses-ruby) | 送信方法 `:ses_v2`、`ses_v2_settings`、SES v2 の `SendEmail` に全文(raw)と To、Cc、Bcc を渡すこと(`lib/aws/action_mailer/ses_v2/mailer.rb`) |
| [RubyGems の aws-actionmailer-ses](https://rubygems.org/gems/aws-actionmailer-ses) | 1.2.0(2026-05-21)、`actionmailer` 7.1 以上 |
| [Pandoc のリリース](https://github.com/jgm/pandoc/releases) | 3.13(2026-10-26)、`pandoc-3.13-linux-arm64.tar.gz` |
| [Debian の pandoc(trixie)](https://sources.debian.org/src/pandoc/) | 3.1.11.1 |
| [aws/aws-activejob-sqs-ruby](https://github.com/aws/aws-activejob-sqs-ruby) | アダプター `:sqs`、Lambda 用のハンドラー(`Aws::ActiveJob::SQS::LambdaHandler.job_handler`。メッセージごとに実行し、成功したら消す。`lib/aws/active_job/sqs/lambda_handler.rb`)、コンテナイメージで Rails を読み込む形 |
| [RubyGems の aws-activejob-sqs](https://rubygems.org/gems/aws-activejob-sqs) | 1.2.0(2026-08-17)、`activejob` 7.1 以上 |
| [getmoto/moto](https://github.com/getmoto/moto) | Apache-2.0、更新が続いている(2026-11-06)。テストで AWS の代わりに使う |
| [CloudFront の定額プラン](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html) | Free: WAF のルール 5 つ、IP アドレスごとの回数の制限と国での遮断はあり、CAPTCHA、ヘッダーと正規表現で絞るルール、止めたときの応答の変更、Bot Control はない。本文を調べるのは 16 KB まで。AWS 管理のキャッシュ、オリジンリクエスト、レスポンスヘッダーのポリシーは使え、自分で作るものは Business から。CloudFront Functions は含まれ、Lambda@Edge は使えて呼び出しごとに課金、KeyValueStore は Pro から。アクセスログと WAF のログは Pro から。Free のプランは 1 つのアカウントで 3 つまで(上げられない)。キャッシュのビヘイビアは Free で 5 つ。Web ACL は外せない。ルールのグループは使えない。ほかのディストリビューションが使う Web ACL と CloudFront Functions は付けられない。AWS の無料利用枠のアカウントはプランを使えない(2026-11-10 に確認)。[lambda.md](lambda.md#flat-rate-free-plan-and-waf)、[security.md](security.md#aws-waf) |
| [CloudFront の料金](https://aws.amazon.com/cloudfront/pricing/) | Free は 0 ドル(月 100 万件、100 GB)、Pro は月 15 ドル(1,000 万件、50 TB)。WAF が止めた要求は使用量に数えない(2026-11-09 に確認) |
| [AWS WAF の料金](https://aws.amazon.com/waf/pricing/) | 従量: Web ACL 1 つで月 5 ドル、ルールか管理ルールのグループ 1 つで月 1 ドル、100 万件の要求で 0.60 ドル。既定より大きな本文を調べると、16 KB ごとに 100 万件あたり 0.30 ドル(2026-11-09 に確認) |
| [WAF の rate-based のルールの設定](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based-high-level-settings.html) | 数える時間は 60、120、300、600 秒。回数の下限は 10。ちょうどの回数で止めることは約束しない(2026-11-09 に確認) |
| [AWS 管理の応答のヘッダーのポリシー](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html) | `SecurityHeadersPolicy`(`67f7725c-6f97-4210-82d7-5512b31e9d03`)の中身(2026-11-09 に確認) |
| [GitHub Packages の権限](https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages)、[RubyGems のレジストリ](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-rubygems-registry) | 公開のパッケージを認証なしで取れるのは、コンテナのレジストリだけ。RubyGems のレジストリは、公開の gem でも、入れるのにトークンが要る(2026-11-09 に確認)。[architecture.md](architecture.md#distribution) |
| [localstack/localstack](https://github.com/localstack/localstack) | GitHub のリポジトリがアーカイブされている(2026-03)。リポジトリの代わりに、料金のプランのある製品(LocalStack for AWS)を使う |
| [minio/minio](https://github.com/minio/minio) | GitHub のリポジトリがアーカイブされている(2026-04)。テストの道具には選ばない |
| [Embulk](https://www.embulk.org/)、[embulk-input-mysql と embulk-output-postgresql](https://github.com/embulk/embulk-input-jdbc) | MySQL から PostgreSQL にデータだけをコピーする道具([migration.md](migration.md#migrating-from-mysql))。使うバージョンは、作るときに確認する(未確認) |
| [LocalStack の Lambda](https://docs.localstack.cloud/aws/services/lambda/) | Lambda と関数 URL は Hobby から使える。コンテナイメージのプランの決まりは書かれていない(2026-11-09 に確認) |
| [LocalStack の料金](https://www.localstack.cloud/pricing) | Hobby は無料で、非商用の利用に限る(商用の目的での利用を規約で禁じる)。Hobby には Lambda、S3、SQS、SSM、IAM、SES(v1)があり、SES v2、RDS、CloudFront はない。CI の利用は、プランごとの決まりと Fair Use の範囲(2026-11-09 に確認) |

<a id="other-aws-services"></a>

## そのほかの AWS

| ページ | 確認したこと |
| --- | --- |
| [SES v2 の SendEmail](https://docs.aws.amazon.com/ses/latest/APIReference-V2/API_SendEmail.html) | エラーの一覧(`TooManyRequestsException` は 429、ほかは 400 か 404)と意味。メールの送り直しの分け方に使う |
| [EventBridge の料金](https://aws.amazon.com/eventbridge/pricing/) | 検討して使わなかった形のため。カスタムのイベントは 100 万件あたり 1.00 ドル。S3 のイベントの料金は書かれていない |
| [EventBridge の送り直し](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html) | 既定で 24 時間、最大 185 回。届かなかったイベントはデッドレターキューで受ける |

