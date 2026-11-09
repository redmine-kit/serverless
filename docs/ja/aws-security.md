# AWS のセキュリティの設定

AWS の側のセキュリティの設定をまとめます。それぞれについて、何を守るか、このプロジェクトのテンプレートが作るのか、使う側がアカウントごとに 1 回有効にするのか、費用、既定で有効かを書きます。起きうることと Redmine の中の守りは [security.md](security.md) に、ロールと権限は [iam.md](iam.md) にあります。

価格は、東京リージョン(ap-northeast-1)のもので、AWS の価格表から取りました(価格表の日付を添えます)。アカウントの使い方で変わる見込みには「見込み」と、価格表で確認していないものには「未確認」と書きます。

<a id="overview"></a>

## 一覧

| 設定 | 守るもの | 用意するもの | 既定 | 月の費用 |
| --- | --- | --- | --- | --- |
| [GuardDuty の脅威の検出](#guardduty) | 怪しい API の呼び出し、通信、使われている認証情報を見つける | 使う側。アカウントとリージョンごとに 1 回 | 有効にすることを勧める(テンプレートは作らない) | 見込み: 小さなアカウントで USD 1 未満 |
| [GuardDuty Malware Protection for S3](#malware-protection-for-s3) | 利用者がアップロードやインポートで送ったファイルを、Redmine が読む前にスキャンする | インスタンスのスタック | 有効(`uploads.malwareScan`) | 3,000 ファイル、6 GB で約 USD 1.2 |
| [CloudTrail](#cloudtrail) | アカウントの API の呼び出しの記録。調べるときのために残す | アカウントのスタック(`bin/deploy --account`)。アカウントに証跡があれば作らない | 証跡がないときに有効 | 管理イベントの最初のコピーは無料。S3 の保存 |
| [IAM Access Analyzer](#iam-access-analyzer) | アカウントの外に開いたリソースと、使われていないアクセスを見つける | アカウントのスタック。リージョンにアナライザーがあれば作らない | 外部のアクセス: 有効。使われていないアクセス: 無効 | 外部のアクセス: 無料。使われていないアクセス: ロールかユーザーごとに USD 0.20 |
| [AWS Security Hub](#aws-security-hub) | AWS の基礎的なセキュリティのベストプラクティスに照らして、アカウントを確認する | 使う側(任意) | 無効 | 確認 1 回あたり USD 0.001(最初の 100,000 回) |
| [AWS Config](#aws-config) | リソースの構成の履歴。Security Hub の確認に要る | 使う側(任意) | 無効 | 記録する構成の項目ごとに USD 0.003 |
| [S3 のパブリックアクセスのブロック(アカウント)](#s3-block-public-access) | アカウントのどのバケットも公開できない | 使う側。アカウントごとに 1 回 | 有効にすることを勧める | 無料 |
| [EBS の既定の暗号化](#ebs-default-encryption) | ボリュームを暗号化する(ボリュームを持つのは NAT インスタンスだけ) | NAT インスタンスのボリュームはテンプレートが暗号化する。アカウントの既定は使う側 | NAT のボリューム: 有効 | 無料 |
| [ルートユーザー](#the-root-user) | アカウントのいちばん強い認証情報 | 使う側 | — | 無料 |
| [人のアクセス](#peoples-access) | 管理者と運用する人のサインイン | 使う側(IAM Identity Center) | — | 無料 |
| [予算](#budgets) | 費用が上限を超えたときの通知 | 使う側 | 有効にすることを勧める | アクションのない予算は無料 |

<a id="guardduty"></a>

## GuardDuty

GuardDuty は、CloudTrail の管理イベント、VPC のフローログ、DNS のログを分析し、ふだんと違う場所からの認証情報の利用、知られた悪いホストへの通信、暗号資産の採掘などを検出します。

- **用意するもの:** 使う側が、アカウントとリージョンごとに 1 回有効にします。ディテクターはアカウントとリージョンごとに 1 つで、組織ですべてのアカウントに有効にすることも多いので、テンプレートでは作りません。
- **手順:** 使うリージョン(インスタンスのリージョンと、CloudFront のスタックの us-east-1)ごとに有効にします。

  ```sh
  aws guardduty create-detector --enable --region <リージョン>
  ```

  要るなら、EventBridge のルールで、検出の結果をアラームのトピックに送ります。
- **費用:** 分析した CloudTrail のイベント 100 万件あたり USD 4.72。VPC のフローログと DNS のログは、分析した量に応じて(GuardDuty の AWS の価格表、2026-10-30)。最初の 30 日は無料です。小さなインスタンスなら、月に USD 1 未満の見込みです。30 日の無料の期間に、GuardDuty の使用量の画面で実際の額がわかります。
- **任意の保護のプラン:** S3 の保護(すべてのバケットのデータイベント)、Lambda の保護(関数の通信)、RDS の保護は別に費用がかかり、この設計には要りません。下の Malware Protection for S3 は別のもので、ディテクターは要りません。

<a id="malware-protection-for-s3"></a>

## Malware Protection for S3

インスタンスのスタックが、添付ファイルのバケットに Amazon GuardDuty Malware Protection のプランを作ります。Redmine は、ファイルを使う前に結果を待ちます。待ち方と利用者に見えるものは、S3 のプラグインの資料にあります([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html#malware-scan))。

プランは、`incoming/`(CloudFront と Lambda を通したアップロード)と `imports/`(CSV のインポートのファイル)の下の新しいオブジェクトをスキャンします。`files/` には、問題がないとわかったオブジェクトのコピーしか置かないので、もう一度スキャンはしません。スキャンすると費用が 2 倍になります。受信したメールも GuardDuty ではスキャンしません。SES が受信したメールをスキャンしてウイルスの判定を付け、`PASS` のメールだけを取得します([mail.md](mail.md))。

プランは、スキャンしたオブジェクトに `GuardDutyMalwareScanStatus` のタグ(`NO_THREATS_FOUND`、`THREATS_FOUND`、`UNSUPPORTED`、`ACCESS_DENIED`、`FAILED`)を付けます。バケットポリシーは、このタグでアクセスを制御します。`incoming/*` と `imports/*` では、プランのロール(`<instance>-malware-scan`)のほかは、タグが `NO_THREATS_FOUND` でなければ `s3:GetObject` と `s3:GetObjectVersion` を拒否します。そこでのタグの書き込みと削除も、そのロールのほかは拒否します。これでタグ付きの `PutObject` も止まるので、スキャンの前にタグを偽れません。条件には、IAM の資料が勧めるとおり、`NotPrincipal` ではなく `aws:PrincipalArn` を使います。

関数は、結果を読むために `incoming/*` と `imports/*` の `s3:GetObjectTagging` を持ち、`REDMINE_S3_MALWARE_SCAN=true` でプラグインが結果を待つようになります。プランのロール `<instance>-malware-scan` は、`malware-protection-plan.guardduty.amazonaws.com` が引き受け、GuardDuty の資料が 1 つのバケットのために挙げる権限を持ちます。GuardDuty が管理する EventBridge のルール(`DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*`)、バケットの通知、オブジェクトを読むことと、タグを付けること、検証のためのオブジェクトです。バケットはイベントを EventBridge に送ります。これはテンプレートで設定するので、スタックを更新しても残ります。

費用は、スキャンした量 1 GB あたり USD 0.1185(月に最初の 1 GB は無料)と、オブジェクト 1 つあたり USD 0.000282(月に最初の 1,000 は無料)です(GuardDuty の AWS の価格表、2026-10-30)。たとえば、月に 3,000 ファイル、6 GB なら、(6 − 1) × 0.1185 + (3,000 − 1,000) × 0.000282 ≈ USD 1.2 です([cost.md](cost.md))。

スキャンを止めるときは、`redmine.json` に `"uploads": {"malwareScan": false}` を書きます([deploy-config.md](deploy-config.md#fields-of-redminejson))。そのときは、プラン、そのロール、バケットポリシーの文を作らず、関数には `REDMINE_S3_MALWARE_SCAN=false` を渡します。

<a id="cloudtrail"></a>

## CloudTrail

証跡は、アカウントの API の呼び出し(管理イベント)を、ログのファイルとして S3 に残します。事故のあとに調べるためです([security.md](security.md))。

- **用意するもの:** アカウントのスタック(`infra/account.yaml`、`bin/deploy --account`)が、証跡 `redmine-trail` を作ります。すべてのリージョン、グローバルなサービスのイベント、ログのファイルの検証を有効にし、バケット `redmine-trail-<account>-<リージョン>`(暗号化、パブリックアクセスのブロック、TLS だけ、この証跡の CloudTrail だけが書ける)に送ります。ログのファイルは、`account.trailDays`(既定は 365)日のあとに消します。
- **2 つ目は作らない:** `bin/deploy --account` は、アカウントに複数のリージョンの証跡(組織の証跡を含む)がないときだけ作ります。`account.cloudTrail`(`true` か `false`)で上書きできます。一度作ったら、残します。
- **費用:** 管理イベントの最初のコピーは無料です。同じイベントの 2 つ目の証跡は、10 万件あたり USD 2.00(1 件 USD 0.00002。CloudTrail の AWS の価格表、2026-11-02)なので、2 つ目は作りません。ログのファイルの S3 の保存は、小さなアカウントなら月に数セントの見込みです。

<a id="iam-access-analyzer"></a>

## IAM Access Analyzer

- **外部のアクセス:** アカウントのアナライザー(`redmine-external-access`)が、ほかのアカウントを許すバケットのポリシーやロールの信頼など、アカウントの外から届くリージョンのリソースを報告します。無料です。リージョンにアカウントか組織のアナライザーがなければ、アカウントのスタックが作ります(`account.accessAnalyzer` で上書きできます)。アナライザーはリージョンごとなので、ほかのリージョンには使う側が足します。
- **使われていないアクセス:** 使われていないアクセスのアナライザー(`redmine-unused-access`)が、90 日使われていないロール、キー、権限を報告します。分析するロールかユーザーごとに月 USD 0.20(IAM Access Analyzer の AWS の価格表、2026-11-08)なので、既定では作りません(`account.unusedAccessAnalyzer`)。

<a id="aws-security-hub"></a>

## AWS Security Hub

Security Hub(CSPM)は、AWS の基礎的なセキュリティのベストプラクティスの基準に照らしてアカウントを確認し、GuardDuty と IAM Access Analyzer の結果を 1 か所に集めます。

- **用意するもの:** 使う側が、任意で有効にします。組織でまとめて管理することも多いです。
- **手順:** 使うリージョンごとに有効にします。

  ```sh
  aws securityhub enable-security-hub --enable-default-standards --region <リージョン>
  ```

  その確認には、AWS Config の記録(下)が要ります。
- **費用:** アカウントとリージョンごとに、月の最初の 100,000 回の確認は 1 回 USD 0.001(Security Hub の AWS の価格表、2026-11-08)。30 日は無料です。確認の回数はリソースの数で変わり、無料の期間にわかります(この設計での額は未確認)。

<a id="aws-config"></a>

## AWS Config

Config は、リソースの構成とその変化を記録します。

- **用意するもの:** 使う側が、任意で有効にします(Security Hub の確認には要ります)。
- **費用:** 記録する構成の項目ごとに USD 0.003、ルールの評価は最初の 100,000 回まで 1 回 USD 0.001(Config の AWS の価格表、2026-11-08)。デプロイのたびに関数が変わるので、デプロイごとにいくつかの項目を記録します。定期の記録にするか、記録するリソースの種類を絞ると、小さく抑えられます(この設計での額は未確認)。

<a id="s3-block-public-access"></a>

## S3 のパブリックアクセスのブロック

テンプレートは、作るどのバケットにも、パブリックアクセスのブロックを有効にします。アカウントで有効にすると、手で作ったバケットも含みます。

- **手順:** アカウントごとに 1 回、実行します。

  ```sh
  aws s3control put-public-access-block --account-id <account> \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  ```

- **費用:** 無料です。

<a id="ebs-default-encryption"></a>

## EBS の既定の暗号化

EBS のボリュームを持つのは、NAT インスタンス(`network.mode` が `nat`)だけです。起動テンプレートが、アカウントの設定にかかわらず、そのボリュームを暗号化します。

- **アカウントの既定(任意):** リージョンごとに有効にします。

  ```sh
  aws ec2 enable-ebs-encryption-by-default --region <リージョン>
  ```

  AWS 管理の鍵 `aws/ebs` を使います。
- **費用:** 無料です。

<a id="the-root-user"></a>

## ルートユーザー

- **手順:** ルートユーザーに MFA を設定し、アクセスキーがあれば消し、ふだんの作業には使いません。組織では、ルートのアクセスをまとめて管理する機能で、メンバーのアカウントのルートの認証情報をなくせます。
- **費用:** 無料です。

<a id="peoples-access"></a>

## 人のアクセス

管理者と運用する人は、IAM Identity Center でサインインします。IAM のユーザーとアクセスキーは作りません。権限のセットと、それぞれができることは [iam.md](iam.md#permissions-of-people) にあります。

<a id="budgets"></a>

## 予算

- **手順:** 月の費用の予算を作り、見込みの費用([cost.md](cost.md))のたとえば 80% と 100% で管理者に通知します。`aws budgets create-budget` に `--notifications-with-subscribers` を付けるか、請求のコンソールで作ります。
- **費用:** アクションのない予算は無料です。アクションのある予算は、最初の 62 予算日まで無料で、そのあとは 1 予算日 USD 0.10(Budgets の AWS の価格表、2026-09-11)。

<a id="to-verify"></a>

## 未確認の事項

- バケットのポリシーの、`aws:PrincipalArn` を使った条件(GuardDuty の資料の `NotPrincipal` の代わり)で、プランのロールが読めてタグを付けられ、ほかのすべてが拒否されるか
- CloudFront の `incoming/` への `PutObject`(オリジンアクセスコントロール)が、タグの文の影響を受けないか
- スタックの同じ更新でプランとバケットのポリシーを作るときに、プランがバケットの検証を通るか
- 1 つのインスタンスでの、GuardDuty の脅威の検出、Security Hub、Config の実際の月の費用
