# 費用の見積もり

ap-northeast-1 での月額費用の見積もりです。単価は AWS の料金表 (Price List API) の ap-northeast-1 の料金表ファイルから取得しました。使用量は、10 人ほどが業務時間に使う前提で置いた数字で、まだ計測していません。データベースは、VPC 内の RDS for PostgreSQL です ([rds.md](rds.md))。

<a id="monthly-estimate"></a>

## 月額の見積もり

| 項目 | 単価 | 想定の使用量 | 月額 |
| --- | --- | --- | --- |
| RDS for PostgreSQL (db.t4g.micro、Single-AZ、gp3 20 GB) | 1 時間 0.025 ドル、1 GB あたり月 0.138 ドル | 1 か月間稼働し続ける | 21.01 ドル |
| SQS | 100 万リクエストあたり 0.40 ドル (標準キュー) | 10 万リクエスト | 約 0.04 ドル |
| Lambda (arm、`redmine-web`) | 1 GB 秒あたり 0.0000133334 ドル、100 万リクエストあたり 0.20 ドル | 5 万リクエスト × 0.3 秒 × 2 GB、ウォームアップの呼び出し 3,200 回 | 約 0.5 ドル |
| S3 (Standard、添付ファイルとアセット) | 1 GB あたり月 0.025 ドル | 10 GB (古いバージョンを含む) | 0.25 ドル |
| S3 リクエスト | PUT など 1,000 リクエストあたり 0.0047 ドル、GET など 1 万リクエストあたり 0.0037 ドル | PUT など 1 万リクエスト、GET など 10 万リクエスト | 約 0.1 ドル |
| ECR | 1 GB あたり月 0.10 ドル | 3 GB (イメージ 3 つ分) | 0.30 ドル |
| CloudWatch Logs | 取り込み 1 GB あたり 0.76 ドル、保存 1 GB あたり月 0.033 ドル | 0.5 GB | 約 0.4 ドル |
| CloudFront | 定額料金プランの無料プランか、常時無料枠に収まる見込み | — | 0 ドル |
| Lambda@Edge (`redmine-body-hash`) | 100 万リクエストあたり 0.60 ドル、1 GB 秒あたり 0.00005001 ドル。無料枠はない | 6 万リクエスト (画面と、`/tmp/*` のサムネイル、zip、アップロード) × 10 ミリ秒 × 128 MB | 約 0.04 ドル |
| SES の送信 | 宛先 1 件あたり 0.0001 ドル | 1,000 通 | 0.10 ドル |
| SES の受信 | 1 通あたり 0.0001 ドル、1 チャンクあたり 0.00009 ドル | 1,000 通 | 約 0.19 ドル |
| Route 53 | ホストゾーン 1 つで月 0.50 ドル。CloudFront を指すエイリアスレコードへのクエリは無料、ほかは 100 万クエリあたり 0.40 ドル | Redmine のサブドメインを委任するときだけ。委任しないなら 0 ドル | 約 0.5 ドル |
| GuardDuty Malware Protection for S3 (アップロードとインポート。[aws-security.md](aws-security.md#malware-protection-for-s3)) | スキャンしたデータ 1 GB あたり 0.1185 ドル (毎月最初の 1 GB は無料)、オブジェクト 1 つあたり 0.000282 ドル (毎月最初の 1,000 は無料) | 3,000 ファイル、6 GB | 約 1.2 ドル |
| 小計 | | | 約 24.6 ドル |

小計に、VPC から AWS サービスへの経路の費用が加わります ([rds.md](rds.md#routes-out-of-the-vpc))。

| 構成 | 経路 | 月額の合計 |
| --- | --- | --- |
| 構成 2: NAT インスタンス | t4g.nano 1 台、パブリック IPv4、ディスクで約 8.4 ドル | 約 33.0 ドル |
| 構成 1: VPC エンドポイント | SES、SSM、SQS のインターフェイスエンドポイント (1 AZ) で約 30.7 ドル | 約 55.3 ドル |

合計の大半は固定費です。RDS と VPC 外への経路は、Redmine を使っても使わなくても、時間で課金されます。ほかの項目は、使った分だけです。

CloudFront は、定額料金プランの無料プランを使えば、月 100 万リクエストと 100 GB まで 0 ドルです。プランを使わない場合も、常時無料枠 (月 1 TB のデータ転送と 1,000 万リクエスト) に収まる見込みです。常時無料枠の内容は、構築するときに確認します。

いくつかの少額の項目は含めていません。CloudWatch アラーム (デッドレターキュー、送信の失敗、受信の失敗など。1 つあたり月 0.10 ドルほど)、`redmine-worker` と `redmine-task` の実行時間、SSM Parameter Store のリクエストと、SecureString を復号する KMS のリクエストです。NAT インスタンスのディスクの単価は、料金表で確認していません ([rds.md](rds.md#cost))。どれも少額の見込みです。

次の 2 つは、料金表ではまだ確認していない前提です。関数を VPC に接続すること自体には、費用がかからない前提にしています。また、`redmine-worker` のイベントソースマッピングはキューを常にポーリングして (ロングポーリング) リクエストを送りますが、SQS は毎月 100 万リクエストが無料なので、この規模なら合計は変わらない見込みです。

<a id="what-adds-cost"></a>

## 追加の費用

| 項目 | 月額 | 追加する場合 |
| --- | --- | --- |
| Provisioned Concurrency (2 GB の環境 1 つ) | 約 23 ドル | 起動待ちをなくしたいとき |
| CloudFront の定額料金プランのプロプラン | 15 ドル (ログの保存と検索は別料金) | CloudFront と WAF のログを保持したいとき ([security.md](security.md#plan-and-cost)) |
| 利用者が有効にする AWS のセキュリティサービス (GuardDuty の脅威検出、Security Hub、Config、未使用のアクセスの分析) | それぞれ 1 ドル未満から。ページを参照 | アカウントごと ([aws-security.md](aws-security.md)) |
| 管理画面の費用表示 (`costExplorer.enabled`) | 約 0.9〜1.2 ドル (Cost Explorer API は 1 リクエスト 0.01 ドル。プラグインの取得は 1 日 1 回の更新だけで、1 日 3 リクエスト、タグ別の内訳ありで 4 リクエスト) | アカウントの費用を Redmine で見たいとき。プラグイン `redmine_serverless_costexplorer` を追加したイメージ (派生イメージ) で ([deploy-config.md](deploy-config.md#fields-of-redminejson)) |
| 共有キャッシュ (ElastiCache Serverless for Valkey) | 約 7.4 ドル (`cache.t4g.micro` のノード 1 台なら 14.60 ドル) | 整形済みのテキストと検索結果を、環境をまたいで再利用したいとき ([cache.md](cache.md#when-a-shared-cache-is-worth-it)) |

データベースと経路に追加するもの (Multi-AZ、NAT Gateway、RDS Proxy など) は、[rds.md](rds.md#cost) にあります。

<a id="sources-of-the-prices"></a>

## 単価の出典

| 料金表 | 公開日 |
| --- | --- |
| AmazonRDS | 2026-10-29 |
| AWSLambda | 2026-10-30 |
| AmazonS3 | 2026-11-04 |
| AmazonCloudWatch | 2026-11-04 |
| AmazonECR | 2026-09-11 |
| AmazonVPC | 2026-11-05 |
| AmazonSES | 2026-11-04 |
| AWSQueueService (SQS) | 2026-09-11 |
| AmazonRoute53 | 2026-11-04 |
| AmazonGuardDuty | 2026-10-30 |
| AWSCostExplorer (グローバル) | 2026-09-11 |

URL の形式は `https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/<サービス>/current/ap-northeast-1/index.json` です (2026-11-08 に取得)。AmazonRDS と AmazonVPC は、[rds.md](rds.md#cost) の費用にも使っています。
