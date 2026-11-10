# Serverless

Serverless の設計資料です。最新の Redmine を AWS Lambda で動かし、データベースに RDS for PostgreSQL、添付ファイルに S3 を使う設計をまとめます。

<a id="find-by-purpose"></a>

## 目的から探す

| 目的 | 資料 |
| --- | --- |
| 全体構成と、決定事項・未決定事項を知る | [architecture.md](architecture.md) |
| イメージや Lambda の設定を作る | [lambda.md](lambda.md) |
| 添付ファイルの保存と取得を実装する | [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html) |
| データベースと VPC を構築する | [rds.md](rds.md) |
| migration や rake を実行する | [tasks.md](tasks.md) |
| メールを送信・受信する | [mail.md](mail.md) |
| 管理画面を作る | [admin.md](https://redmine-kit.github.io/redmine_serverless/ja/admin.html) |
| 権限を決める | [iam.md](iam.md) |
| セキュリティ対策、WAF、ログの保持、インシデント対応の手順を知る | [security.md](security.md) |
| AWS 側のセキュリティ設定 (GuardDuty、CloudTrail、Access Analyzer など) を行う | [aws-security.md](aws-security.md) |
| 設定を書いてデプロイする、複数のインスタンスを構築する | [deploy-config.md](deploy-config.md) |
| AI 機能と連携する | [ai.md](ai.md) |
| キャッシュの方式を決め、調整する | [cache.md](cache.md) |
| セッションの仕組みを知り、設定する | [session.md](session.md) |
| 月額費用を確認する | [cost.md](cost.md) |
| 一般的なサーバー構成と比較する | [comparison.md](comparison.md) |
| テストを書く、CI を作る | [testing.md](testing.md) |
| Redmine のバージョンアップ | [upgrade.md](upgrade.md) |
| 古い Redmine からデータを移行する | [migration.md](migration.md) |

<a id="pages"></a>

## 資料一覧

| 資料 | 内容 |
| --- | --- |
| [architecture.md](architecture.md) | 全体構成、決定事項とその理由、独自プラグイン、未決定事項 |
| [lambda.md](lambda.md) | Event Functions、コンテナイメージ、Lambda Web Adapter、読み取り専用のファイルシステム、SSM Parameter Store、Rails の設定、SQS でのジョブ、CloudFront とアセット |
| [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html) | S3 プラグインを参考にした設計、バケット構成、CloudFront と署名付き URL によるアップロードとダウンロード、sandbox の CSP、`/tmp` のキャッシュ |
| [rds.md](rds.md) | データベース (RDS for PostgreSQL) と VPC。設定、VPC 外への経路 (VPC エンドポイントか NAT インスタンス)、Systems Manager での接続、費用 |
| [tasks.md](tasks.md) | 同じイメージで 3 つの役割を切り替える仕組み。タスク用の関数での migration、任意の rake、`rails runner`、メールの取り込み |
| [mail.md](mail.md) | Rails の ActionMailer から SES の API で送信するメールと、SES で受信して取り込むメール |
| [admin.md](https://redmine-kit.github.io/redmine_serverless/ja/admin.html) | プラグインが追加する管理画面。共有の「Serverless」メニュー項目の下のタブ (`redmine_serverless` の状態と接続、`redmine_serverless_sqs` のジョブ、`redmine_serverless_ses` のメールの送信と受信、`redmine_serverless_s3` の添付ファイルの S3) |
| [iam.md](iam.md) | 実行ロール、リソースベースのポリシー、デプロイ用ロール、ユーザーの権限 |
| [security.md](security.md) | 保護対象、脅威と対策、エントリーポイントと AWS WAF、Redmine の設定、データ保護、保持期間、ログ、サプライチェーン、残存リスク、インシデント対応 |
| [aws-security.md](aws-security.md) | AWS 側のセキュリティ設定。それぞれの保護対象、設定の担当者、費用、デフォルト (GuardDuty とアップロードのマルウェアスキャン、CloudTrail、IAM Access Analyzer、Security Hub、Config、パブリックアクセスブロック、EBS の暗号化、ルートユーザー、予算) |
| [deploy-config.md](deploy-config.md) | Redmine ごとの設定ファイル (`redmine.json`)、命名規則、共有基盤、デプロイコマンド |
| [ai.md](ai.md) | 別プロジェクトの AI 機能との連携 (Redmine 標準の REST API、OAuth、webhook) と安全上の規則 |
| [cache.md](cache.md) | Redmine がキャッシュするもの、実行環境別のキャッシュ、調整できる箇所、共有キャッシュ (ElastiCache for Valkey) の費用 |
| [session.md](session.md) | 暗号化した Cookie に保存し、データベースのトークンで検証するセッション、セッションの設定、`Secure` 属性 |
| [cost.md](cost.md) | ap-northeast-1 での月額費用の見積もり |
| [comparison.md](comparison.md) | 一般的なサーバー構成 (EC2、Lightsail、ECS Fargate) との、料金、セキュリティ、運用の比較 |
| [testing.md](testing.md) | テストの種類、プラグインと本体のテスト、イメージテスト、デプロイ後の確認、CI での実行順序 |
| [upgrade.md](upgrade.md) | Redmine のバージョンアップの確認方法 (追加された migration の分類、試験用データベースでの実行、記録) |
| [migration.md](migration.md) | 古い Redmine (ほかの環境で動いているもの) からの移行。MySQL からの移行方法 |
| [sources.md](sources.md) | 参照した情報と確認日 |

<a id="sponsors"></a>

## スポンサー

<Sponsors><a href="https://www.keyselect.co.jp/">KEY SELECT</a> <a href="https://localstack.cloud">LocalStack</a></Sponsors>

<a id="license"></a>

## ライセンス

Serverless は、GNU General Public License バージョン 2 またはそれ以降のバージョンで公開しています。[LICENSE](../../LICENSE) を参照してください。Redmine の非公式のプロジェクトです。
