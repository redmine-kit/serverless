# Serverless

最新の Redmine(7.0.3)を、データベースに RDS for PostgreSQL、添付ファイルとアセットに S3 を使って、AWS Lambda(Event Functions)で動かす設計です。外部のプラグインは入れず、テーマは標準のままにします。Lambda と AWS のための拡張は、自前のプラグインです。[`redmine_serverless`](https://github.com/redmine-kit/redmine_serverless)(Lambda での実行)、[`redmine_serverless_s3`](https://github.com/redmine-kit/redmine_serverless_s3)(S3 の添付ファイル)、[`redmine_serverless_ses`](https://github.com/redmine-kit/redmine_serverless_ses)(SES でのメール)に分けます。

[English](README.md)

> **状態:** 開発の初期です。イメージとそのテストを作りました。ほかは設計段階です。

<a id="documentation"></a>

## ドキュメント

- Web サイト: https://redmine-kit.github.io/serverless/ja/ (English: https://redmine-kit.github.io/serverless/)
- Markdown: [docs/ja/README.md](docs/ja/README.md) (English: [docs/README.md](docs/README.md))

まず [docs/ja/architecture.md](docs/ja/architecture.md) を読んでください。プラグインの設計は、[Redmine Serverless](https://redmine-kit.github.io/redmine_serverless/ja/)、[Redmine Serverless S3](https://redmine-kit.github.io/redmine_serverless_s3/ja/)、[Redmine Serverless SES](https://redmine-kit.github.io/redmine_serverless_ses/ja/) にあります。

<a id="key-points-of-the-design"></a>

## 構成の要点

- **実行環境:** Lambda の Ruby のベースイメージ(Ruby 4.0、Amazon Linux 2023)に、Redmine と Lambda Web Adapter を入れたコンテナイメージ(arm64)を、Event Functions で動かします。画面、ジョブ、タスクの 3 つの関数は同じイメージで、環境変数で役割を切り替えます。
- **入口:** CloudFront から関数 URL に転送します。関数 URL は IAM の認証にし、CloudFront の OAC が署名した要求だけを受けます。POST などの本文のハッシュは、Lambda@Edge が入れます。アセット(`/assets/*`)は、CloudFront が S3 から返します。
- **データベース:** VPC の中の RDS for PostgreSQL を使います。Lambda の関数は VPC のプライベートのサブネットで動き、AWS のサービスには VPC のエンドポイントか NAT インスタンスを通ってつなぎます([docs/rds.md](docs/ja/rds.md))。
- **添付ファイル:** S3 に置きます。アップロードはブラウザーから S3 に直接送り、ダウンロードは S3 の署名付き URL にリダイレクトします。Redmine の S3 のプラグインのやり方を参考に、自前のプラグイン `redmine_serverless_s3` で作ります。
- **ジョブ:** ActiveJob のジョブは、SQS(`aws-activejob-sqs`)に積み、ジョブ用の関数で実行します。
- **メール:** 送信は、ジョブ用の関数が Rails の ActionMailer から SES の API(`aws-actionmailer-ses`)で送ります。受信は、SES で受けて S3 に置き、タスクの関数が Redmine に取り込みます。
- **設定と秘密の値:** SSM Parameter Store に置き、Redmine が起動のときに読みます。
- **migration と rake:** タスク用の関数で、手元のコマンド(`bin/rake`)から実行します。
- **テスト:** 差し替えた処理ごとのテスト、Redmine 本体のテスト、イメージのテスト、Lambda の結合のテスト(LocalStack)、デプロイしたあとの確認を、CI で順に実行します([docs/testing.md](docs/ja/testing.md))。

<a id="license"></a>

## ライセンス

Serverless は、GNU General Public License バージョン 2 またはそれ以降のバージョンで公開しています。[LICENSE](LICENSE) を参照してください。Redmine projectとは関係ありません。
