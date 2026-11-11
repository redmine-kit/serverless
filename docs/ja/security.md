# セキュリティ

Serverless のセキュリティ設計です。保護対象、脅威、層ごとの対策、残存リスク、インシデント対応の手順をまとめます。権限、ネットワーク、データベースの詳細な設定は、それぞれの資料にあり、この資料からリンクします。AWS 側のセキュリティ設定 (GuardDuty とアップロードのマルウェアスキャン、CloudTrail、IAM Access Analyzer など) は [aws-security.md](aws-security.md) にあります。

この資料の仕様は、2026-11-09 時点の公式情報と、Redmine 7.0.3 のソースで確認したものです。出典は [sources.md](sources.md) にあります。

<a id="approach"></a>

## 方針

- **外部からの経路を少なくする:** 外部からアクセスできるのは CloudFront だけにします。関数 URL は OAC の署名がないと呼び出せず、データベースは、パブリックアクセスのない VPC のプライベートサブネットに置きます。
- **権限を小さく分ける:** 関数ごと、インスタンスごとに権限を分け、1 つが侵害されても影響が広がらないようにします。
- **シークレットを減らす:** AWS のアクセスキーは作成しません。残るシークレット (データベースパスワードと `SECRET_KEY_BASE`) は、SSM Parameter Store の SecureString に保存します。
- **Redmine の標準の対策を使う:** 二要素認証、パスワードのポリシー、権限とロールは、Redmine の標準機能を使い、プラグインで作り直しません。
- **安全なデフォルト値:** 設定ファイルと Redmine の設定の初期値は、安全な側にします (下の「Redmine の設定」)。緩めるときは、アダプタが理由を決めて変更します。

<a id="what-to-protect"></a>

## 保護対象

| 保護対象 | 保存先 | 漏えい・破損時の影響 |
| --- | --- | --- |
| Redmine のデータ (チケット、wiki、ユーザー、パスワードのハッシュ、API キー) | RDS for PostgreSQL | 業務情報と、ユーザーのアカウントが漏えいする |
| 添付ファイル | S3 の添付ファイル用バケット | 業務文書が漏えいする |
| 受信したメール | S3 のメール用バケット (`inbound/`、`processed/`) | メールの全文が漏えいする |
| シークレット (`SECRET_KEY_BASE`、データベースパスワード) | SSM Parameter Store | セッション Cookie を偽造される。VPC 内からデータベースを読み書きされる |
| AWS の権限 | 実行ロール、デプロイ用ロール、管理者の SSO | AWS リソースを読み書きされる。費用を発生させられる |
| 管理者アカウント | Redmine と SSO | すべてのデータと設定を変更される |

<a id="threats-and-protections"></a>

## 脅威と対策

| 脅威 | 主な対策 | 資料 |
| --- | --- | --- |
| Redmine の脆弱性を悪用される | Redmine を早めにバージョンアップする、WAF、読み取り専用のファイルシステム | [upgrade.md](upgrade.md)、下の「AWS WAF」 |
| パスワードの総当たり攻撃、使い回しのパスワード | 二要素認証 (管理者は必須)、パスワードのポリシー、WAF によるログインのレート制限 | 下の「Redmine の設定」「AWS WAF」 |
| 関数 URL を直接呼び出される | 関数 URL は IAM 認証で、OAC の署名がないと関数が呼び出されない | [lambda.md](lambda.md#cloudfront-and-function-urls) |
| 外部からデータベースに接続される | RDS はパブリックアクセスのないプライベートサブネットに置く。セキュリティグループは関数からの接続だけを許可する。パスワードは SSM と RDS にだけ保存する | [rds.md](rds.md#security) |
| 権限のないユーザーに添付ファイルを読まれる | Redmine が権限を確認してから、有効期限 5 分の CloudFront 署名付き URL を発行する。バケットは公開せず、OAC を通した CloudFront からのアクセスだけを許可する | [attachments.md](https://redmine-kit.github.io/redmine_aws_s3/ja/attachments.html#download) |
| 署名付き URL が漏えいする | 有効期限は 5 分。ログに記録しない (下の「ログ」) | 下の「ログ」 |
| 添付ファイルで悪意のあるコードを実行される (HTML、SVG) | 添付ファイルは、Redmine の標準と同じく Redmine のオリジンから、CloudFront のビヘイビア `/files/*` と `/tmp/*` (サムネイルと zip) を通して返され、Redmine が付けるのと同じ `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; sandbox` と `X-Content-Type-Options: nosniff` が付く。sandbox の文書は不透明なオリジンになり、スクリプトも実行されないので、Redmine の Cookie を読むことも、Redmine を呼び出すこともできない。PDF 以外は、ダウンロードとして返す (`Content-Disposition: attachment`。Redmine の標準と同じ)。デプロイ後の確認で、ヘッダーを確認する ([testing.md](testing.md#checks-after-deployment)) | [attachments.md](https://redmine-kit.github.io/redmine_aws_s3/ja/attachments.html#download) |
| 送信者を偽装したメールで、チケットを作成される | DMARC に合格しないメール、迷惑メール、ウイルスを含むメールを破棄する。登録されていないアドレスからのメールを受け付けない | [mail.md](mail.md#spoofing-and-spam) |
| webhook で、内部のアドレスにリクエストを送信させられる (SSRF) | `webhook_blocklist` で、プライベート、ループバック、リンクローカルのアドレスを拒否する | [lambda.md](lambda.md#rails-and-redmine-settings) |
| 依存する gem やイメージに悪意のあるコードが混入する | digest と SHA256 で固定する、依存関係の脆弱性スキャン、GitHub Actions を SHA で固定する | 下の「サプライチェーン」 |
| AWS の権限を昇格される | 関数ごとのロール、アクセス許可の境界、インフラの変更には承認が必要 | [iam.md](iam.md) |
| 費用を発生させられる (大量のリクエスト) | 予約された同時実行、WAF のレート制限、CloudFront の定額料金プラン (WAF がブロックしたリクエストは使用量に含まれない) | 下の「AWS WAF」 |
| インスタンス間でデータが混在する | 名前とロールをインスタンスごとに分け、対象を ARN で限定する | [deploy-config.md](deploy-config.md) |

<a id="entry-point-cloudfront"></a>

## エントリーポイント (CloudFront)

| 項目 | 決定事項 |
| --- | --- |
| HTTPS | ビューワーには HTTPS だけを許可し、HTTP は HTTPS にリダイレクトする。TLS の最小バージョンは、CloudFront のセキュリティポリシー `TLSv1.2_2021` |
| レスポンスヘッダー | すべてのビヘイビアに、CloudFront の AWS マネージドのレスポンスヘッダーポリシー `SecurityHeadersPolicy` (ID `67f7725c-6f97-4210-82d7-5512b31e9d03`) を設定する。`Strict-Transport-Security: max-age=31536000`、`X-Content-Type-Options: nosniff`、`X-Frame-Options: SAMEORIGIN`、`Referrer-Policy: strict-origin-when-cross-origin`、`X-XSS-Protection: 1; mode=block` が付く。Redmine は `force_ssl` を有効にしていないので (`config/environments/production.rb`)、HSTS は CloudFront で付ける |
| 添付ファイル | ビヘイビア `/files/*` (添付ファイルの GET) と `/tmp/*` (サムネイルと zip の GET、`/tmp/incoming/` へのアップロードの PUT) は、OAC で添付ファイル用バケットに転送し、CloudFront 署名付き URL を必須にする。どちらにも、`SecurityHeadersPolicy` が `nosniff` を付け、ビューワーレスポンスの CloudFront Functions (`<instance>-attachment-headers`) が、sandbox の CSP と、署名付き URL のファイル名と種類を付ける ([attachments.md](https://redmine-kit.github.io/redmine_aws_s3/ja/attachments.html#download)) |
| 関数 URL | OAC の署名がないリクエストは、関数が呼び出される前に拒否される ([lambda.md](lambda.md#cloudfront-and-function-urls)) |
| ホストとスキーム | CloudFront は、ドメインを `X-Forwarded-Host` で、`https` を `X-Forwarded-Proto` で渡す。どちらもオリジンカスタムヘッダーで、ビューワーが送った同じ名前のヘッダーを上書きする。Rails はドメインだけを受け付け (`config.hosts`)、Lambda では `redmine_aws_lambda` が `X-Forwarded-Host` を `Host` にするので、関数 URL のホスト名は受け付けない。ヘッダーがないリクエストやほかのホストのリクエストは 403 になる ([lambda.md](lambda.md#host-and-scheme)) |
| キャッシュするレスポンス | CloudFront がキャッシュするのは、`/assets/*` (S3 のコンパイル済みのアセット) と `/favicons/*` (Redmine 7.1 のファビコン。Redmine が誰にでも public、immutable で返すもの) だけ。`/favicons/*` は Cookie を Redmine に転送せず、CloudFront がレスポンスから `Set-Cookie` を削除するので、キャッシュしたレスポンスにセッションは入らない。Redmine の画面、アバター (Redmine 7.1)、添付ファイルは CloudFront でキャッシュしない ([lambda.md](lambda.md#the-favicon)) |
| リクエスト本文 | Redmine のビヘイビアでは 1 MB まで。超えると Lambda@Edge が 413 を返す。`/tmp/incoming/` へのアップロードは、Lambda ではなく S3 に到達し、アップロードの上限を超える本文は CloudFront Functions が拒否する ([attachments.md](https://redmine-kit.github.io/redmine_aws_s3/ja/attachments.html#upload)) |

ディストリビューションは、どのプランでも AWS マネージドのポリシー (キャッシュ、オリジンリクエスト、レスポンスヘッダー) だけを使い、添付ファイルのヘッダーは CloudFront Functions で付けます ([lambda.md](lambda.md#flat-rate-free-plan-and-waf))。無料プランとプロプランで使えるのは、マネージドポリシーだけです。Content Security Policy などを独自に定義するポリシーはビジネスプランからで、この設計では使いません。

<a id="aws-waf"></a>

## AWS WAF

CloudFront に AWS WAF のウェブ ACL を関連付け、Redmine に到達する前に、よくある攻撃と、過剰なリクエストをブロックします。

<a id="plan-and-cost"></a>

### プランと費用

テンプレートは、どのプランでも同じ構成を作成します。下の 5 つのルールと AWS マネージドの CloudFront のポリシーを使い、CloudFront と WAF のログは設定しません。構成は定額料金プランの無料プランに収まるように作っていて、プランで変わるのは料金と含まれる使用量だけです。

| プラン | WAF の費用 | 使う場合 |
| --- | --- | --- |
| CloudFront の定額料金プランの無料プラン (デフォルト) | 0 ドル (プランに含まれる) | この設計の前提のプラン。WAF ルールは 5 つまでで、この設計は 5 つすべてを使う |
| 定額料金プランのプロプラン | 月額 15 ドル (CloudFront と WAF を含む) | 使用量が無料プランの月 100 万リクエスト、100 GB を超える見込みの場合。構成は同じ |
| 従量課金 | ウェブ ACL 1 つで月額 5 ドル、ルールかマネージドルールグループ 1 つで月額 1 ドル、リクエスト 100 万件で 0.60 ドル。下の 5 つのルールなら月額 10 ドル程度 | アカウントに無料プランの枠が残っていない場合 (1 つのアカウントで 3 つまで。下記)。構成は同じ |

定額料金プランには、いくつかの制約があります。ウェブ ACL は関連付けを解除できず (解除するには従量課金に戻す)、独自のルールグループは使えないので、ルールを 1 つずつ設定します。無料プランは 1 つのアカウントで 3 つまでで、この上限は引き上げられません。ほかのディストリビューションが使っているウェブ ACL や CloudFront Functions は、プランのディストリビューションに関連付けられないので、独自に用意するウェブ ACL (`cloudfront.webAclArn`) は、このディストリビューション専用にします。キャッシュビヘイビアは、無料プランで 5 つまでです (この設計は 5 つ。最後の 1 つは Redmine 7.1 のファビコン用。[lambda.md](lambda.md#the-favicon))。

無料プランでは、CAPTCHA、JavaScript のチャレンジ、ヘッダーや正規表現で絞り込むルール、ブロック時のレスポンスのカスタマイズ、Bot Control は使えません。そのため、ログインのレート制限は、正規表現ではなく、文字列の一致 (前方一致) でパスを指定します。無料プランとプロプランでは、WAF が検査する本文は最初の 16 KB までです。

CloudFront のウェブ ACL は us-east-1 に作成し、インスタンスの us-east-1 のスタック (`<instance>-edge`) に置きます ([deploy-config.md](deploy-config.md))。

<a id="rules"></a>

### ルール

ルールは 5 つです (無料プランの上限)。上から順に評価します。デフォルトアクションは「許可」です。

| 優先順位 | ルール | 内容 | デフォルト値 | アクション |
| --- | --- | --- | --- | --- |
| 1 | ログインのレート制限 (レートベース) | `POST` で、パスが `/login`、`/account/lost_password`、`/account/register`、`/account/twofa` のいずれかで始まるリクエストを、IP アドレスごとにカウントする | 5 分で 20 回 | ブロック |
| 2 | 全体のレート制限 (レートベース) | すべてのリクエストを、IP アドレスごとにカウントする | 5 分で 1,000 回 | ブロック |
| 3 | AWS マネージドルール: Amazon IP Reputation List | 評価の低い IP アドレス | — | ブロック |
| 4 | AWS マネージドルール: Known Bad Inputs | 既知の不正な入力 (Log4j のパターンなど) | — | ブロック |
| 5 | AWS マネージドルール: Common Rule Set | よくある攻撃 (SQL インジェクション、典型的な XSS、パストラバーサルなど) | — | 最初はカウントだけ。確認してからブロック (下記) |

Redmine には、ログインの失敗回数でアカウントをロックする仕組みがありません (Redmine 7.0.3 のソースで確認)。そのため総当たり攻撃は、ログインのレート制限と二要素認証で防ぎます。二要素認証のコードの試行は、Redmine 自身がパスワード 1 回につき 3 回までに制限しています。

レートベースのルールは、1、2、5、10 分のいずれかの期間でカウントし、しきい値の下限は 10 です。WAF は設定した回数の近くでブロックしますが、正確な回数は保証していません (WAF の資料)。CloudFront を経由するので、カウントする IP アドレスはユーザーのものです。全体の 1,000 回は初期値です。Redmine の 1 画面は、アセットを除いて数件のリクエストで、アセットも CloudFront を経由するので回数に含まれます。利用状況を計測して決め、社内からのリクエストが 1 つの IP アドレスにまとまる (NAT など) 場合は引き上げます。

Common Rule Set を最初はカウントだけにするのは、Redmine の正当なリクエストをブロックするルールがあるためです。`SizeRestrictions_BODY` (本文が 8 KB を超えるとブロック) は、wiki やチケットの長い本文をブロックし、`CrossSiteScripting_BODY` などは、wiki に書いたコード例をブロックすることがあります。最初の 2 週間ほどはルールグループ全体をカウントだけにし、ブロックされるはずだったリクエストをダッシュボードで確認して、該当したルールだけをカウントのまま残し、ほかはブロックにします。

Redmine 7.1 のファビコン (PNG または ICO で 32 KB まで) は、設定のフォームで Lambda に送ります。`SizeRestrictions_BODY` は 8 KB を超えるフォームに一致しますが、カウントするだけです。最初のカウントの期間も、ブロックに変えたあとも、`waf.commonRuleSetCountOnly` のルール (デフォルトは `SizeRestrictions_BODY`。[deploy-config.md](deploy-config.md)) としてカウントのままです。Common Rule Set のほかの本文のルールが画像のバイト列に一致するかは確認していません。ブロックされるはずだったリクエストに、設定のフォームがないかを確認します。Redmine 7.1 のアバターは `/tmp/incoming/` に送るので、このルールグループの検査の対象外です ([attachments.md](https://redmine-kit.github.io/redmine_aws_s3/ja/attachments.html#avatars))。

国によるブロックは無料プランでも使えますが、出張先などから使うユーザーがいるので、デフォルトでは使いません。使う場合は、ルールが 5 つを超えないように全体のレート制限と入れ替えます。無料プランで WAF がリクエストをブロックすると、WAF のデフォルトの 403 を返します。

WAF は、リクエストがオリジンに到達する前に評価されます。WAF がブロックしたリクエストでは、Lambda@Edge も Lambda も呼び出されず、定額料金プランの使用量にも含まれません (CloudFront の資料)。

<a id="monitoring"></a>

### 監視

- **ダッシュボード:** CloudFront のセキュリティダッシュボード (無料プランでも使える) で、ブロックしたリクエストと、該当したルールを確認します。
- **アラーム:** WAF の CloudWatch メトリクス (ルール別のブロック数) に、アラームを設定します。ログインのレート制限が急に増えたら、総当たり攻撃を疑います。
- **ログ:** この設計では、どのプランでも CloudFront と WAF のログを保持しません (無料プランにはログが含まれません)。インシデントの調査には、セキュリティダッシュボード、ブロックしたリクエストのサンプル、Lambda のログを使います。

<a id="settings"></a>

### 設定

プラン、レート制限、Common Rule Set をブロックにするかは、設定ファイルの `cloudfront.plan` と `waf.*` で、インスタンスごとに決めます ([deploy-config.md](deploy-config.md#fields-of-redminejson))。

<a id="redmine-settings"></a>

## Redmine の設定

設定ファイルの `redmine.settings` (初回のデプロイで設定する値。[deploy-config.md](deploy-config.md)) で、次の値を初期値にします。

| 設定 (Redmine の画面での名前) | 値 | 理由 |
| --- | --- | --- |
| 認証が必要 (`login_required`) | 有効 | ログインしていないユーザーに表示しない。`/robots.txt` も、すべてを拒否する |
| ユーザーによるアカウント登録 (`self_registration`) | 無効 | 不特定のユーザーがアカウントを作成できないようにする (Redmine のデフォルトは、管理者の承認による登録) |
| 二要素認証 (`twofa`) | システム管理者のみ必須 (できれば必須) | 管理者アカウントが、パスワードだけで侵害されないようにする |
| パスワードの最低必要文字数 (`password_min_length`) | 12 (Redmine のデフォルトは 8) | 総当たり攻撃への対策 |
| 無操作タイムアウト、有効期間の最大値 (`session_timeout`、`session_lifetime`) | 決めた時間にする (Redmine のデフォルトは無効) | 放置された端末のセッションを長く残さない |
| RESTによるWebサービスを有効にする (`rest_api_enabled`) | 使う場合だけ有効 | 使わないなら、API キーによる操作を受け付けない (Redmine のデフォルトも無効) |
| JSONPを有効にする (`jsonp_enabled`) | 無効 | 別のオリジンから API のレスポンスを読ませない |
| 禁止する拡張子 (`attachment_extensions_denied`) | 実行可能ファイル (`exe`、`bat` など) を、アダプタが決める | 添付ファイルで有害なファイルを配布させない |

デプロイしたらすぐに、初期の管理者 (`admin`、パスワードも `admin`) のパスワードを変更し、二要素認証を設定します。このアカウントを使わない場合は、別の管理者を作成してからロックします。Lambda で使えない設定 (リポジトリと受信メールの Web サービス) は、プラグインが無効に固定します ([admin.md](https://redmine-kit.github.io/redmine_aws_lambda/ja/admin.html#redmine-settings-that-cannot-work-on-lambda))。

<a id="aws-accounts-and-permissions"></a>

## AWS アカウントと権限

- **権限:** ロールと権限の詳細は [iam.md](iam.md) にあります。関数ごとのロール、アクセス許可の境界、インフラの変更の承認、アクセスキーを作成しないことが要点です。
- **アカウントの保護:** root ユーザーには MFA を設定し、通常は使いません。人は IAM Identity Center (SSO) で、MFA を使ってサインインします。
- **S3:** アカウントとバケットの両方で、パブリックアクセスブロックを有効にします。バケットポリシーで、TLS を使わないリクエストを拒否します ([iam.md](iam.md#resource-based-policies))。
- **監視:** CloudTrail (管理イベント) をアカウントで有効にし、IAM Access Analyzer で外部からアクセスできるリソースがないかを確認します。GuardDuty は、アカウントで有効にすることを推奨します (費用は、構築時に確認する)。

<a id="protecting-data"></a>

## データの保護

| データ | 保存時の暗号化 | 転送時の暗号化 | バックアップ |
| --- | --- | --- | --- |
| RDS for PostgreSQL | 保存時の暗号化 (AWS マネージドキー) | TLS を強制する (`rds.force_ssl`)。関数は証明書を検証する (`verify-full`) | 自動バックアップ (ポイントインタイムリカバリ)。削除保護を有効にする |
| S3 (添付ファイル、メール、アセット) | SSE-S3 | TLS だけを許可する | 添付ファイル用バケットはバージョニング。削除しても、決めた期間は復元できる |
| SSM Parameter Store | SecureString (`aws/ssm` のキー) | TLS | シークレットは、`bin/deploy` が初回に作成する。再作成の手順は下の「インシデント対応」 |
| CloudWatch Logs | デフォルトで暗号化される | TLS | 下の「保持期間」 |

バックアップから、別の DB インスタンスとバケットに復元する訓練を、定期的に行います。復元できることを確認していないバックアップは、当てにしません。

<a id="retention-periods"></a>

## 保持期間

ログ、記録、一時ファイル、バックアップの保持期間です。すべての期間を、ここで決めます。ほかの資料の期間は、この表に合わせます。設定ファイルに項目があるものは、インスタンスごとに変更できます ([deploy-config.md](deploy-config.md#fields-of-redminejson))。

| 対象 | 期間 (デフォルト) | 削除の方法 | 設定ファイルの項目 |
| --- | --- | --- | --- |
| CloudWatch Logs (`redmine-web`、`redmine-worker`、`redmine-task`) | 90 日 | ロググループの保持設定。ロググループは CloudFormation で先に作成する | `logs.retentionDays` |
| CloudWatch Logs (Lambda@Edge の `redmine-body-hash`) | 90 日 | Lambda@Edge は、実行されたリージョンごとに、ロググループを自動で作成する。CloudFormation では先に作成できないので、`bin/deploy` が、すべてのリージョンのロググループに保持設定を適用する (作成されたあとのものにも、デプロイのたびに適用し直す) | `logs.retentionDays` |
| CloudWatch Logs (Session Manager。NAT インスタンス構成だけ) | 90 日 | ロググループの保持設定 | `logs.retentionDays` |
| CloudTrail (管理イベント) | 1 年 (案) | 証跡を保存する S3 バケットのライフサイクル。アカウントの規定があれば、それに従う。CloudTrail のイベント履歴 (90 日) は、AWS が決めている | アカウントの基盤で決める (この設計の対象外) |
| 受信したメールの記録 (`aws_ses_received_mails`) | 90 日 | 毎日の定期 rake で削除する ([tasks.md](tasks.md#scheduled-runs)) | `retention.recordsDays` |
| 失敗したジョブの記録 (`aws_sqs_job_failures`) | 90 日 | 同上 | `retention.recordsDays` |
| 取り込んだメール (`processed/`) | 30 日 | S3 ライフサイクル | `retention.mailDays` |
| 取り込まなかったメール (`inbound/` に残ったもの。破棄したもの、失敗したもの) | 30 日 | S3 ライフサイクル。取り込みのやり直しは、この期間内に行う | `retention.mailDays` |
| SQS のデッドレターキュー | 14 日 | SQS のメッセージ保持期間 (SQS の上限) | — |
| 添付ファイルの以前のバージョン (削除したものと、上書きされたもの) | 30 日 | S3 ライフサイクル (以前のバージョンを削除する) | `retention.noncurrentVersionDays` |
| 一時ファイル (`tmp/`。一括ダウンロードの zip、読み書きテスト) | 1 日 | S3 ライフサイクル | — |
| 登録前のアップロード (`tmp/incoming/`) | 1 日 | S3 ライフサイクル | — |
| CSV インポートのファイル (`imports/`) | 7 日 | S3 ライフサイクル | — |
| 古いアセット | 90 日 | S3 ライフサイクル (以前のバージョンを削除する) | — |
| ECR イメージ | 新しいものから 10 個 | ECR のライフサイクル。関数が使っているイメージは削除しない ([lambda.md](lambda.md#image)) | — |
| RDS の自動バックアップ | 7 日 | DB インスタンスのバックアップ保持期間 ([rds.md](rds.md#settings)) | `retention.backupDays` |
| WAF のサンプルリクエスト | AWS が決めた期間 (直近の数時間。構築時に確認する) | — | — |

インシデントの発生時は、調査が終わるまで、これらの期間で削除されないようにします (下の「インシデント対応」)。期間を短くしすぎないことも重要です。ログと記録はインシデントに気づくまでの時間より長く保持し、90 日より短くするときは、その時間を見積もってから決めます。ログと記録には、ユーザーのメールアドレスと IP アドレスが含まれます。アダプタの規定で保持できる期間に上限があれば、それに合わせて短くします。

<a id="logs"></a>

## ログ

- **署名付き URL を記録しない:** Rails は、リダイレクト先の URL をログに書き込みます。添付ファイルのダウンロードの署名付き URL がログに残ると、ログを読める人が、有効期限のあいだ添付ファイルを読めます。Redmine のドメインの `/files/` と `/tmp/` の下の URL (添付ファイル、サムネイル、一括ダウンロードの zip) へのリダイレクトを Rails の設定 `config.filter_redirect` に指定し、ログには `[FILTERED]` と書き込ませます ([lambda.md](lambda.md#rails-and-redmine-settings))。
- **パラメーターをマスクする:** Redmine は、`password`、`salt`、`twofa_totp_key`、`key` のパラメーターを、ログでマスクします (`config/application.rb` の `filter_parameters`)。プラグインが追加する画面のパラメーターも、機密性のあるものは同じくマスクします。
- **IP アドレス:** CloudFront を経由するので、Redmine には `X-Forwarded-For` でユーザーの IP アドレスが渡されます。Rails の `remote_ip` が、CloudFront の IP アドレスではなくユーザーの IP アドレスを返すか (信頼するプロキシの設定) は、構築時に確認します。
- **閲覧者を限定する:** ログを読む権限は、運用担当者だけに付与します ([iam.md](iam.md#permissions-of-people))。

<a id="supply-chain"></a>

## サプライチェーン

| 対象 | 対策 |
| --- | --- |
| ベースイメージ、Lambda Web Adapter | タグではなく digest で参照する ([AGENTS.md](../../AGENTS.md)) |
| Redmine、Pandoc | ダウンロードしたファイルの SHA256 を確認する |
| gem | `Gemfile.lock` で固定する。CI で、既知の脆弱性がないかをスキャンする (`bundler-audit`) |
| イメージ | CI で、イメージ内の OS パッケージと gem の既知の脆弱性をスキャンする (Trivy など)。重大な脆弱性があれば、デプロイしない |
| GitHub Actions | 使うアクションを、タグではなくコミットの SHA で固定する |
| Lambda@Edge 関数 | 依存する npm パッケージを使わない (`node:crypto` だけ) |
| 配布するイメージとプラグイン | アダプタは、イメージを digest で参照する。プラグインの gem は、バージョンとチェックサムを `image/Gemfile.lock` で固定する ([architecture.md](architecture.md#distribution)) |
| アダプタが追加するプラグインとテーマ | `image.plugins` と `image.themes` には、バージョンを完全に指定した gem、タグか完全なコミットハッシュを指定した Git のリポジトリ (ブランチは不可)、ディレクトリだけを指定でき、派生イメージでもベースイメージの gem のバージョンは変えない (別のバージョンを必要とするプラグインは、ビルドを失敗させる)。Git の取得元は HTTPS の公開リポジトリで、認証情報なしで取得する。GitHub Packages の認証情報はビルドのシークレットで渡し、レイヤーにも `redmine.json` にも残さない。追加したコードは関数の権限で動くので、アダプタが内容を確認する。タグは付け替えられるので、Git の取得元はコミットハッシュのほうが確実に固定できる ([architecture.md](architecture.md#derived-images)) |

Redmine の更新と、gem とイメージの更新は、[upgrade.md](upgrade.md) の確認を経てから行います。

<a id="remaining-risks"></a>

## 残存リスク

この設計では防ぎきれず、運用で補うものです。

| リスク | 理由 | 対処 |
| --- | --- | --- |
| Redmine の脆弱性 | Redmine と Rails の脆弱性は、バージョンアップするまで残る | Redmine のセキュリティ情報を確認して、早めにバージョンアップする。WAF で一部を防ぐ |
| ログインの総当たり攻撃 | Redmine に、失敗回数でアカウントをロックする仕組みがない | WAF のレート制限と、二要素認証 |
| NAT インスタンスを経由する外部への通信 | NAT インスタンス構成では、関数がインターネットにアクセスできる | 侵害されないことに注力する (上の対策)。外部への通信を止める必要があれば、VPC エンドポイント構成にする ([rds.md](rds.md#which-to-choose)) |
| リポジトリの URL | 「リポジトリの管理」の権限を持つユーザーが、関数が `svn` で読む URL (と `git` が読むパス) を設定する。webhook の `webhook_blocklist` のような拒否リストは、Redmine にない | 「リポジトリの管理」は信頼できるロールにだけ与える。関数が接続できるのは VPC のルートが許す範囲だけで、VPC エンドポイントの構成ではインターネット上のサーバーに接続できない ([lambda.md](lambda.md#repositories)) |
| データベースパスワード | 一時的な認証情報と違い、パスワードは自動では失効しない | SSM (SecureString) と RDS にだけ保存し、RDS には VPC 内からしか接続できない。インシデントの発生時は変更する (下記) |
| 添付ファイルのウイルス | Redmine は添付ファイルをスキャンしない | `tmp/incoming/` と `imports/` に GuardDuty Malware Protection for S3 を使い、`REDMINE_S3_MALWARE_SCAN=true` にする。プラグインは、問題がないと判定されたファイルだけを使う ([attachments.md](https://redmine-kit.github.io/redmine_aws_s3/ja/attachments.html#malware-scan)、費用も) |
| CloudFront と WAF のログがない | 定額料金プランの無料プランに、ログが含まれない | Lambda のログと、セキュリティダッシュボードで確認する |

<a id="incidents"></a>

## インシデント対応

1. **停止:** `redmine-web` と `redmine-worker` の予約された同時実行を 0 にし、外部からの操作を止めます (CloudFront がメンテナンス画面を返す。[deploy-config.md](deploy-config.md#deployment-commands))。メール受信を止めるときは、SES の受信ルールを無効にします。
2. **保全:** CloudTrail、CloudWatch Logs、S3 のバージョン、プラグインの記録を、削除せずに残します。調査が終わるまで、上の「保持期間」で削除されないように、ロググループの保持設定と S3 ライフサイクルを停止し、定期 rake による記録の削除も止めます。
3. **認証情報の更新:**
   - `SECRET_KEY_BASE` を再生成します (SSM パラメーターを新しい値にして、関数を更新する)。セッション Cookie が無効になり、ユーザーは再ログインします。
   - データベースパスワードを変更します (RDS と SSM パラメーターに新しい値を設定して、関数を更新する)。
   - 漏えいしたおそれのあるユーザーのパスワードと API キーを、再発行してもらいます。管理者アカウントを確認します。
   - AWS 側では、関係したロールのセッションを無効にします (IAM の「セッションを取り消す」)。
4. **復旧:** データが破壊されたときは、RDS の自動バックアップ (ポイントインタイムリカバリ) と S3 のバージョンから復元します (上の「データの保護」)。
5. **通知:** アダプタの規定と法令に従って、ユーザーや関係者に通知します。

<a id="to-verify"></a>

## 未確認の事項

- `config.filter_redirect` で、CloudFront 署名付き URL へのリダイレクトがログに残らないか
- プランの機能の表と照らした構成を、CloudFront が定額料金プランの無料プランで受け付けるか ([lambda.md](lambda.md#flat-rate-free-plan-and-waf))。AWS マネージドルールグループが WAF のルール 5 つのうち 1 つとして数えられるか、AWS マネージドルールグループにスコープダウンステートメントを設定できるか
- WAF の Common Rule Set のうち、Redmine の正当なリクエストをブロックするルール (本文のサイズ、XSS のパターンなど)
- Common Rule Set の `SizeRestrictions_BODY` 以外の本文のルールが、Redmine 7.1 のファビコンを含む設定のフォーム (PNG や ICO の画像のバイト列) に一致するか
- Rails の `remote_ip` が、CloudFront を経由したリクエストで、ユーザーの IP アドレスになるか
- 関数 URL が、CloudFront の `X-Forwarded-Host` と `X-Forwarded-Proto` をそのまま関数に渡すか ([lambda.md](lambda.md#host-and-scheme))
- GuardDuty と、S3 のマルウェアスキャンの費用
- `bin/deploy` が、デプロイ用ロールで、すべてのリージョンの Lambda@Edge のロググループに保持設定を適用できるか (そのロググループへの `logs:PutRetentionPolicy`、`logs:DescribeLogGroups`、`ec2:DescribeRegions`。[iam.md](iam.md#role-for-deploying-infrastructure))
- WAF のサンプルリクエストを確認できる期間
