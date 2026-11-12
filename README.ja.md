# Serverless

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/serverless/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/serverless/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/serverless?label=Coverage)](https://codecov.io/gh/redmine-kit/serverless)
[![License](https://img.shields.io/github/license/redmine-kit/serverless?label=License)](LICENSE)
[![Tested with LocalStack](https://img.shields.io/badge/Tested%20with-LocalStack-39227A?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9Ii0wLjM4IC0wLjAwIDg4Ljg4IDg4Ljg4Ij48cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTc2LjI5ODMgNjEuODcyN0M3Ny4zMDA2IDYxLjg3MjcgNzcuODAyNSA2My4wODQ1IDc3LjA5MzggNjMuNzkzMkw1Mi43MTYzIDg4LjE2ODhDNTIuMDA3NiA4OC44Nzc1IDUwLjc5NTcgODguMzc1NiA1MC43OTU3IDg3LjM3MzRMNTAuNzk1NyA2Mi45OTc3QzUwLjc5NTcgNjIuMzc2NCA1MS4yOTk0IDYxLjg3MjcgNTEuOTIwOCA2MS44NzI3TDc2LjI5ODMgNjEuODcyN1pNMS4xMjczMiAzOC45MDM2QzAuMTI1MDIgMzguOTAzNiAtMC4zNzY5MzMgMzcuNjkxOCAwLjMzMTgwNyAzNi45ODMyTDI0LjcwOTMgMTIuNjA3NUMyNS40MTggMTEuODk4OCAyNi42Mjk4IDEyLjQwMDcgMjYuNjI5OCAxMy40MDI5TDI2LjYyOTggMzcuNzc4NkMyNi42Mjk4IDM4LjM5OTkgMjYuMTI2MSAzOC45MDM2IDI1LjUwNDggMzguOTAzNkwxLjEyNzMyIDM4LjkwMzZaIiBmaWxsPSJ1cmwoI3BhaW50MF9saW5lYXJfMjBfMykiLz48cGF0aCBkPSJNNTQuMTkzNCAzNC45MDI5TDg2Ljg0ODkgMzQuOTAyOUM4Ny40NzAyIDM0LjkwMjkgODcuOTczOSAzNC4zOTkzIDg3Ljk3MzkgMzMuNzc4TDg3Ljk3MzkgMS4xMjQ4OEM4Ny45NzM5IDAuNTAzNTgyIDg3LjQ3MDIgLTguMDE1MjdlLTA1IDg2Ljg0ODkgLTguMDIwN2UtMDVMNTQuMTkzNCAtOC4zMDYxOGUtMDVDNTMuNTcyMSAtOC4zMTE2MmUtMDUgNTMuMDY4NCAwLjUwMzU3OSA1My4wNjg0IDEuMTI0ODdMNTMuMDY4NCAzMy43NzhDNTMuMDY4NCAzNC4zOTkzIDUzLjU3MjEgMzQuOTAyOSA1NC4xOTM0IDM0LjkwMjlaIiBmaWxsPSJ1cmwoI3BhaW50MV9saW5lYXJfMjBfMykiLz48cGF0aCBkPSJNNzguMzgxOCA1Ni4yNDhMMzMuMzgwMSA1Ni4yNDhDMzIuNzU4OCA1Ni4yNDggMzIuMjU1MSA1NS43NDQzIDMyLjI1NTEgNTUuMTIzTDMyLjI1NTEgMTAuMTI0NkMzMi4yNTUxIDkuNTAzMzMgMzIuNzU4OCA4Ljk5OTY3IDMzLjM4MDEgOC45OTk2N0w0Ni4zMTgxIDguOTk5NjdDNDYuOTM5NCA4Ljk5OTY3IDQ3LjQ0MzEgOS41MDMzMyA0Ny40NDMxIDEwLjEyNDZMNDcuNDQzMSAzOS4zNzM2QzQ3LjQ0MzEgMzkuOTk0OSA0Ny45NDY4IDQwLjQ5ODYgNDguNTY4MiA0MC40OTg2TDc4LjM4MTggNDAuNDk4NkM3OS4wMDMxIDQwLjQ5ODYgNzkuNTA2OCA0MS4wMDIyIDc5LjUwNjggNDEuNjIzNUw3OS41MDY4IDU1LjEyM0M3OS41MDY4IDU1Ljc0NDMgNzkuMDAzMSA1Ni4yNDggNzguMzgxOCA1Ni4yNDhaIiBmaWxsPSJ1cmwoI3BhaW50Ml9saW5lYXJfMjBfMykiLz48ZGVmcz4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDBfbGluZWFyXzIwXzMiIHgxPSI3Ny41MDM1IiB5MT0iMTIuMDQ0NCIgeDI9IjEzLjk1MTYiIHkyPSI3NC45NjgiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj4KPHN0b3Agc3RvcC1jb2xvcj0iIzREMjlCNCIvPgo8c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiM4MzZGRkYiLz4KPC9saW5lYXJHcmFkaWVudD4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDFfbGluZWFyXzIwXzMiIHgxPSI1MC4wMTA3IiB5MT0iMzYuNjU3IiB4Mj0iOTMuOTk2NCIgeTI9Ii02LjU0ODg3IiBncmFkaWVudFVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+CjxzdG9wIHN0b3AtY29sb3I9IiM3MEZGRTUiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjNjI5NUUxIi8+CjwvbGluZWFyR3JhZGllbnQ+CjxsaW5lYXJHcmFkaWVudCBpZD0icGFpbnQyX2xpbmVhcl8yMF8zIiB4MT0iNzMuODM3NyIgeTE9IjE5LjM3NTkiIHgyPSIzMi40NzA1IiB5Mj0iNTguNjU0NCIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBvZmZzZXQ9IjAuMDA3NDc1MTEiIHN0b3AtY29sb3I9IiM2NTRGRUMiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjNzFCMkZGIi8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz48L3N2Zz4=)](https://localstack.cloud)

最新の Redmine (7.0.3) を、データベースに RDS for PostgreSQL、添付ファイルとアセットに S3 を使って、AWS Lambda (Event Functions) で動かす設計です。サードパーティーのプラグインはインストールせず、テーマは標準のままにします。Lambda と AWS のための拡張機能は、独自プラグインです。[`redmine_aws`](https://github.com/redmine-kit/redmine_aws) (各プラグインが共通で使う)、[`redmine_aws_lambda`](https://github.com/redmine-kit/redmine_aws_lambda) (Lambda での実行)、[`redmine_aws_s3`](https://github.com/redmine-kit/redmine_aws_s3) (S3 の添付ファイル)、[`redmine_aws_ses`](https://github.com/redmine-kit/redmine_aws_ses) (SES でのメール)、[`redmine_aws_sqs`](https://github.com/redmine-kit/redmine_aws_sqs) (SQS でのジョブ)、[`redmine_aws_ssm`](https://github.com/redmine-kit/redmine_aws_ssm) (SSM Parameter Store の設定とシークレット) に分けます。

[English](README.md)

> **状態:** 開発の初期です。イメージ、インフラのテンプレート、デプロイコマンドを作り、LocalStack でテストしています。AWS ではまだ動かしていません。

<a id="documentation"></a>

## ドキュメント

- Web サイト: https://redmine-kit.github.io/serverless/ja/ (English: https://redmine-kit.github.io/serverless/)
- Markdown: [docs/ja/README.md](docs/ja/README.md) (English: [docs/README.md](docs/README.md))

まず [docs/ja/architecture.md](docs/ja/architecture.md) を読んでください。プラグインの設計は、[Redmine AWS](https://redmine-kit.github.io/redmine_aws/ja/)、[Redmine AWS Lambda](https://redmine-kit.github.io/redmine_aws_lambda/ja/)、[Redmine AWS S3](https://redmine-kit.github.io/redmine_aws_s3/ja/)、[Redmine AWS SES](https://redmine-kit.github.io/redmine_aws_ses/ja/)、[Redmine AWS SQS](https://redmine-kit.github.io/redmine_aws_sqs/ja/)、[Redmine AWS SSM](https://redmine-kit.github.io/redmine_aws_ssm/ja/) にあります。

<a id="key-points-of-the-design"></a>

## 構成の要点

- **実行環境:** Lambda の Ruby ベースイメージ (Ruby 4.0、Amazon Linux 2023) に、Redmine と Lambda Web Adapter をインストールしたコンテナイメージ (arm64) を、Event Functions で実行します。Web、ジョブ、タスクの 3 つの関数は同じイメージで、環境変数で役割を切り替えます。
- **エントリーポイント:** CloudFront から関数 URL に転送します。関数 URL は IAM 認証にし、CloudFront の OAC が署名したリクエストだけを受け付けます。POST などのリクエスト本文のハッシュは、Lambda@Edge が追加します。アセット (`/assets/*`) は、CloudFront が S3 から返します。
- **データベース:** VPC 内の RDS for PostgreSQL を使います。Lambda 関数は VPC のプライベートサブネットで動作し、AWS サービスには VPC エンドポイントか NAT インスタンス経由で接続します ([docs/rds.md](docs/ja/rds.md))。
- **添付ファイル:** S3 に保存します。アップロードでは、ブラウザーが CloudFront 署名付き URL を使い、CloudFront 経由で S3 に送信します。ダウンロードは CloudFront 署名付き URL にリダイレクトします。Redmine の S3 プラグインの方式を参考に、独自プラグイン `redmine_aws_s3` として実装します。
- **ジョブ:** ActiveJob のジョブは、SQS (`aws-activejob-sqs`) に送り、ジョブ用の関数で実行します。
- **メール:** 送信では、ジョブ用の関数が Rails の ActionMailer から SES の API (`aws-actionmailer-ses`) で送信します。受信では、SES で受信して S3 に保存し、タスク用の関数が Redmine に取り込みます。
- **設定とシークレット:** SSM Parameter Store に保存し、Redmine が起動時に読み込みます。
- **migration と rake:** タスク用の関数で、ローカルのコマンド (`bin/rake`) から実行します。
- **テスト:** 置き換えた処理ごとのテスト、Redmine 本体のテスト、イメージテスト、Lambda の結合テスト (LocalStack)、デプロイ後の確認を、CI で順に実行します ([docs/testing.md](docs/ja/testing.md))。

<a id="sponsors"></a>

## スポンサー

<a href="https://www.keyselect.co.jp/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/keyselect-logo-dark.svg">
    <img alt="KEY SELECT" src=".github/assets/keyselect-logo.svg" width="136" height="29">
  </picture>
</a>
&emsp;&emsp;
<a href="https://localstack.cloud">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/localstack-logo-dark.svg">
    <img alt="LocalStack" src=".github/assets/localstack-logo.svg" width="98" height="23">
  </picture>
</a>

<a id="license"></a>

## ライセンス

Serverless は、GNU General Public License バージョン 2 またはそれ以降のバージョンで公開しています。[LICENSE](LICENSE) を参照してください。Redmine の非公式のプロジェクトです。
