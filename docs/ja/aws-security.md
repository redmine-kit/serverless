# AWS のセキュリティ設定

AWS 側のセキュリティ設定をまとめます。それぞれについて、保護対象、このプロジェクトのテンプレートが作成するのか、導入者がアカウントごとに 1 回有効にするのか、費用、デフォルトで有効かを書きます。脅威と Redmine 内の対策は [security.md](security.md) に、ロールと権限は [iam.md](iam.md) にあります。

価格は ap-northeast-1 のもので、AWS の料金表から取得しました (料金表の日付を添えます)。アカウントの利用状況で変わる見込みには「見込み」と、料金表で確認していないものには「未確認」と書きます。

<a id="overview"></a>

## 一覧

| 設定 | 保護対象 | 設定する主体 | デフォルト | 月額費用 |
| --- | --- | --- | --- | --- |
| [GuardDuty の脅威検出](#guardduty) | 不審な API 呼び出し、通信、使用中の認証情報を検出する | 導入者。アカウントとリージョンごとに 1 回 | 有効にすることを推奨 (テンプレートでは作成しない) | 見込み: 小規模なアカウントで USD 1 未満 |
| [GuardDuty Malware Protection for S3](#malware-protection-for-s3) | ユーザーがアップロードやインポートで送信したファイルを、Redmine が読む前にスキャンする | インスタンスのスタック | 有効 (`uploads.malwareScan`) | 3,000 ファイル、6 GB で約 USD 1.2 |
| [CloudTrail](#cloudtrail) | アカウントの API 呼び出しの記録。調査に備えて保持する | アカウントのスタック (`bin/deploy --account`)。アカウントに証跡があれば作成しない | 証跡がない場合に有効 | 管理イベントの最初のコピーは無料。S3 の保存料金 |
| [IAM Access Analyzer](#iam-access-analyzer) | アカウント外に公開されたリソースと、未使用のアクセスを検出する | アカウントのスタック。リージョンにアナライザーがあれば作成しない | 外部アクセス: 有効。未使用のアクセス: 無効 | 外部アクセス: 無料。未使用のアクセス: ロールかユーザーごとに USD 0.20 |
| [AWS Security Hub](#aws-security-hub) | AWS 基礎セキュリティのベストプラクティスに照らして、アカウントをチェックする | 導入者 (任意) | 無効 | チェック 1 回あたり USD 0.001 (最初の 100,000 回) |
| [AWS Config](#aws-config) | リソースの設定履歴。Security Hub のチェックに必要 | 導入者 (任意) | 無効 | 記録する設定項目ごとに USD 0.003 |
| [S3 パブリックアクセスブロック (アカウント)](#s3-block-public-access) | アカウント内のどのバケットも公開できなくする | 導入者。アカウントごとに 1 回 | 有効にすることを推奨 | 無料 |
| [EBS のデフォルト暗号化](#ebs-default-encryption) | ボリュームを暗号化する (ボリュームを持つのは NAT インスタンスだけ) | NAT インスタンスのボリュームはテンプレートが暗号化する。アカウントのデフォルトは導入者 | NAT のボリューム: 有効 | 無料 |
| [ルートユーザー](#the-root-user) | アカウントで最も強い権限を持つ認証情報 | 導入者 | — | 無料 |
| [管理者と運用担当者のアクセス](#peoples-access) | 管理者と運用担当者のサインイン | 導入者 (IAM Identity Center) | — | 無料 |
| [予算](#budgets) | 費用が上限を超えたときの通知 | 導入者 | 有効にすることを推奨 | アクションのない予算は無料 |

<a id="guardduty"></a>

## GuardDuty

GuardDuty は、CloudTrail の管理イベント、VPC フローログ、DNS ログを分析し、通常と異なる場所からの認証情報の使用、既知の悪意のあるホストへの通信、暗号資産のマイニングなどを検出します。

- **設定する主体:** 導入者が、アカウントとリージョンごとに 1 回有効にします。ディテクターはアカウントとリージョンごとに 1 つで、組織ですべてのアカウントに対して有効にすることも多いので、テンプレートでは作成しません。
- **手順:** 使用するリージョン (インスタンスのリージョンと、CloudFront のスタックの us-east-1) ごとに有効にします。

  ```sh
  aws guardduty create-detector --enable --region <リージョン>
  ```

  必要に応じて、EventBridge ルールで、検出結果をアラームのトピックに送信します。
- **費用:** 分析した CloudTrail イベント 100 万件あたり USD 4.72。VPC フローログと DNS ログは、分析した量に応じて課金されます (GuardDuty の AWS の料金表、2026-10-30)。最初の 30 日間は無料です。小規模なインスタンスなら、月額 USD 1 未満の見込みです。30 日間の無料期間中に、GuardDuty の使用状況の画面で実際の金額を確認できます。
- **オプションの保護プラン:** S3 Protection (すべてのバケットのデータイベント)、Lambda Protection (関数の通信)、RDS Protection は別途費用がかかり、この設計には不要です。下の Malware Protection for S3 は別の機能で、ディテクターは不要です。

<a id="malware-protection-for-s3"></a>

## Malware Protection for S3

インスタンスのスタックが、添付ファイル用バケットに Amazon GuardDuty Malware Protection のプランを作成します。Redmine は、ファイルを使う前にスキャン結果を待ちます。待ち方とユーザーに表示される内容は、S3 プラグインの資料にあります ([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html#malware-scan))。

プランは、`tmp/incoming/` (CloudFront と Lambda を経由したアップロード) と `imports/` (CSV インポートのファイル) の下の新しいオブジェクトをスキャンします。`files/` には、問題がないと判定されたオブジェクトのコピーしか置かないので、再スキャンはしません。再スキャンすると費用が 2 倍になります。受信したメールも GuardDuty ではスキャンしません。SES が受信したメールをスキャンしてウイルスの判定結果を付け、判定が `PASS` のメールだけを取り込みます ([mail.md](mail.md))。

プランは、スキャンしたオブジェクトに `GuardDutyMalwareScanStatus` タグ (`NO_THREATS_FOUND`、`THREATS_FOUND`、`UNSUPPORTED`、`ACCESS_DENIED`、`FAILED`) を付けます。バケットポリシーは、このタグでアクセスを制御します。`tmp/incoming/*` と `imports/*` では、プランのロール (`<instance>-malware-scan`) 以外は、タグが `NO_THREATS_FOUND` でなければ `s3:GetObject` と `s3:GetObjectVersion` を拒否します。そこでのタグの書き込みと削除も、そのロール以外は拒否します。これでタグ付きの `PutObject` も拒否されるので、スキャン前にタグを偽装できません。条件には、IAM のドキュメントの推奨どおり、`NotPrincipal` ではなく `aws:PrincipalArn` を使います。

関数は、スキャン結果を読むために `tmp/incoming/*` と `imports/*` の `s3:GetObjectTagging` 権限を持ち、`REDMINE_S3_MALWARE_SCAN=true` でプラグインがスキャン結果を待つようになります。プランのロール `<instance>-malware-scan` は、`malware-protection-plan.guardduty.amazonaws.com` が引き受け、GuardDuty のドキュメントが 1 つのバケットのために挙げる権限を持ちます。GuardDuty が管理する EventBridge ルール (`DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*`)、バケットの通知、オブジェクトの読み取りとタグ付け、検証用のオブジェクトです。バケットはイベントを EventBridge に送信します。これはテンプレートで設定するので、スタックを更新しても維持されます。

費用は、スキャンした量 1 GB あたり USD 0.1185 (毎月最初の 1 GB は無料) と、オブジェクト 1 つあたり USD 0.000282 (毎月最初の 1,000 は無料) です (GuardDuty の AWS の料金表、2026-10-30)。たとえば、月に 3,000 ファイル、6 GB なら、(6 − 1) × 0.1185 + (3,000 − 1,000) × 0.000282 ≈ USD 1.2 です ([cost.md](cost.md))。

スキャンを無効にするときは、`redmine.json` に `"uploads": {"malwareScan": false}` を指定します ([deploy-config.md](deploy-config.md#fields-of-redminejson))。その場合は、プラン、そのロール、バケットポリシーのステートメントを作成せず、関数には `REDMINE_S3_MALWARE_SCAN=false` を渡します。

<a id="cloudtrail"></a>

## CloudTrail

証跡は、アカウントの API 呼び出し (管理イベント) を、ログファイルとして S3 に保存します。インシデントの発生後に調査するためです ([security.md](security.md))。

- **設定する主体:** アカウントのスタック (`infra/account.yaml`、`bin/deploy --account`) が、証跡 `redmine-trail` を作成します。すべてのリージョン、グローバルサービスイベント、ログファイルの検証を有効にし、バケット `redmine-trail-<account>-<リージョン>` (暗号化、パブリックアクセスブロック、TLS のみ、この証跡の CloudTrail だけが書き込める) に送信します。ログファイルは、`account.trailDays` (既定は 365) 日後に削除します。
- **2 つ目は作成しない:** `bin/deploy --account` は、アカウントにマルチリージョンの証跡 (組織の証跡を含む) がない場合だけ作成します。`account.cloudTrail` (`true` か `false`) で上書きできます。一度作成したら、そのまま維持します。
- **費用:** 管理イベントの最初のコピーは無料です。同じイベントの 2 つ目の証跡は、10 万件あたり USD 2.00 (1 件 USD 0.00002。CloudTrail の AWS の料金表、2026-11-02) なので、2 つ目は作成しません。ログファイルの S3 の保存料金は、小規模なアカウントなら月に数セントの見込みです。

<a id="iam-access-analyzer"></a>

## IAM Access Analyzer

- **外部アクセス:** アカウントのアナライザー (`redmine-external-access`) が、ほかのアカウントを許可するバケットポリシーやロールの信頼ポリシーなど、アカウント外からアクセスできるリージョンのリソースを報告します。無料です。リージョンにアカウントか組織のアナライザーがなければ、アカウントのスタックが作成します (`account.accessAnalyzer` で上書きできます)。アナライザーはリージョンごとなので、ほかのリージョンには導入者が追加します。
- **未使用のアクセス:** 未使用のアクセスのアナライザー (`redmine-unused-access`) が、90 日間使われていないロール、キー、権限を報告します。分析するロールかユーザーごとに月額 USD 0.20 (IAM Access Analyzer の AWS の料金表、2026-11-08) なので、デフォルトでは作成しません (`account.unusedAccessAnalyzer`)。

<a id="aws-security-hub"></a>

## AWS Security Hub

Security Hub (CSPM) は、AWS 基礎セキュリティのベストプラクティスの標準に照らしてアカウントをチェックし、GuardDuty と IAM Access Analyzer の結果を 1 か所に集約します。

- **設定する主体:** 導入者が、任意で有効にします。組織で一元管理することも多いです。
- **手順:** 使用するリージョンごとに有効にします。

  ```sh
  aws securityhub enable-security-hub --enable-default-standards --region <リージョン>
  ```

  そのチェックには、AWS Config の記録 (下記) が必要です。
- **費用:** アカウントとリージョンごとに、毎月最初の 100,000 回のチェックは 1 回 USD 0.001 (Security Hub の AWS の料金表、2026-11-08)。30 日間は無料です。チェックの回数はリソースの数で変わり、無料期間中にわかります (この設計での金額は未確認)。

<a id="aws-config"></a>

## AWS Config

Config は、リソースの設定とその変更を記録します。

- **設定する主体:** 導入者が、任意で有効にします (Security Hub のチェックには必要です)。
- **費用:** 記録する設定項目ごとに USD 0.003、ルールの評価は最初の 100,000 回まで 1 回 USD 0.001 (Config の AWS の料金表、2026-11-08)。デプロイのたびに関数が変わるので、デプロイごとにいくつかの設定項目を記録します。定期的な記録にするか、記録するリソースタイプを絞り込むと、費用を小さく抑えられます (この設計での金額は未確認)。

<a id="s3-block-public-access"></a>

## S3 パブリックアクセスブロック

テンプレートは、作成するすべてのバケットで、パブリックアクセスブロックを有効にします。アカウントで有効にすると、手動で作成したバケットにも適用されます。

- **手順:** アカウントごとに 1 回、実行します。

  ```sh
  aws s3control put-public-access-block --account-id <account> \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  ```

- **費用:** 無料です。

<a id="ebs-default-encryption"></a>

## EBS のデフォルト暗号化

EBS ボリュームを持つのは、NAT インスタンス (`network.mode` が `nat`) だけです。起動テンプレートが、アカウントの設定にかかわらず、そのボリュームを暗号化します。

- **アカウントのデフォルト (任意):** リージョンごとに有効にします。

  ```sh
  aws ec2 enable-ebs-encryption-by-default --region <リージョン>
  ```

  AWS マネージドキー `aws/ebs` を使います。
- **費用:** 無料です。

<a id="the-root-user"></a>

## ルートユーザー

- **手順:** ルートユーザーに MFA を設定し、アクセスキーがあれば削除し、日常の作業には使いません。組織では、ルートアクセスの一元管理の機能で、メンバーアカウントのルートユーザーの認証情報を削除できます。
- **費用:** 無料です。

<a id="peoples-access"></a>

## 管理者と運用担当者のアクセス

管理者と運用担当者は、IAM Identity Center でサインインします。IAM ユーザーとアクセスキーは作成しません。許可セットと、それぞれの権限の内容は [iam.md](iam.md#permissions-of-people) にあります。

<a id="budgets"></a>

## 予算

- **手順:** 月額費用の予算を作成し、費用の見積もり ([cost.md](cost.md)) のたとえば 80% と 100% で管理者に通知します。`aws budgets create-budget` に `--notifications-with-subscribers` を指定するか、請求コンソールで作成します。
- **費用:** アクションのない予算は無料です。アクションのある予算は、最初の 62 予算日まで無料で、その後は 1 予算日 USD 0.10 (Budgets の AWS の料金表、2026-09-11)。

<a id="to-verify"></a>

## 未確認の事項

- バケットポリシーの、`aws:PrincipalArn` を使った条件 (GuardDuty のドキュメントの `NotPrincipal` の代わり) で、プランのロールが読み取りとタグ付けができ、それ以外のすべてが拒否されるか
- CloudFront の `tmp/incoming/` への `PutObject` (オリジンアクセスコントロール) が、タグのステートメントの影響を受けないか
- スタックの同じ更新でプランとバケットポリシーを作成するときに、プランがバケットの検証に合格するか
- 1 つのインスタンスでの、GuardDuty の脅威検出、Security Hub、Config の実際の月額費用
