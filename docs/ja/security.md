# セキュリティ

Serverless のセキュリティの設計です。守るもの、起きうること、層ごとの守り、残るリスク、事故のときの手順をまとめます。権限、ネットワーク、データベースの細かい設定は、それぞれの資料にあり、この資料からリンクします。

この資料の仕様は、2026-11-09 時点の公式の情報と、Redmine 7.0.3 のソースで確認したものです。出典は [sources.md](sources.md) にあります。

<a id="approach"></a>

## 方針

- **Redmine の外に出る道を少なくする:** 外から届くのは CloudFront だけにします。関数 URL は OAC の署名がないと呼べず、データベースは、パブリックアクセスのない VPC のプライベートのサブネットに置きます。
- **権限を小さく分ける:** 関数ごと、インスタンスごとに権限を分け、1 つが破られても広がらないようにします。
- **秘密の値を減らす:** AWS のアクセスキーは作りません。残る秘密の値(データベースのパスワードと `SECRET_KEY_BASE`)は、SSM Parameter Store の SecureString に置きます。
- **Redmine の標準の守りを使う:** 二要素認証、パスワードの決まり、権限とロールは、Redmine の標準の機能を使い、プラグインで作り直しません。
- **安全な既定値:** 設定のファイルと Redmine の設定の初めの値は、安全な側にします(下の「Redmine の設定」)。緩めるときは、使う人が理由を決めて変えます。

<a id="what-to-protect"></a>

## 守るもの

| 守るもの | 置き場所 | 漏れたり壊れたりしたときの影響 |
| --- | --- | --- |
| Redmine のデータ(チケット、wiki、利用者、パスワードのハッシュ、API キー) | RDS for PostgreSQL | 業務の情報と、利用者のアカウントが漏れる |
| 添付ファイル | S3 の添付ファイルのバケット | 業務の文書が漏れる |
| 受け取ったメール | S3 のメールのバケット(`inbound/`、`processed/`) | メールの全文が漏れる |
| 秘密の値(`SECRET_KEY_BASE`、データベースのパスワード) | SSM Parameter Store | セッションの Cookie を偽造される。VPC の中からデータベースを読み書きされる |
| AWS の権限 | 実行ロール、デプロイ用のロール、管理者の SSO | AWS のリソースを読み書きされる。費用を使われる |
| 管理者のアカウント | Redmine と SSO | すべてのデータと設定を変えられる |

<a id="threats-and-protections"></a>

## 起きうることと守り

| 起きうること | 主な守り | 資料 |
| --- | --- | --- |
| Redmine の弱点を突かれる | Redmine を早めに上げる、WAF、読み取り専用のファイルシステム | [upgrade.md](upgrade.md)、下の「AWS WAF」 |
| パスワードの総当たり、使い回しのパスワード | 二要素認証(管理者は必須)、パスワードの決まり、WAF のログインへの回数の制限 | 下の「Redmine の設定」「AWS WAF」 |
| 関数 URL を直接呼ばれる | 関数 URL は IAM の認証で、OAC の署名がないと関数が呼ばれない | [lambda.md](lambda.md#cloudfront-and-function-urls) |
| データベースに外からつながれる | RDS はパブリックアクセスのないプライベートのサブネットに置く。セキュリティグループは関数からだけを許す。パスワードは SSM と RDS にだけ置く | [rds.md](rds.md#security) |
| 添付ファイルを権限のない人に読まれる | Redmine が権限を確認してから、5 分の署名付き URL を出す。バケットは公開しない | [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html#download) |
| 署名付き URL が漏れる | 期限は 5 分。ログに残さない(下の「ログ」) | 下の「ログ」 |
| 添付ファイルで悪いコードを動かされる(HTML、SVG) | 添付ファイルは S3 のドメインから配るので、Redmine とは別のオリジンになり、Redmine の Cookie を読めない。PDF のほかは、ダウンロードとして返す(`Content-Disposition: attachment`。Redmine の標準と同じ) | [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html#download) |
| 差出人を偽ったメールで、チケットを作られる | DMARC が通らないメール、迷惑メール、ウイルスのメールを捨てる。登録のないアドレスのメールを受けない | [mail.md](mail.md#spoofing-and-spam) |
| webhook で、内向きのアドレスに要求を送らされる(SSRF) | `webhook_blocklist` で、プライベート、ループバック、リンクローカルのアドレスを断る | [lambda.md](lambda.md#rails-and-redmine-settings) |
| 依存の gem やイメージに悪いコードが混ざる | digest と SHA256 で固定する、依存の弱点の検査、GitHub Actions を SHA で固定する | 下の「供給網」 |
| AWS の権限を広げられる | 関数ごとのロール、権限の境界、インフラの変更は承認が要る | [iam.md](iam.md) |
| 費用を使われる(大量の要求) | 同時実行数の予約、WAF の回数の制限、CloudFront の定額プラン(WAF が止めた要求は使用量に数えない) | 下の「AWS WAF」 |
| インスタンスのあいだでデータが混ざる | 名前とロールをインスタンスごとに分け、対象を ARN で絞る | [deploy-config.md](deploy-config.md) |

<a id="entry-point-cloudfront"></a>

## 入口(CloudFront)

| 項目 | 決めたこと |
| --- | --- |
| HTTPS | ビューアーには HTTPS だけを許し、HTTP は HTTPS にリダイレクトする。TLS の最低のバージョンは、CloudFront のセキュリティポリシー `TLSv1.2_2021` |
| 応答のヘッダー | CloudFront の AWS 管理の応答のヘッダーのポリシー `SecurityHeadersPolicy`(ID `67f7725c-6f97-4210-82d7-5512b31e9d03`)を付ける。`Strict-Transport-Security: max-age=31536000`、`X-Content-Type-Options: nosniff`、`X-Frame-Options: SAMEORIGIN`、`Referrer-Policy: strict-origin-when-cross-origin`、`X-XSS-Protection: 1; mode=block` が付く。Redmine は `force_ssl` を有効にしていないので(`config/environments/production.rb`)、HSTS は CloudFront で付ける |
| 関数 URL | OAC の署名がない要求は、関数が呼ばれる前に断られる([lambda.md](lambda.md#cloudfront-and-function-urls)) |
| 要求の本文 | 1 MB まで。超えたら Lambda@Edge が 413 を返す |

- **自分で作る応答のヘッダー:** Content Security Policy などを自分で決めるポリシーは、定額プランの Business より上だけです。Free と Pro では、上の AWS 管理のポリシーを使います。

<a id="aws-waf"></a>

## AWS WAF

CloudFront に AWS WAF の Web ACL を付け、Redmine に届く前に、よくある攻撃と、回数の多すぎる要求を止めます。

<a id="plan-and-cost"></a>

### プランと費用

| 形 | WAF の費用 | ルールの数 | ログ | 向いているとき |
| --- | --- | --- | --- | --- |
| CloudFront の定額プラン Free(既定) | 0 ドル(プランに含まれる) | 5 | なし。セキュリティのダッシュボードと、止めた要求のサンプルだけ | 少人数で、ログを残す決まりがないとき |
| 定額プラン Pro | 月 15 ドル(CloudFront と WAF を含む) | 25 | CloudFront のアクセスログと WAF のログを、CloudWatch Logs に送れる(取り込みは含まれ、保存と検索は別料金) | ログを残したいとき。CAPTCHA、ヘッダーでのルール、止めたときの応答を変えたいとき |
| 従量 | Web ACL 1 つで月 5 ドル、ルールか管理ルールのグループ 1 つで月 1 ドル、100 万件の要求で 0.60 ドル。下の 5 つのルールなら月 10 ドルほど | 上限なし | 送れる(別料金) | 定額プランの決まり(下記)に合わないとき |

- **定額プランの決まり:** 定額プランでは、Web ACL を外せません(外すには従量に戻す)。自分で作るルールのグループは使えず、ルールを 1 つずつ置きます。Free のプランは、1 つのアカウントで 3 つまでで、上限は上げられません。キャッシュのビヘイビアは、Free で 5 つまでです(この設計は 2 つ)。
- **Free で使えないもの:** CAPTCHA、JavaScript のチャレンジ、ヘッダーで絞るルール、正規表現で絞るルール、止めたときの応答を変えること、Bot Control。
- **調べる本文:** WAF が中身を調べる本文は、Free と Pro では最初の 16 KB までです。それより後ろは調べません。
- **置き場所:** CloudFront の Web ACL は us-east-1 に作ります。インスタンスの us-east-1 のスタック(`<instance>-edge`)に置きます([deploy-config.md](deploy-config.md))。

<a id="rules"></a>

### ルール

ルールは 5 つです(Free の上限)。上から順に当てます。既定の動きは「通す」です。

| 順 | ルール | 中身 | 既定の値 | 動き |
| --- | --- | --- | --- | --- |
| 1 | ログインの回数の制限(rate-based) | `POST` の `/login`、`/account/lost_password`、`/account/register`、`/account/twofa` を、IP アドレスごとに数える | 5 分で 20 回 | 止める |
| 2 | 全体の回数の制限(rate-based) | すべての要求を、IP アドレスごとに数える | 5 分で 1,000 回 | 止める |
| 3 | AWS の管理ルール: Amazon IP Reputation List | 悪い評判の IP アドレス | — | 止める |
| 4 | AWS の管理ルール: Known Bad Inputs | 知られた悪い入力(Log4j の形など) | — | 止める |
| 5 | AWS の管理ルール: Common Rule Set | よくある攻撃(SQL インジェクション、XSS の典型、パスの書き換えなど) | — | 初めは数えるだけ。確認してから止める(下記) |

- **ログインの回数の制限:** Redmine には、ログインの失敗の回数でアカウントを止める仕組みがありません(Redmine 7.0.3 のソースで確認した)。総当たりは、このルールと二要素認証で防ぎます。二要素認証のコードの試しは、Redmine が、パスワード 1 回につき 3 回までに抑えています。
- **回数の制限の決まり:** 数える時間は 1、2、5、10 分から選べ、回数の下限は 10 です。WAF は、決めた回数の近くで止めますが、ちょうどの回数は約束していません(WAF の資料)。CloudFront を通るので、数える IP アドレスは、利用者の IP アドレスです。
- **全体の回数:** 1,000 回は、起点の値です。Redmine の 1 画面は、アセットを除いて数件の要求です(アセットも CloudFront を通るので数に入る)。使い方を測って決めます。社内からの要求が 1 つの IP アドレスにまとまる(NAT など)ときは、上げます。
- **Common Rule Set を初めは数えるだけにする理由:** Redmine の正しい要求を止めるルールがあるためです。`SizeRestrictions_BODY`(本文が 8 KB を超えると止める)は、wiki やチケットの長い本文を止めます。`CrossSiteScripting_BODY` などは、wiki に書いたコードの例を止めることがあります。初めの 2 週間ほどは、グループ全体を数えるだけにし、止めたはずの要求をダッシュボードで見て、当たったルールだけを数えるだけのまま残し、ほかを止める形にします。
- **国での遮断:** Free でも使えます。使うなら、ルールの数が 5 を超えないように、全体の回数の制限と入れ替えるか、Pro にします。既定では使いません(出張先などから使う人がいるため)。
- **止めたときの応答:** Free では、WAF の既定の 403 です。
- **Lambda@Edge より先:** WAF は、オリジンへの要求の前に当たります。WAF が止めた要求では、Lambda@Edge も Lambda も呼ばれません。WAF が止めた要求は、定額プランの使用量にも数えません(CloudFront の資料)。

<a id="monitoring"></a>

### 見張り

- **ダッシュボード:** CloudFront のセキュリティのダッシュボード(Free でも使える)で、止めた要求と、当たったルールを見ます。
- **アラーム:** WAF の CloudWatch のメトリクス(ルールごとの止めた数)に、アラームを付けます。ログインの回数の制限が急に増えたら、総当たりを疑います。
- **ログ:** Free には WAF のログがありません。事故を調べるのにログが要るときは、Pro にします(上の「プランと費用」)。

<a id="settings"></a>

### 設定

プラン、回数の制限、Common Rule Set を止めるかは、設定のファイルの `cloudfront.plan` と `waf.*` で、インスタンスごとに決めます([deploy-config.md](deploy-config.md#fields-of-redminejson))。

<a id="redmine-settings"></a>

## Redmine の設定

設定のファイルの `redmine.settings`(初めて立てたときに入れる値。[deploy-config.md](deploy-config.md))で、次の値を初めの値にします。

| 設定(Redmine の画面の名前) | 値 | 理由 |
| --- | --- | --- |
| 認証が必要(`login_required`) | 有効 | ログインしていない人に見せない。`/robots.txt` も、すべてを拒む |
| ユーザーによるアカウント登録(`self_registration`) | 無効 | 知らない人がアカウントを作れないようにする(Redmine の既定は、管理者の承認での登録) |
| 二要素認証(`twofa`) | システム管理者のみ必須(できれば必須) | 管理者のアカウントが、パスワードだけで破られないようにする |
| パスワードの最低必要文字数(`password_min_length`) | 12(Redmine の既定は 8) | 総当たりへの備え |
| 無操作タイムアウト、有効期間の最大値(`session_timeout`、`session_lifetime`) | 決めた時間にする(Redmine の既定は無効) | 置き忘れた端末のセッションを長く残さない |
| RESTによるWebサービスを有効にする(`rest_api_enabled`) | 使うときだけ有効 | 使わないなら、API キーでの操作を受けない(Redmine の既定も無効) |
| JSONPを有効にする(`jsonp_enabled`) | 無効 | 別のオリジンから API の応答を読ませない |
| 禁止する拡張子(`attachment_extensions_denied`) | 実行できるファイル(`exe`、`bat` など)を、使う側で決める | 添付ファイルで悪いファイルを配らせない |

- **初めの管理者:** 初めの管理者(`admin`、パスワードも `admin`)は、立てたらすぐにパスワードを変え、二要素認証を設定します。使わないなら、別の管理者を作ってからロックします。
- **Lambda で使えない設定:** リポジトリと受信メールの Web サービスは、プラグインが無効に固定します([admin.md](https://redmine-kit.github.io/redmine_serverless/ja/admin.html#redmine-settings-that-cannot-work-on-lambda))。

<a id="aws-accounts-and-permissions"></a>

## AWS のアカウントと権限

- **権限:** ロールと権限の詳しい内容は [iam.md](iam.md) にあります。関数ごとのロール、権限の境界、インフラの変更の承認、アクセスキーを作らないことが要点です。
- **アカウントの守り:** root のユーザーには MFA を付け、ふだんは使いません。人は IAM Identity Center(SSO)で、MFA を付けて入ります。
- **S3:** アカウントとバケットの両方で、パブリックアクセスのブロックを有効にします。バケットポリシーで、TLS でない要求を断ります([iam.md](iam.md#resource-based-policies))。
- **見張り:** CloudTrail(管理のイベント)をアカウントで有効にし、IAM Access Analyzer で外から使えるリソースがないかを見ます。GuardDuty は、アカウントで有効にすることを勧めます(費用は、作るときに確認する)。

<a id="protecting-data"></a>

## データの守り

| データ | 保存のときの暗号化 | 通信の暗号化 | バックアップ |
| --- | --- | --- | --- |
| RDS for PostgreSQL | 保存時の暗号化(AWS の管理する鍵) | TLS を強制する(`rds.force_ssl`)。関数は証明書を確認する(`verify-full`) | 自動バックアップ(ある時点に戻せる)。削除の保護を有効にする |
| S3(添付ファイル、メール、アセット) | SSE-S3 | TLS だけを許す | 添付ファイルのバケットはバージョニング。消しても、決めた期間は戻せる |
| SSM Parameter Store | SecureString(`aws/ssm` の鍵) | TLS | 秘密の値は、`bin/deploy` が初めて作る。作り直しの手順は下の「事故のとき」 |
| CloudWatch Logs | 既定で暗号化される | TLS | 下の「保持の期間」 |

- **戻す練習:** バックアップから、別の DB インスタンスとバケットに戻す練習を、定期的に行います。戻せることを確認していないバックアップは、当てにしません。

<a id="retention-periods"></a>

## 保持の期間

ログ、記録、仮のファイル、バックアップを残す期間です。すべての期間を、ここで決めます。ほかの資料の期間は、この表に合わせます。設定のファイルの項目があるものは、インスタンスごとに変えられます([deploy-config.md](deploy-config.md#fields-of-redminejson))。

| 対象 | 期間(既定) | 消し方 | 設定のファイルの項目 |
| --- | --- | --- | --- |
| CloudWatch Logs(`redmine-web`、`redmine-worker`、`redmine-task`) | 90 日 | ロググループの保持の設定。ロググループは CloudFormation で先に作る | `logs.retentionDays` |
| CloudWatch Logs(Lambda@Edge の `redmine-body-hash`) | 90 日 | Lambda@Edge は、動いたリージョンごとに、ロググループを自動で作る。CloudFormation では先に作れないので、`bin/deploy` が、すべてのリージョンのロググループに保持の設定を当てる(作られたあとのものにも、デプロイのたびに当て直す) | `logs.retentionDays` |
| CloudWatch Logs(Session Manager。NAT インスタンスの形だけ) | 90 日 | ロググループの保持の設定 | `logs.retentionDays` |
| CloudTrail(管理のイベント) | 1 年(案) | 証跡を置く S3 のバケットのライフサイクル。アカウントの決まりがあれば、それに従う。CloudTrail のイベントの履歴(90 日)は、AWS が決めている | アカウントの土台で決める(この設計の外) |
| 受け取ったメールの記録(`serverless_received_mails`) | 90 日 | 毎日の定期の rake で消す([tasks.md](tasks.md#scheduled-runs)) | `retention.recordsDays` |
| 失敗したジョブの記録(`serverless_job_failures`) | 90 日 | 同上 | `retention.recordsDays` |
| 取り込んだメール(`processed/`) | 30 日 | S3 のライフサイクル | `retention.mailDays` |
| 取り込まなかったメール(`inbound/` に残ったもの。捨てたもの、失敗したもの) | 30 日 | S3 のライフサイクル。取り込み直しは、この期間のうちに行う | `retention.mailDays` |
| SQS のデッドレターキュー | 14 日 | SQS のメッセージの保持(SQS の上限) | — |
| 添付ファイルの古いバージョン(消したものと、上書きされたもの) | 30 日 | S3 のライフサイクル(古いバージョンを消す) | `retention.noncurrentVersionDays` |
| 仮のファイル(`tmp/`。一括のダウンロードの zip、読み書きの確認) | 1 日 | S3 のライフサイクル | — |
| 登録の前のアップロード(`incoming/`) | 1 日 | S3 のライフサイクル | — |
| CSV のインポートのファイル(`imports/`) | 7 日 | S3 のライフサイクル | — |
| 古いアセット | 90 日 | S3 のライフサイクル(古いバージョンを消す) | — |
| ECR のイメージ | 新しいものから 10 個 | ECR のライフサイクル。関数が使っているイメージは消さない([lambda.md](lambda.md#image)) | — |
| RDS の自動バックアップ | 7 日 | DB インスタンスのバックアップの保持の期間([rds.md](rds.md#settings)) | `retention.backupDays` |
| WAF のサンプルの要求 | AWS が決めた期間(直近の数時間。作るときに確認する) | — | — |

- **事故のとき:** 調べ終わるまで、上の期間で消えないようにします(下の「事故のとき」)。
- **短くしすぎない:** ログと記録は、事故に気づくまでの時間より長く残します。90 日より短くするときは、気づくまでの時間を見積もってから決めます。
- **個人の情報:** ログと記録には、利用者のメールのアドレスと IP アドレスが入ります。使う側の決まりで、残せる期間に上限があれば、それに合わせて短くします。

<a id="logs"></a>

## ログ

- **署名付き URL を残さない:** Rails は、リダイレクトの先の URL をログに書きます。添付ファイルのダウンロードの署名付き URL がログに残ると、ログを読める人が、期限のあいだ添付ファイルを読めます。Rails の設定 `config.filter_redirect` に S3 のホスト名を入れ、ログには `[FILTERED]` と書かせます([lambda.md](lambda.md#rails-and-redmine-settings))。
- **パラメーターを伏せる:** Redmine は、`password`、`salt`、`twofa_totp_key`、`key` のパラメーターを、ログで伏せます(`config/application.rb` の `filter_parameters`)。プラグインが足す画面のパラメーターも、秘密のものは同じく伏せます。
- **IP アドレス:** CloudFront を通るので、Redmine には `X-Forwarded-For` で利用者の IP アドレスが届きます。Rails の `remote_ip` が、CloudFront の IP アドレスではなく利用者の IP アドレスを返すか(信頼するプロキシの設定)は、作るときに確認します。
- **見る人を絞る:** ログを読める権限は、運用する人だけにします([iam.md](iam.md#permissions-of-people))。

<a id="supply-chain"></a>

## 供給網

| 対象 | 守り |
| --- | --- |
| 土台のイメージ、Lambda Web Adapter | タグではなく digest で参照する([AGENTS.md](../../AGENTS.md)) |
| Redmine、Pandoc | ダウンロードしたファイルの SHA256 を確認する |
| gem | `Gemfile.lock` で固定する。CI で、知られた弱点がないかを調べる(`bundler-audit`) |
| イメージ | CI で、イメージの中の OS のパッケージと gem の知られた弱点を調べる(Trivy など)。重い弱点があれば、デプロイしない |
| GitHub Actions | 使うアクションを、タグではなくコミットの SHA で固定する |
| Lambda@Edge の関数 | 依存の npm のパッケージを使わない(`node:crypto` だけ) |
| 配布するイメージとプラグイン | 使う側は、digest で参照する([architecture.md](architecture.md#distribution-proposal)) |

- **依存の更新:** Redmine の更新と、gem とイメージの更新は、[upgrade.md](upgrade.md) の確認を通してから行います。

<a id="remaining-risks"></a>

## 残るリスク

この設計では防ぎきれず、運用で補うものです。

| リスク | 理由 | 補う方法 |
| --- | --- | --- |
| Redmine の弱点 | Redmine と Rails の弱点は、上げるまで残る | Redmine のセキュリティの通知を見て、早めに上げる。WAF で一部を防ぐ |
| ログインの総当たり | Redmine に、失敗の回数でアカウントを止める仕組みがない | WAF の回数の制限と、二要素認証 |
| NAT インスタンスを通る外への通信 | NAT インスタンスの形では、関数がインターネットに出られる | 乗っ取られないことに力を入れる(上の守り)。外への通信を止める必要があれば、VPC のエンドポイントの形にする([rds.md](rds.md#which-to-choose)) |
| データベースのパスワード | 一時的な認証情報と違い、パスワードはひとりでには切れない | SSM(SecureString)と RDS にだけ置き、RDS には VPC の中からしか届かない。事故のときは変える(下記) |
| 添付ファイルのウイルス | Redmine は添付ファイルを検査しない | 必要なら、S3 のマルウェアの検査(GuardDuty Malware Protection for S3)を足す(費用と、検査が終わるまでの扱いは、作るときに決める) |
| CloudFront と WAF のログがない | 定額プラン Free に、ログが含まれない | Lambda のログと、セキュリティのダッシュボードで見る。足りなければ Pro にする |

<a id="incidents"></a>

## 事故のとき

1. **止める:** `redmine-web` と `redmine-worker` の同時実行数の予約を 0 にし、外からの操作を止めます(CloudFront が保守の画面を返す。[deploy-config.md](deploy-config.md#deployment-commands))。メールの受信を止めるときは、SES の受信のルールを無効にします。
2. **残す:** CloudTrail、CloudWatch Logs、S3 のバージョン、プラグインの記録を、消さずに残します。調べ終わるまで、上の「保持の期間」で消えないように、ロググループの保持の設定と S3 のライフサイクルを止め、定期の rake の記録の削除も止めます。
3. **入れ替える:**
   - `SECRET_KEY_BASE` を作り直します(SSM のパラメーターを新しい値にして、関数を更新する)。セッションの Cookie が無効になり、利用者はログインし直します。
   - データベースのパスワードを変えます(RDS と SSM のパラメーターに新しい値を設定して、関数を更新する)。
   - 漏れたおそれのある利用者のパスワードと API キーを、作り直してもらいます。管理者のアカウントを確認します。
   - AWS の側では、関わったロールのセッションを無効にします(IAM の「セッションを取り消す」)。
4. **戻す:** データが壊されたときは、RDS の自動バックアップ(ある時点に戻す)と S3 のバージョンから戻します(上の「データの守り」)。
5. **通知:** 使う側の決まりと法令に従って、利用者や関係する人に通知します。

<a id="to-verify"></a>

## 確認すること

- `config.filter_redirect` で、S3 の署名付き URL へのリダイレクトがログに残らないか
- CloudFront の応答のヘッダーのポリシーと WAF のルールが、定額プラン Free で使えるか
- WAF の Common Rule Set のうち、Redmine の正しい要求を止めるルール(本文の大きさ、XSS の形など)
- Rails の `remote_ip` が、CloudFront を通った要求で、利用者の IP アドレスになるか
- GuardDuty と、S3 のマルウェアの検査の費用
- Lambda@Edge のロググループに、すべてのリージョンで保持の設定を当てる方法(`bin/deploy` で当てるのに要る権限を含む)
- WAF のサンプルの要求を見られる期間
