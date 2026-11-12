# 一般的なサーバー構成との比較

この設計 (Lambda とマネージドサービス) と、一般的なサーバーで Redmine を動かす構成を、料金、セキュリティ、運用で比較します。

この資料の単価は、AWS の料金表 (Price List API) の ap-northeast-1 の料金表ファイルから取得しました (EC2 は 2026-11-07、ECS は 2026-10-19、ELB は 2026-11-05、Lightsail は 2026-09-15 公開)。月額は 730 時間で計算しています。ユーザーは 10 人ほどの前提です。出典は [sources.md](sources.md) にあります。

<a id="setups-compared"></a>

## 比較する構成

| 構成 | 内容 |
| --- | --- |
| この設計 | VPC 内の Lambda、RDS for PostgreSQL (db.t4g.micro)、VPC エンドポイントか NAT インスタンス、S3、SQS、SES ([architecture.md](architecture.md)) |
| EC2 1 台 | t4g.small (2 GB) 1 台に、Redmine と PostgreSQL を同居させる。添付ファイルはサーバーのディスク |
| EC2 と RDS | t4g.small 1 台の Redmine と、RDS for PostgreSQL (db.t4g.micro) |
| Lightsail 1 台 | Lightsail の 2 GB のインスタンス 1 台に、Redmine と PostgreSQL |
| ECS Fargate | Fargate (0.5 vCPU、1 GB、Arm) の Redmine、ALB、RDS for PostgreSQL (db.t4g.micro) |

<a id="prices-monthly-estimates"></a>

## 月額費用

| 構成 | 内訳 | 月額 |
| --- | --- | --- |
| この設計 | RDS 約 21.0 ドル、VPC 外への経路 (NAT インスタンス約 8.4 ドルか、エンドポイント 3 つで約 30.7 ドル)、そのほか (Lambda、S3、ECR、ログ、Route 53、アップロードのマルウェアスキャンなど) 約 3.6 ドル ([cost.md](cost.md)) | 約 33.0〜55.3 ドル |
| EC2 1 台 | t4g.small 15.8 ドル (1 時間 0.0216 ドル)、gp3 30 GB 2.9 ドル (1 GB あたり月 0.096 ドル)、パブリック IPv4 3.7 ドル | 約 22.3 ドル |
| EC2 と RDS | EC2 1 台の分 (約 22.3 ドル) と RDS 約 21.0 ドル | 約 43.3 ドル |
| Lightsail 1 台 | 2 GB のインスタンス 11.8 ドル (1 時間 0.01612 ドル。パブリック IPv4 を含む) | 約 11.8 ドル |
| ECS Fargate | Fargate 18.0 ドル (vCPU 1 時間 0.04045 ドル、メモリ 1 GB 1 時間 0.00442 ドル)、ALB 17.7 ドル (1 時間 0.0243 ドル) と LCU、ALB のパブリック IPv4 2 つで 7.3 ドル、RDS 約 21.0 ドル、タスクの外部への経路 (パブリック IPv4 か NAT) | 約 69 ドル以上 |

Lambda は使った分だけですが、データベースと VPC 外への経路は固定費です。そのため、この設計は、1 台のサーバーにすべてを載せる構成 (Lightsail、EC2 1 台) より高くなります。NAT インスタンスなら EC2 と RDS より安く、エンドポイントなら同程度か高くなります ([cost.md](cost.md))。

バックアップ (EBS スナップショット、Lightsail のスナップショット) と、CloudFront と SES の送信の料金は含めていません。どの構成でも少額です。Lightsail のインスタンスの料金にはディスクとデータ転送の枠が含まれ、その大きさは Lightsail の料金ページで確認します。

<a id="security"></a>

## セキュリティ

| 項目 | この設計 (Lambda) | EC2 1 台、Lightsail 1 台 | EC2 と RDS | ECS Fargate |
| --- | --- | --- | --- | --- |
| OS の更新 | Lambda の実行環境は AWS が更新する。イメージ内の OS (Amazon Linux 2023) と gem は、イメージを再ビルドして適用する | サーバーの OS を自分で更新する | 同左 (データベースの更新は RDS) | Fargate の基盤は AWS。イメージは再ビルドして適用する |
| エントリーポイント | CloudFront だけ (関数 URL は、CloudFront の OAC 署名がないと呼び出せない)。RDS には外部からアクセスできない。開いているポートも、ログインできるサーバーもない | Web のポート (443)。SSH を開けるか、Systems Manager を使う | 同左 | ALB だけ |
| 侵入された場合 | 実行環境は読み取り専用で、短時間で入れ替わるので、ファイルを書き換えて居座ることができない | ディスクへの書き換えが残り、居座られるおそれがある | 同左 | タスクは入れ替わるが、書き込める場所は設定しだい |
| 権限の分離 | 関数ごとに実行ロールを分ける (画面、ジョブ、タスク) ([iam.md](iam.md)) | サーバー 1 つのロールに、すべての権限が集まる | 同左 | タスクごとにロールを分けられる |
| データベース | VPC のプライベートサブネットの RDS。SSM Parameter Store に置いたパスワードで、サーバー証明書を検証する TLS で接続する ([rds.md](rds.md#settings)) | 同じサーバー内。サーバーに侵入されると、データベースも読まれる | VPC 内の RDS。パスワードで接続 | VPC 内の RDS。パスワードで接続 |
| 添付ファイル | S3。バージョニングで、削除しても復元できる。ダウンロードは有効期限 5 分の CloudFront 署名付き URL | サーバーのディスク。バックアップを自分で取る | 同左 | 共有ストレージ (EFS か S3) が必要 |
| シークレット | SSM Parameter Store。Lambda の環境変数にも置かない | サーバーの設定ファイル | 同左 | タスク定義から SSM か Secrets Manager |
| 可用性 | Lambda は複数の AZ で動く。RDS は Single-AZ で、停止したらバックアップから復元する ([rds.md](rds.md#settings)) | サーバー 1 台が停止すると、すべて停止する | Redmine のサーバーが 1 台 | タスクを複数の AZ に配置できる |

関数 URL は IAM 認証にし、CloudFront の OAC が署名したリクエストだけを受け付けるので、直接のリクエストは関数が呼び出される前に拒否されます ([lambda.md](lambda.md#cloudfront-and-function-urls))。Lambda のコンテナイメージは、AWS が自動では更新しません。ベースイメージ、Redmine、gem の更新のたびに、イメージを再ビルドしてデプロイします。

<a id="operations"></a>

## 運用

| 項目 | この設計 (Lambda) | 一般的なサーバー |
| --- | --- | --- |
| サーバー管理 | Redmine のサーバーはない。RDS は、メンテナンスウィンドウにデータベースの更新を適用する。NAT インスタンス構成では、NAT インスタンス 1 台を Systems Manager で更新する ([rds.md](rds.md#managing-it-with-systems-manager)) | OS、ミドルウェア、ディスク、バックアップを自分で管理する |
| 起動待ち | 使われていない時間のあとの最初の画面で、起動を待つ ([lambda.md](lambda.md#waiting-for-start-up)) | ない |
| 負荷が増えた場合 | Lambda が環境を増やす。RDS はインスタンスクラスを変えてスケールアップする | サーバーのサイズを見直す |
| Redmine の更新 | イメージを再ビルドし、タスク用の関数で migration を実行する ([tasks.md](tasks.md)) | サーバーで Redmine を入れ替え、migration を実行する |
| 独自のコード | 独自のプラグイン (共通の AWS メニューと AWS クライアント、Lambda での実行、S3 の添付ファイル、SES でのメール、SQS でのジョブ、SSM の設定、派生イメージでは Cost Explorer) を、Redmine の更新に合わせてメンテナンスする ([upgrade.md](upgrade.md)) | 不要 (Redmine の標準のまま動く) |

<a id="which-to-choose"></a>

## 構成の選び方

| 重視すること | 向いている構成 |
| --- | --- |
| Redmine のコードを標準のまま動かし、月額費用を固定にする。1 台が停止することと、自分での更新を受け入れる | Lightsail 1 台 |
| Redmine のサーバー管理をなくし、侵入されにくくする。固定費を抑える | この設計の NAT インスタンス構成 |
| 上に加えて、外部への通信をなくす | この設計の VPC エンドポイント構成 |
| Redmine を標準のまま動かし、データベースだけはマネージドにする | EC2 と RDS |

<a id="to-verify"></a>

## 未確認の事項

- Lightsail の 2 GB のインスタンスのディスクと転送の枠
- ALB の LCU の、この規模での実際の使用量
