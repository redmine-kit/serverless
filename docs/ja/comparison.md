# ふつうのサーバーとの比較

この設計(Lambda とマネージドサービス)と、ふつうのサーバーで Redmine を動かす形を、料金、セキュリティ、運用で比べます。

この資料の単価は、AWS の価格表(Price List API)の東京のファイルから取りました(EC2 は 2026-11-07、ECS は 2026-10-19、ELB は 2026-11-05、Lightsail は 2026-09-15 公開)。月額は 730 時間で計算しています。利用は 10 人ほどの前提です。出典は [sources.md](sources.md) にあります。

<a id="setups-compared"></a>

## 比べる形

| 形 | 中身 |
| --- | --- |
| この設計 | VPC の中の Lambda、RDS for PostgreSQL(db.t4g.micro)、VPC のエンドポイントか NAT インスタンス、S3、SQS、SES([architecture.md](architecture.md)) |
| EC2 1 台 | t4g.small(2 GB)1 台に、Redmine と PostgreSQL を同じサーバーで動かす。添付ファイルはサーバーのディスク |
| EC2 と RDS | t4g.small 1 台の Redmine と、RDS for PostgreSQL(db.t4g.micro) |
| Lightsail 1 台 | Lightsail の 2 GB のインスタンス 1 台に、Redmine と PostgreSQL |
| ECS Fargate | Fargate(0.5 vCPU、1 GB、Arm)の Redmine、ALB、RDS for PostgreSQL(db.t4g.micro) |

<a id="prices-monthly-estimates"></a>

## 料金(月額の見込み)

| 形 | 内訳 | 月額 |
| --- | --- | --- |
| この設計 | RDS 約 21.0 ドル、VPC の外への道(NAT インスタンス約 8.4 ドルか、エンドポイント 3 つで約 30.7 ドル)、そのほか(Lambda、S3、ECR、ログ、Route 53 など)約 2.4 ドル([cost.md](cost.md)) | 約 31.8〜54.1 ドル |
| EC2 1 台 | t4g.small 15.8 ドル(1 時間 0.0216 ドル)、gp3 30 GB 2.9 ドル(1 GB あたり月 0.096 ドル)、パブリック IPv4 3.7 ドル | 約 22.3 ドル |
| EC2 と RDS | EC2 1 台の分(約 22.3 ドル)と RDS 約 21.0 ドル | 約 43.3 ドル |
| Lightsail 1 台 | 2 GB のインスタンス 11.8 ドル(1 時間 0.01612 ドル。パブリック IPv4 を含む) | 約 11.8 ドル |
| ECS Fargate | Fargate 18.0 ドル(vCPU 1 時間 0.04045 ドル、メモリ 1 GB 1 時間 0.00442 ドル)、ALB 17.7 ドル(1 時間 0.0243 ドル)と LCU、ALB のパブリック IPv4 2 つで 7.3 ドル、RDS 約 21.0 ドル、タスクの外への経路(パブリック IPv4 か NAT) | 約 69 ドル以上 |

- **含めていないもの:** バックアップ(EBS のスナップショット、Lightsail のスナップショット)、CloudFront、SES の送信の料金。どの形でも少額です。
- **Lightsail の枠:** Lightsail のインスタンスの料金には、ディスクとデータの転送の枠が含まれます。枠の大きさは、Lightsail の料金のページで確認します。
- **読み方:** Lambda は使った分だけですが、データベースと VPC の外への道は決まった費用です。この設計は、1 台のサーバーに全部を載せる形(Lightsail、EC2 1 台)より高くなります。NAT インスタンスなら EC2 と RDS より安く、エンドポイントなら同じくらいか高くなります([cost.md](cost.md))。

<a id="security"></a>

## セキュリティ

| 項目 | この設計(Lambda) | EC2 1 台、Lightsail 1 台 | EC2 と RDS | ECS Fargate |
| --- | --- | --- | --- | --- |
| OS の更新 | Lambda の実行環境は AWS が更新する。イメージの中の OS(Amazon Linux 2023)と gem は、イメージを作り直して当てる | サーバーの OS を自分で更新する | 同左(データベースの更新は RDS) | Fargate の基盤は AWS。イメージは作り直して当てる |
| 外からの入口 | CloudFront だけ(関数 URL は、CloudFront の OAC の署名がないと呼べない)。RDS は外から届かない。開いているポートも、ログインできるサーバーもない | Web のポート(443)。SSH を開けるか、Systems Manager を使う | 同左 | ALB だけ |
| 侵入されたとき | 実行環境は読み取り専用で、短い時間で入れ替わるので、ファイルを書き換えて居座ることができない | ディスクに書き換えが残り、居座られるおそれがある | 同左 | タスクは入れ替わるが、書き込める場所は設定しだい |
| 権限の分け方 | 関数ごとに実行ロールを分ける(画面、ジョブ、タスク)([iam.md](iam.md)) | サーバー 1 つのロールに、全部の権限が集まる | 同左 | タスクごとにロールを分けられる |
| データベース | VPC のプライベートのサブネットの RDS。SSM Parameter Store に置いたパスワードで、サーバーの証明書を確認する TLS でつなぐ([rds.md](rds.md#settings)) | 同じサーバーの中。サーバーが侵入されると、データベースも読まれる | VPC の中の RDS。パスワードで接続 | VPC の中の RDS。パスワードで接続 |
| 添付ファイル | S3。バージョニングで消しても戻せる。ダウンロードは 5 分の署名付き URL | サーバーのディスク。バックアップを自分で取る | 同左 | 共有の置き場所(EFS か S3)が要る |
| 秘密の値 | SSM Parameter Store。Lambda の環境変数にも置かない | サーバーの設定ファイル | 同左 | タスクの定義から SSM か Secrets Manager |
| 止まりにくさ | Lambda は複数の AZ で動く。RDS は Single-AZ で、止まったらバックアップから戻す([rds.md](rds.md#settings)) | サーバー 1 台が止まると、すべて止まる | Redmine のサーバーが 1 台 | タスクを複数の AZ に置ける |

- **入口:** 関数 URL は IAM の認証にし、CloudFront の OAC が署名した要求だけを受けます。直接の要求は、関数が呼ばれる前に断られます([lambda.md](lambda.md#cloudfront-and-function-urls))。
- **イメージの更新:** Lambda のコンテナイメージは、AWS が自動では更新しません。土台のイメージ、Redmine、gem の更新のたびに、イメージを作り直してデプロイします。

<a id="operations"></a>

## 運用

| 項目 | この設計(Lambda) | ふつうのサーバー |
| --- | --- | --- |
| サーバーの面倒 | Redmine のサーバーはない。RDS は、保守の時間帯にデータベースの更新を当てる。NAT インスタンスの形では、NAT インスタンス 1 台を Systems Manager で更新する([rds.md](rds.md#managing-it-with-systems-manager)) | OS、ミドルウェア、ディスク、バックアップを自分で見る |
| 起動待ち | 使われていない時間のあとの最初の画面で、起動を待つ([lambda.md](lambda.md#waiting-for-start-up)) | ない |
| 負荷が増えたとき | Lambda が環境を増やす。RDS はインスタンスの種類を変えて大きくする | サーバーの大きさを見直す |
| Redmine の更新 | イメージを作り直し、タスクの関数で migration を実行する([tasks.md](tasks.md)) | サーバーで Redmine を入れ替え、migration を実行する |
| 自前のコード | 自前のプラグイン(Lambda での実行、S3 の添付ファイル、SES でのメール)を、Redmine の更新に合わせて保つ([upgrade.md](upgrade.md)) | 要らない(Redmine の標準のまま動く) |

<a id="which-to-choose"></a>

## どれを選ぶか

| 重く見ること | 向いている形 |
| --- | --- |
| Redmine のコードを標準のまま動かし、月の費用を決まった額にする。1 台が止まることと、自分での更新を受け入れる | Lightsail 1 台 |
| Redmine のサーバーの面倒をなくし、侵入されにくくする。決まった費用を抑える | この設計の NAT インスタンスの形 |
| 上に加えて、外への通信をなくす | この設計の VPC のエンドポイントの形 |
| Redmine を標準のまま動かし、データベースだけはマネージドにする | EC2 と RDS |

<a id="to-verify"></a>

## 確認すること

- Lightsail の 2 GB のインスタンスのディスクと転送の枠
- ALB の LCU の、この規模での実際の使用量
