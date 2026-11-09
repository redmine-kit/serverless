# Serverless

Serverless の設計の資料です。最新の Redmine を AWS Lambda で動かし、データベースに RDS for PostgreSQL、添付ファイルに S3 を使う設計をまとめます。

<a id="find-by-purpose"></a>

## 目的から探す

| 目的 | 読む資料 |
| --- | --- |
| 全体の構成と、決めたこと・まだ決めていないことを知る | [architecture.md](architecture.md) |
| イメージや Lambda の設定を作る | [lambda.md](lambda.md) |
| 添付ファイルの保存と取得を作る | [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html) |
| データベースと VPC を作る | [rds.md](rds.md) |
| migration や rake を実行する | [tasks.md](tasks.md) |
| メールを送る、受ける | [mail.md](mail.md) |
| 管理画面を作る | [admin.md](https://redmine-kit.github.io/redmine_serverless/ja/admin.html) |
| 権限を決める | [iam.md](iam.md) |
| セキュリティの守り、WAF、ログの保持、事故のときの手順を知る | [security.md](security.md) |
| 設定を書いてデプロイする、いくつも立てる | [deploy-config.md](deploy-config.md) |
| AI の機能をつなぐ | [ai.md](ai.md) |
| 月の費用を見る | [cost.md](cost.md) |
| ふつうのサーバーと比べる | [comparison.md](comparison.md) |
| テストを書く、CI を作る | [testing.md](testing.md) |
| Redmine のバージョンを上げる | [upgrade.md](upgrade.md) |
| 古い Redmine からデータを移す | [migration.md](migration.md) |

<a id="pages"></a>

## 資料

| 資料 | 内容 |
| --- | --- |
| [architecture.md](architecture.md) | 全体の構成、決めたことと理由、自前のプラグイン、まだ決めていないこと |
| [lambda.md](lambda.md) | Event Functions、コンテナイメージ、Lambda Web Adapter、読み取り専用のファイルシステム、SSM Parameter Store、Rails の設定、SQS でのジョブ、CloudFront とアセット |
| [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html) | S3 のプラグインを参考にした設計、バケットの構成、S3 への直接のアップロード、署名付き URL でのダウンロード、`/tmp` のキャッシュ |
| [rds.md](rds.md) | データベース(RDS for PostgreSQL)と VPC。設定、VPC の外への道(VPC のエンドポイントか NAT インスタンス)、Systems Manager での接続、費用 |
| [tasks.md](tasks.md) | 同じイメージで 3 つの役割を切り替える仕組み。タスク用の関数での migration、任意の rake、`rails runner`、メールの取り込み |
| [mail.md](mail.md) | Rails の ActionMailer から SES の API で送るメールと、SES で受けて取り込むメール |
| [admin.md](https://redmine-kit.github.io/redmine_serverless/ja/admin.html) | プラグインが足す管理画面(`redmine_serverless` の状態と接続とジョブ、`redmine_serverless_ses` のメールの送信と受信、`redmine_serverless_s3` の添付ファイルの S3) |
| [iam.md](iam.md) | 実行ロール、リソースベースのポリシー、デプロイ用のロール、人の権限 |
| [security.md](security.md) | 守るもの、起きうることと守り、入口と AWS WAF、Redmine の設定、データの守り、保持の期間、ログ、供給網、残るリスク、事故のとき |
| [deploy-config.md](deploy-config.md) | 1 つの Redmine ごとの設定のファイル(`redmine.json`)、名前の決まり、共有の土台、デプロイのコマンド |
| [ai.md](ai.md) | 別のプロジェクトの AI の機能との連携(Redmine の標準の REST API、OAuth、webhook)と安全の決まり |
| [cost.md](cost.md) | 東京リージョンでの月の費用の見込み |
| [comparison.md](comparison.md) | ふつうのサーバー(EC2、Lightsail、ECS Fargate)との、料金、セキュリティ、運用の比較 |
| [testing.md](testing.md) | テストの種類、プラグインと本体のテスト、イメージのテスト、デプロイしたあとの確認、CI の順番 |
| [upgrade.md](upgrade.md) | Redmine を上げるときの確認の方法(増えた migration の読み分け、試験用のデータベースでの実行、記録) |
| [migration.md](migration.md) | 古い Redmine(ほかの環境で動いているもの)からの移行。MySQL からの移し方 |
| [sources.md](sources.md) | 参照した情報と確認日 |
