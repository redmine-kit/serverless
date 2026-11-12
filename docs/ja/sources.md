# 出典

この資料で参照した情報です。

- 確認日は、行に書いたもののほかは、2026-11-08 です。
- 仕様は変わることがあります。構築するときに最新の内容を確認し、確認日を更新してください。

<a id="redmine"></a>

## Redmine

| ページ | 確認したこと |
| --- | --- |
| [Download](https://www.redmine.org/projects/redmine/wiki/Download) | 最新の安定バージョンは 7.0.3 (2026-11-01)。6.1 はバグ修正とセキュリティ修正だけ |
| [RedmineInstall](https://www.redmine.org/projects/redmine/wiki/RedmineInstall) | 7.0 の Ruby (3.2〜4.0)、Rails 8.1、データベース (PostgreSQL 14、MySQL 8.0〜8.4 など)、ImageMagick、Ghostscript、Pandoc、ジョブの `:async` は本番環境で推奨しないこと |
| [Changelog 7.0](https://www.redmine.org/projects/redmine/wiki/Changelog_7_0) | 7.0.0〜7.0.3 の日付 |
| [Roadmap](https://www.redmine.org/projects/redmine/roadmap) | 7.1.0 と 7.0.4 が開発中 |
| [EmailConfiguration](https://www.redmine.org/projects/redmine/wiki/EmailConfiguration) | `email_delivery` の書き方 |
| [redmine/redmine の 7.0-stable](https://github.com/redmine/redmine/tree/7.0-stable) (d718d63)。OAuth 2 のプロバイダー (`Gemfile` の doorkeeper、`config/initializers/doorkeeper.rb`)、メーラーのヘッダー (`X-Redmine-Project`)、メールの取り込み先プロジェクトの決定 (`MailHandler#target_project`) | 添付ファイルの処理 (`app/models/attachment.rb`、`app/controllers/attachments_controller.rb`、`app/assets/javascripts/attachments.js`)、インポートの一時ファイル、アセットの自動書き出し、ジョブ、セッション |
| [Docker Hub の redmine](https://hub.docker.com/_/redmine) | 7.0.3 のタグ、arm64 のビルド (2026-11-06 に更新) |
| [docker-library/redmine の 7.0 の Dockerfile (trixie)](https://github.com/docker-library/redmine/blob/master/7.0/trixie/Dockerfile) | 公式イメージのベースイメージ (`ruby:4.0-slim-trixie`)、含まれるツール、権限、エントリーポイント。Redmine 7.0.3 の tar.gz の SHA256 |

<a id="redmines-s3-plugin-reference"></a>

## Redmine の S3 プラグイン (参考)

| ページ | 確認したこと |
| --- | --- |
| [hgyoon-w/redmine5_amazon_s3](https://github.com/hgyoon-w/redmine5_amazon_s3) | 1.0.0、最後のコミットは 2025-12-17、Redmine 5.0 以上。保存、削除、ダウンロードとサムネイルのリダイレクト、`thumbnail_tag` の差し替え。digest を保存時刻に置き換える |
| [redmine_cloud_attachment_pro](https://www.redmine.org/plugins/redmine_cloud_attachment_pro) | 0.0.1、Redmine 4.0〜6.1。`diskfile` のたびに S3 から一時ファイルに取得する |
| [ka8725/redmine_s3](https://github.com/ka8725/redmine_s3) | 古くからある S3 プラグイン (Redmine 3 系のころ) |

<a id="rails"></a>

## Rails

| ページ | 確認したこと |
| --- | --- |
| [railties の configuration.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/configuration.rb) | キャッシュのデフォルト (ファイル)、`SECRET_KEY_BASE` の読み込み |
| [activejob の railtie (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activejob/lib/active_job/railtie.rb) | ジョブアダプターのデフォルトは `:async` |
| [mail_delivery_job.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionmailer/lib/action_mailer/mail_delivery_job.rb) | メール送信ジョブは、例外をメーラーの `handle_exception` に渡す (処理がなければ例外のまま) |
| [Propshaft の railtie (v1.3.1)](https://github.com/rails/propshaft/blob/v1.3.1/lib/propshaft/railtie.rb) | アセットの出力先 `public/assets` |
| [active_record.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record.rb) | `dump_schema_after_migration` のデフォルトは `true` |
| [databases.rake (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/railties/databases.rake) | `db:migrate` のあとにスキーマを書き出す |
| [bootstrap.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/bootstrap.rb) | キャッシュは `initialize_cache` で、アプリの initializer より前に作る |
| [host_authorization.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_dispatch/middleware/host_authorization.rb) | `Host` が許可されていないとき、または `X-Forwarded-Host` があってその最後の値が許可されていないときに、リクエストを 403 でブロックする (`blocked_hosts`)。`exclude` が受け取るのはリクエストだけ (2026-11-10 に確認)。[lambda.md](lambda.md#host-and-scheme) |
| [request_forgery_protection.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_controller/metal/request_forgery_protection.rb) | `forgery_protection_origin_check` は、設定しなければ `false`。`load_defaults` の 5.0 以降が `true` にする (`configuration.rb`)。Redmine 7.0.3 は `load_defaults` を呼ばない (`config/application.rb`。2026-11-10 に確認)。[lambda.md](lambda.md#host-and-scheme) |
| [default_middleware_stack.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/default_middleware_stack.rb) | `HostAuthorization` はミドルウェアの先頭で、`config.hosts` が空でないときだけ入る (2026-11-10 に確認) |
| [actionpack の url.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_dispatch/http/url.rb) | ホストは `X-Forwarded-Host` の最後の値、なければ `Host` から取る (`raw_host_with_port`)。ポートはその値から取り、なければスキームの標準のポート。プロトコルは `ssl?` から決まる (2026-11-10 に確認) |
| [Rack の request.rb (v3.2.8)](https://github.com/rack/rack/blob/v3.2.8/lib/rack/request.rb) | スキームは `HTTPS`、`Forwarded` ヘッダー、`X-Forwarded-Proto` の順に取る (`forwarded_priority` のデフォルトは `[:forwarded, :x_forwarded]`。2026-11-10 に確認) |

<a id="aws-lambda"></a>

## AWS Lambda

| ページ | 確認したこと |
| --- | --- |
| [Lambda runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html) | `ruby4.0` と `ruby3.4` (Amazon Linux 2023) と非推奨の日付 |
| [Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html) | 同期呼び出しのリクエストとレスポンスは 6 MB。コンテナイメージは 10 GB、zip は展開後 250 MB。`/tmp` は 512〜10,240 MB |
| [Execution environment lifecycle](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html) | 初期化は 10 秒まで。超えると最初の呼び出しで再試行する |
| [SnapStart](https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html) | Java、Python、.NET だけ。Ruby は対象外 |
| [Response streaming](https://docs.aws.amazon.com/lambda/latest/dg/configuration-response-streaming.html) | ストリーミングレスポンスは 200 MB まで。この設計は、圧縮を使うためにストリーミングにしない (`AWS_LWA_INVOKE_MODE` を buffered。[lambda.md](lambda.md#lambda-web-adapter-settings)) |
| [Building Lambda functions with Ruby](https://docs.aws.amazon.com/lambda/latest/dg/lambda-ruby.html) | Rails には YJIT を勧める (`RUBY_YJIT_ENABLE=1`) |
| [Configuring S3 Files access](https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem-s3files.html) | 検討して採用しなかった S3 Files の条件 (マウントターゲットと同じ VPC、NFS) |
| [File systems](https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem.html) | Event Functions は EFS か S3 Files のどちらかをマウントできる |
| [Lambda Managed Instances](https://docs.aws.amazon.com/lambda/latest/dg/lambda-managed-instances-runtimes.html) | 対応する言語に Ruby がない。実行環境の最小数 |
| [Web Functions の runtimes](https://docs.aws.amazon.com/lambda/latest/dg/web-functions-runtimes.html) | `nodejs24.x` だけ |
| [Web Functions の revisions](https://docs.aws.amazon.com/lambda/latest/dg/web-functions-revisions.html) | ファイルシステムの設定項目がない |
| [AWS Lambda Web Adapter](https://github.com/aws/aws-lambda-web-adapter) | 1.1.0 (2026-09-18)、準備完了チェック (`tcp`)、`AWS_LWA_ASYNC_INIT`、HTTP ではないイベントの扱い |
| [Lambda Web Adapter 1.1.0 のソース](https://github.com/aws/aws-lambda-web-adapter/tree/v1.1.0/src) | 読み込む環境変数の一覧 (無効にする設定はない)。拡張機能として `{"events": []}` で登録し、Runtime API とのやり取りも自分で行う (`src/main.rs`、`src/lib.rs` の `register_extension_internal`) |
| [Lambda Web Adapter 1.1.0 の `src/lib.rs`](https://github.com/aws/aws-lambda-web-adapter/blob/v1.1.0/src/lib.rs) | リクエストヘッダーは、`Host` も含めてそのまま Web アプリケーションに渡し、`x-amzn-request-context` と `x-amzn-lambda-context` を追加する (2026-11-10 に確認)。[lambda.md](lambda.md#host-and-scheme) |
| [Lambda 関数 URL の呼び出し](https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html) | イベントには、リクエストヘッダーと、関数 URL のドメインの `requestContext.domainName` が入る。関数 URL が `X-Forwarded-Host` と `X-Forwarded-Proto` をどう扱うかは書かれていない (2026-11-10 に確認) |
| [Using the Lambda Extensions API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-extensions-api.html) | `Lambda-Extension-Name` はファイル名と同じ。`events` は必須でない。拡張機能が失敗すると実行環境を作り直す |
| [Create a Lambda Event Function using a container image](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html) | 読み取り専用のファイルシステム、デフォルトのユーザーがすべてのファイルを読める必要があること、単一アーキテクチャのイメージだけ、数週間呼び出されないと `Inactive`、ECR イメージが削除されると `Failed` |
| [Control access to Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html) | 2025 年 10 月から、関数 URL には `lambda:InvokeFunctionUrl` と `lambda:InvokeFunction` の両方が必要。この設計では、OAC のために CloudFront に、ディストリビューションの `AWS:SourceArn` を条件に両方を許可する ([iam.md](iam.md#resource-based-policies)) |
| [Lambda の Ruby ベースイメージ](https://gallery.ecr.aws/lambda/ruby) | `/lambda-entrypoint.sh` と `curl` がある。`ruby:4.0` は Ruby 4.0.9、Amazon Linux 2023。ローカルの Docker で実行して確認した (arm64)。ImageMagick 6.9.12、ghostscript 9.56.1、libpq 15.0、ipa-gothic-fonts、gcc、make が標準リポジトリにある (`microdnf repoquery`)。Pandoc はない |
| [Lambda S3 Files の発表](https://aws.amazon.com/about-aws/whats-new/2026/04/aws-lambda-amazon-s3/) | 2026 年 4 月。Lambda としての追加料金はない |

<a id="s3-cloudfront-and-databases"></a>

## S3、CloudFront、データベース

| ページ | 確認したこと |
| --- | --- |
| [S3 Files の同期](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-synchronization.html) | 採用しなかった理由の一つ。書き込みが 60 秒止まってから S3 に書き出す |
| [S3 の料金](https://aws.amazon.com/s3/pricing/) | S3 Files の料金体系。ap-northeast-1 の単価は料金表 (AmazonS3) で、保存しているデータ 1 GB あたり月 0.36 ドル |
| [GetObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html) | (署名付き URL の) GET で上書きできるのは `response-content-type`、`-language`、`-expires`、`-cache-control`、`-disposition`、`-encoding` だけなので、CSP は付けられない。添付ファイルを CloudFront 経由で配信する理由 |
| [Implementing secure file uploads to Amazon S3 at the edge: Choosing the right pattern](https://aws.amazon.com/blogs/networking-and-content-delivery/implementing-secure-file-uploads-to-amazon-s3-at-the-edge-choosing-the-right-pattern/) | AWS ブログ、2026-02-24。オリジンアクセスコントロールは POST ポリシーに署名しないので、CloudFront を通したアップロードは PUT にする |
| [Checking object integrity for data uploads](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity-upload.html) | チェックサムのアルゴリズムを指定したコピーには、元がマルチパートアップロードでも、オブジェクト全体のチェックサムが付くこと。`PutObject` はオブジェクト全体のチェックサムタイプを使うこと。`ChecksumMode` を付けた `HeadObject` がチェックサムを返すこと (2026-11-10 に確認) ([attachments.md](https://redmine-kit.github.io/redmine_aws_s3/ja/attachments.html#upload)) |
| [関数 URL のオリジンへのアクセスを OAC で制限する](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-lambda.html) | PUT と POST に `x-amz-content-sha256` が必要。Lambda は署名のない本文を受け付けない。関数 URL は `AWS_IAM`。CloudFront に `lambda:InvokeFunctionUrl` と `lambda:InvokeFunction` を、ディストリビューションの `AWS:SourceArn` を条件に許可する (2026-11-09 に確認) |
| [オリジンリクエストへのカスタムヘッダーの追加](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/add-origin-custom-headers.html) | ビューワーのリクエストに同じ名前のヘッダーがあれば、CloudFront はオリジンに転送する前にその値を上書きする。CloudFront が追加できないヘッダーは `Host`、`Cookie`、`Via`、`X-Real-Ip`、`X-Amz-` や `X-Edge-` で始まるヘッダーなどで、`X-Forwarded-Host` と `X-Forwarded-Proto` は含まれない (2026-11-10 に確認)。[lambda.md](lambda.md#host-and-scheme) |
| [カスタムオリジンのリクエストとレスポンスの動作](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/RequestAndResponseBehaviorCustomOrigin.html) | `Host` を転送しなければ、CloudFront は `Host` をオリジンのドメイン名にする。ビューワーの `X-Forwarded-Proto` は削除し、`X-Forwarded-For` はビューワーのアドレスを末尾に追加して転送する (2026-11-10 に確認) |
| [CloudFront Functions のイベント構造](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/functions-event-structure.html) | リクエストのデータは、メソッド、URI、クエリ文字列、ヘッダー、Cookie だけで、本文がない (2026-11-09 に確認)。[lambda.md](lambda.md#cloudfront-and-function-urls) |
| [Lambda@Edge の制限](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-at-edge-function-restrictions.html) | 本文は base64 で渡される。オリジンリクエストでは 1 MB、ビューアーリクエストでは 40 KB で切り詰める。us-east-1、Node.js と Python、コンテナイメージと arm64 は使えない。実行ロールは `edgelambda.amazonaws.com` にも引き受けを許可する (2026-11-09 に確認) |
| [CloudFront の定額料金プランの新機能 (AWS ブログ)](https://aws.amazon.com/blogs/networking-and-content-delivery/amazon-cloudfront-flat-rate-pricing-plans-new-features-and-expanded-capabilities/) | 2026-03-24。Lambda@Edge が、すべての定額料金プランで使えるようになった。呼び出しは、プランとは別に従量課金 |
| [CloudFront + Lambda 関数 URL 構成で POST/PUT リクエストを行うため Lambda@Edge でコンテンツハッシュを計算する (クラスメソッド)](https://dev.classmethod.jp/articles/cloudfront-lambda-url-with-post-put-request) | 非公式の実践記録 (2024-07-29)。Lambda@Edge で `x-amz-content-sha256` を設定し、OAC 署名で関数 URL が POST を受け付けた。本文を文字列に変換してから計算しているので、この設計ではバイト列のまま計算する |
| 料金表 (AWSLambda、ap-northeast-1、2026-10-30 公開) | Lambda@Edge は 100 万リクエストあたり 0.60 ドル、1 GB 秒あたり 0.00005001 ドル |
| [Route 53 の料金表](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRoute53/current/index.json) | ホストゾーン 1 つで月 0.50 ドル (25 個まで)、エイリアスレコードへの AWS 内からのクエリは無料、ほかのクエリは 100 万クエリあたり 0.40 ドル (2026-11-04 公開) |
| [Cloudflare の CNAME フラット化の設定](https://developers.cloudflare.com/dns/cname-flattening/set-up-cname-flattening/) | ゾーンの頂点とプロキシを通すレコードは、どのプランでもフラット化される。有料プランでは、すべての CNAME か、レコードごとにフラット化できる。同じ名前の MX については記載がない |
| 料金表 (ap-northeast-1。AmazonEC2 2026-11-07、AmazonECS 2026-10-19、AWSELB 2026-11-05、AmazonLightsail 2026-09-15 公開) | EC2 t4g.small 1 時間 0.0216 ドル、gp3 1 GB あたり月 0.096 ドル、Fargate (Arm) の vCPU 1 時間 0.04045 ドルとメモリ 1 GB 1 時間 0.00442 ドル、ALB 1 時間 0.0243 ドルと LCU 1 時間 0.008 ドル、Lightsail 2 GB 1 時間 0.01612 ドル (パブリック IPv4 を含む)。[comparison.md](comparison.md) |
| [Redmine の DB を MySQL から PostgreSQL へ移行 (Qiita)](https://qiita.com/SKYS/items/2004c60000ddfeaa20b3) | 非公式の実践記録 (@SKYS 氏、2026-08-09)。Redmine 6.1、MySQL 8.0 から PostgreSQL 18。スキーマは Redmine の migration で作り、Embulk でデータだけをコピーする。`schema_migrations` を除く、シーケンスを修正する、`wiki_content_versions.data` を base64 でコピーする。pgloader 3.6.9 では成功しなかった。[migration.md](migration.md#migrating-from-mysql) |
| [dimitri/pgloader](https://github.com/dimitri/pgloader) | 最後のリリースは v3.6.9 (2022-10-24)。リポジトリは更新が続いている (2026-09-14) |
| [CloudFront の料金](https://aws.amazon.com/cloudfront/pricing/) | 定額料金プランの無料プランは月 0 ドル、月 100 万リクエストと 100 GB、WAF ルール 5 つまで。ログ、カスタムのキャッシュルール、VPC 内のオリジンは含まれない |
| [CloudFront のクォータ](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html) | オリジンの応答タイムアウトは 1〜120 秒 |
| [Aurora Serverless v2 の自動一時停止](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html) | 対応バージョン、再開に約 15 秒、24 時間を超えると 30 秒以上、接続があると一時停止しない |
| [RDS の停止](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_StopInstance.html) | 7 日まで停止できる。起動に時間がかかることがある |
| [IAM データベース認証](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html) | 300〜1,000 MiB の追加メモリ |
| [SQLite をネットワーク越しに使う](https://www.sqlite.org/useovernet.html) | ロックの問題で壊れた例がある |
| [SES の VPC エンドポイント](https://docs.aws.amazon.com/ses/latest/dg/send-email-set-up-vpc-endpoints.html) | API 用 (`email`) と SMTP 用のインターフェイスエンドポイント。API は 443 番ポート |
| [SES のエンドポイントとクォータ](https://docs.aws.amazon.com/general/latest/gr/ses.html) | ap-northeast-1 の受信エンドポイント `inbound-smtp.ap-northeast-1.amazonaws.com` |
| [SES のメール受信の概念](https://docs.aws.amazon.com/ses/latest/dg/receiving-email-concepts.html) | 検証済み ID 宛てだけを受信する、S3 に保存できるのは 40 MB まで、`X-SES-Spam-Verdict`、`X-SES-Virus-Verdict`、`Authentication-Results` ヘッダー |
| [SES とリージョン](https://docs.aws.amazon.com/ses/latest/dg/regions.html) | 受信に使う Lambda は SES と同じリージョン。アクティブな受信ルールセットはリージョンごとに 1 つ |

<a id="prices"></a>

## 料金

料金表の公開日は [cost.md](cost.md#sources-of-the-prices) にあります。

<a id="gems-and-tools"></a>

## gem とツール

| ページ | 確認したこと |
| --- | --- |
| [aws/aws-actionmailer-ses-ruby](https://github.com/aws/aws-actionmailer-ses-ruby) | 送信方法 `:ses_v2`、`ses_v2_settings`、SES v2 の `SendEmail` に全文 (raw) と To、Cc、Bcc を渡すこと (`lib/aws/action_mailer/ses_v2/mailer.rb`) |
| [RubyGems の aws-actionmailer-ses](https://rubygems.org/gems/aws-actionmailer-ses) | 1.2.0 (2026-05-21)、`actionmailer` 7.1 以上 |
| [Pandoc のリリース](https://github.com/jgm/pandoc/releases) | 3.13 (2026-10-26)、`pandoc-3.13-linux-arm64.tar.gz` |
| [Debian の pandoc (trixie)](https://sources.debian.org/src/pandoc/) | 3.1.11.1 |
| [aws/aws-activejob-sqs-ruby](https://github.com/aws/aws-activejob-sqs-ruby) | アダプター `:sqs`、Lambda 用のハンドラー (`Aws::ActiveJob::SQS::LambdaHandler.job_handler`。メッセージごとに実行し、成功したら削除する。`lib/aws/active_job/sqs/lambda_handler.rb`)、コンテナイメージで Rails を読み込む方法 |
| [RubyGems の aws-activejob-sqs](https://rubygems.org/gems/aws-activejob-sqs) | 1.2.0 (2026-08-17)、`activejob` 7.1 以上 |
| [aws/aws-emulator](https://github.com/aws/aws-emulator) | CC0-1.0 (`vendor/` は Apache-2.0)。AWS はコンテナイメージを公開していないので、downloads.aws.com の RPM を、バージョンと SHA-256 を固定してインストールする (`test/aws-emulator/Dockerfile`)。テレメトリーはデフォルトでオンで、`--telemetry off` か `EMULATOR_TELEMETRY=off` でオフにする。作成する証明書には `127.0.0.1` と `localhost` しか含まれない。SQS は JSON プロトコルだけに対応する (1.0.322 で確認、2026-11-12)。イメージテストで SSM と SQS の代わりに使う ([testing.md](testing.md#image-tests)) |
| [getmoto/moto](https://github.com/getmoto/moto) | Apache-2.0、更新が続いている (2026-11-06)。テストで AWS の代わりに使う |
| [CloudFront 定額料金プラン](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html) | 無料プラン: WAF ルール 5 つ、IP アドレスごとのレート制限と国別のブロックはあり、CAPTCHA、ヘッダーと正規表現で絞るルール、ブロック時のレスポンスの変更、Bot Control はない。本文の検査は 16 KB まで。AWS マネージドのキャッシュポリシー、オリジンリクエストポリシー、レスポンスヘッダーポリシーは使え、カスタムポリシーはビジネスプランから。CloudFront Functions は含まれ、Lambda@Edge は使えて呼び出しごとに課金、KeyValueStore はプロプランから。アクセスログと WAF ログはプロプランから。無料プランは 1 つのアカウントで 3 つまで (引き上げ不可)。キャッシュビヘイビアは無料プランで 5 つ。Web ACL は関連付けを解除できない。ルールグループは使えない。ほかのディストリビューションが使う Web ACL と CloudFront Functions は関連付けられない。AWS 無料利用枠のアカウントはプランを使えない (2026-11-10 に確認)。[lambda.md](lambda.md#flat-rate-free-plan-and-waf)、[security.md](security.md#aws-waf) |
| [CloudFront の料金](https://aws.amazon.com/cloudfront/pricing/) | 無料プランは 0 ドル (月 100 万リクエスト、100 GB)、プロプランは月 15 ドル (1,000 万リクエスト、50 TB)。WAF がブロックしたリクエストは使用量に含めない (2026-11-09 に確認) |
| [AWS WAF の料金](https://aws.amazon.com/waf/pricing/) | 従量課金: Web ACL 1 つで月 5 ドル、ルールかマネージドルールグループ 1 つで月 1 ドル、100 万リクエストで 0.60 ドル。デフォルトより大きな本文を検査すると、16 KB ごとに 100 万リクエストあたり 0.30 ドル (2026-11-09 に確認) |
| [WAF のレートベースのルールの設定](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based-high-level-settings.html) | 評価期間は 60、120、300、600 秒。レート制限の下限は 10。設定した回数ちょうどでブロックすることは保証しない (2026-11-09 に確認) |
| [マネージドレスポンスヘッダーポリシー](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html) | `SecurityHeadersPolicy` (`67f7725c-6f97-4210-82d7-5512b31e9d03`) の中身 (2026-11-09 に確認) |
| [GitHub Packages の権限](https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages)、[RubyGems レジストリ](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-rubygems-registry) | パブリックパッケージを認証なしで取得できるのは、コンテナレジストリだけ。RubyGems レジストリは、パブリックの gem でも、インストールにトークンが必要 (2026-11-09 に確認)。[architecture.md](architecture.md#distribution) |
| [Bundler 4.0.24 の bundle-config(1) の `cooldown`](https://github.com/rubygems/rubygems/blob/v4.0.24/bundler/lib/bundler/man/bundle-config.1.ronn) | cooldown は、gem のサーバーが compact index で各バージョンの `created_at` を返すことが前提。返さないバージョンは cooldown の期間外として扱われ、解決の対象になる。GitHub Packages の RubyGems レジストリ (`/info/<gem>`) は、依存関係とチェックサムだけを返し、`created_at` は返さない (2026-11-12 に確認)。[testing.md](testing.md#updates) |
| [localstack/localstack](https://github.com/localstack/localstack) | GitHub リポジトリがアーカイブされている (2026-03)。リポジトリの代わりに、料金プランのある製品 (LocalStack for AWS) を使う |
| [minio/minio](https://github.com/minio/minio) | GitHub リポジトリがアーカイブされている (2026-04)。テストツールには採用しない |
| [Embulk](https://www.embulk.org/)、[embulk-input-mysql と embulk-output-postgresql](https://github.com/embulk/embulk-input-jdbc) | MySQL から PostgreSQL にデータだけをコピーするツール ([migration.md](migration.md#migrating-from-mysql))。使うバージョンは、構築するときに確認する (未確認) |
| [LocalStack の Lambda](https://docs.localstack.cloud/aws/services/lambda/) | Lambda と関数 URL は Hobby プランから使える。コンテナイメージのプランの条件は記載がない (2026-11-09 に確認) |
| [LocalStack の料金](https://www.localstack.cloud/pricing) | Hobby プランは無料で、非商用の利用に限る (商用目的の利用を規約で禁止)。Hobby プランには Lambda、S3、SQS、SSM、IAM、SES (v1) があり、SES v2、RDS、CloudFront はない。CI での利用は、プランごとの条件と Fair Use の範囲 (2026-11-09 に確認) |

<a id="other-aws-services"></a>

## そのほかの AWS サービス

| ページ | 確認したこと |
| --- | --- |
| [SES v2 の SendEmail](https://docs.aws.amazon.com/ses/latest/APIReference-V2/API_SendEmail.html) | エラーの一覧 (`TooManyRequestsException` は 429、ほかは 400 か 404) と意味。メールを再送するかどうかの判定に使う |
| [EventBridge の料金](https://aws.amazon.com/eventbridge/pricing/) | 検討して採用しなかった構成のため。カスタムイベントは 100 万件あたり 1.00 ドル。S3 イベントの料金は記載がない |
| [EventBridge の再試行](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html) | デフォルトで 24 時間、最大 185 回。配信できなかったイベントはデッドレターキューで受け取る |

