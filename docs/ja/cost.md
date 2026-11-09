# 費用の見込み

東京リージョンでの月の費用の見込みです。単価は AWS の価格表(Price List API)の東京のファイルから取りました。使用量は、10 人ほどが業務時間に使う前提で置いた数字で、まだ測っていません。データベースは、VPC の中の RDS for PostgreSQL です([rds.md](rds.md))。

<a id="monthly-estimate"></a>

## 月の見込み

| 項目 | 単価 | 置いた使用量 | 月額 |
| --- | --- | --- | --- |
| RDS for PostgreSQL(db.t4g.micro、Single-AZ、gp3 20 GB) | 1 時間 0.025 ドル、1 GB あたり月 0.138 ドル | 月のあいだ動かし続ける | 21.01 ドル |
| SQS | 100 万件あたり 0.40 ドル(標準のキュー) | 10 万件 | 約 0.04 ドル |
| Lambda(arm、`redmine-web`) | 1 GB 秒あたり 0.0000133334 ドル、100 万件あたり 0.20 ドル | 5 万件 × 0.3 秒 × 2 GB、温めの呼び出し 3,200 件 | 約 0.5 ドル |
| S3(Standard、添付ファイルとアセット) | 1 GB あたり月 0.025 ドル | 10 GB(古いバージョンを含む) | 0.25 ドル |
| S3 の要求 | PUT など 1,000 件あたり 0.0047 ドル、GET など 1 万件あたり 0.0037 ドル | PUT など 1 万件、GET など 10 万件 | 約 0.1 ドル |
| ECR | 1 GB あたり月 0.10 ドル | 3 GB(イメージ 3 つ分) | 0.30 ドル |
| CloudWatch Logs | 取り込み 1 GB あたり 0.76 ドル、保存 1 GB あたり月 0.033 ドル | 0.5 GB | 約 0.4 ドル |
| CloudFront | 定額プラン Free か、常時無料の枠の中の見込み | — | 0 ドル |
| Lambda@Edge(`redmine-body-hash`) | 100 万件あたり 0.60 ドル、1 GB 秒あたり 0.00005001 ドル。無料の枠はない | 5 万件 × 10 ミリ秒 × 128 MB | 約 0.04 ドル |
| SES の送信 | 宛先 1 件あたり 0.0001 ドル | 1,000 通 | 0.10 ドル |
| SES の受信 | 1 通あたり 0.0001 ドル、チャンクあたり 0.00009 ドル | 1,000 通 | 約 0.19 ドル |
| Route 53 | ホストゾーン 1 つで月 0.50 ドル。CloudFront を向く別名のレコードへの問い合わせは無料、ほかは 100 万件あたり 0.40 ドル | Redmine のサブドメインを委任するときだけ。委任しないなら 0 ドル | 約 0.5 ドル |
| GuardDuty Malware Protection for S3(アップロードとインポート。[aws-security.md](aws-security.md#malware-protection-for-s3)) | スキャンした量 1 GB あたり 0.1185 ドル(月に最初の 1 GB は無料)、オブジェクト 1 つあたり 0.000282 ドル(月に最初の 1,000 は無料) | 3,000 ファイル、6 GB | 約 1.2 ドル |
| 小計 | | | 約 24.6 ドル |

小計に、VPC から AWS のサービスに届く経路の費用が加わります([rds.md](rds.md#routes-out-of-the-vpc))。

| 形 | 経路 | 月の合計 |
| --- | --- | --- |
| 形 2: NAT インスタンス | t4g.nano 1 台、パブリック IPv4、ディスクで約 8.4 ドル | 約 33.0 ドル |
| 形 1: VPC のエンドポイント | SES、SSM、SQS のインターフェイスエンドポイント(1 AZ)で約 30.7 ドル | 約 55.3 ドル |

- **ほとんどが決まった費用:** RDS と VPC から外への経路は、Redmine を使っても使わなくても時間で課金され、合計の大半を占めます。ほかの項目は、使った分だけです。
- **CloudFront:** 定額プラン Free を使えば、月 100 万リクエストと 100 GB まで 0 ドルです。使わない場合も、常時無料の枠(月 1 TB の転送と 1,000 万件の要求)に収まる見込みです。常時無料の枠の内容は、作るときに確認します。
- **入れていないもの:** CloudWatch のアラーム(デッドレターキュー、送信の失敗、受信の失敗など。1 つ月 0.10 ドルほど)、`redmine-worker` と `redmine-task` の実行の時間、SSM Parameter Store の要求と、SecureString を復号する KMS の要求は入れていません。NAT インスタンスのディスクの単価は、価格表で確認していません([rds.md](rds.md#cost))。どれも少額の見込みです。
- **VPC の中の Lambda:** 関数を VPC に入れること自体には、費用がかからない前提です(価格表では未確認)。
- **SQS の待ち受け:** `redmine-worker` のイベントソースマッピングは、キューを常に待ち受けて(ロングポーリング)要求を出します。SQS は毎月 100 万件の要求が無料なので、この規模なら合計は変わらない見込みです(未確認)。

<a id="what-adds-cost"></a>

## 足すと増えるもの

| 項目 | 月額 | 足すとき |
| --- | --- | --- |
| Provisioned Concurrency(2 GB を 1 つ) | 約 23 ドル | 起動待ちをなくしたいとき |
| CloudFront の定額プラン Pro | 15 ドル(ログの保存と検索は別料金) | CloudFront と WAF のログを残したいとき([security.md](security.md#plan-and-cost)) |
| 使う側が有効にする AWS のセキュリティのサービス(GuardDuty の脅威の検出、Security Hub、Config、使われていないアクセスの分析) | それぞれ 1 ドル未満から。ページを参照 | アカウントごと([aws-security.md](aws-security.md)) |
| 管理画面の費用(`costExplorer.enabled`) | 毎日の更新で約 1 ドル(Cost Explorer の API は要求 1 回 0.01 ドル。1 日 3 件か 4 件)。データが 1 時間より古いときにタブを開くと、1 時間に最大 1 回の更新(3 件か 4 件)が増え、営業日の毎時間開いても約 7 ドルまで(見込み) | アカウントの費用を Redmine で見たいとき。プラグイン `redmine_serverless_costexplorer` を足したイメージ(派生のイメージ)で([deploy-config.md](deploy-config.md#fields-of-redminejson)) |
| 共有のキャッシュ(ElastiCache Serverless for Valkey) | 約 7.4 ドル(`cache.t4g.micro` のノード 1 台なら 14.60 ドル) | 整形済みのテキストと検索の結果を、環境をまたいで使い回したいとき([cache.md](cache.md#when-a-shared-cache-is-worth-it)) |

データベースと経路に足すもの(Multi-AZ、NAT Gateway、RDS Proxy など)は、[rds.md](rds.md#cost) にあります。

<a id="sources-of-the-prices"></a>

## 単価の出典

| 価格表 | 公開日 |
| --- | --- |
| AmazonRDS | 2026-10-29 |
| AWSLambda | 2026-10-30 |
| AmazonS3 | 2026-11-04 |
| AmazonCloudWatch | 2026-11-04 |
| AmazonECR | 2026-09-11 |
| AmazonVPC | 2026-11-05 |
| AmazonSES | 2026-11-04 |
| AWSQueueService(SQS) | 2026-09-11 |
| AmazonRoute53 | 2026-11-04 |
| AmazonGuardDuty | 2026-10-30 |
| AWSCostExplorer(グローバル) | 2026-09-11 |

URL の形は `https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/<サービス>/current/ap-northeast-1/index.json` です(2026-11-08 に取得)。AmazonRDS と AmazonVPC は、[rds.md](rds.md#cost) の費用にも使っています。
