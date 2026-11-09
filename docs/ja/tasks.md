# マイグレーション、rake、メールの取り込み

Redmine の migration、rake のタスク、受信したメールの取り込みを、タスク用の Lambda(`redmine-task`)で実行する設計です。`redmine-task` は `redmine-web` と同じイメージを使い、Puma は起動せずに、rake を実行します。

この資料の仕様は、2026-11-08 時点の公式の情報と、Redmine 7.0.3 と Rails 8.1.4 のソースで確認したものです。出典は [sources.md](sources.md) にあります。

<a id="usage-planned"></a>

## 使い方(予定)

```sh
# migration(Redmine 本体とプラグイン)
bin/rake db:migrate
bin/rake redmine:plugins:migrate

# 初めのデータ(日本語)
bin/rake redmine:load_default_data REDMINE_LANG=ja

# 任意の rake のタスク
bin/rake redmine:attachments:prune
bin/rake -T

# 受信したメールを取り込み直す(S3 に残っているメールの ID)
bin/rake redmine_serverless_ses:receive_mail MESSAGE_ID=<メッセージ ID>

# rails runner(1 行のコード)
bin/rails runner 'puts User.count'
```

`bin/rake` と `bin/rails` は、このリポジトリに置くスクリプトです。AWS CLI で `redmine-task` を同期で呼び、出力と終了コードを表示します。AWS は SSO の管理者のロールで操作します。

- **いつもデプロイした Redmine に向けて動く:** このリポジトリの `bin/rake` と `bin/rails` は、手元の Redmine では動きません。手元で使うのはテストだけで、テストは `bin/test` で実行します([testing.md](testing.md))。
- **`bin/rails` は `runner` だけ:** `bin/rails` が受け付けるのは `runner` だけです。
- **環境変数:** rake の標準の書き方(`REDMINE_LANG=ja`)で渡します。渡せるのは、決めた名前(`REDMINE_LANG`、`MESSAGE_ID` など)だけです。
- **送り先を見せる:** 実行の前に、送り先(AWS のアカウント、リージョン、関数の名前)を表示します。データを変えるタスク(`db:migrate`、`runner` など)は、確認してから送ります。

<a id="how-one-image-runs-everything"></a>

## 同じイメージで動かす仕組み

`redmine-task` は `redmine-web` と同じイメージを使います。関数の環境変数 `REDMINE_ROLE` で、起動するものを切り替えます。`redmine-task` では Puma を起動しません。

| | `redmine-web`(`REDMINE_ROLE=web`) | `redmine-worker`(`REDMINE_ROLE=worker`) | `redmine-task`(`REDMINE_ROLE=task`) |
| --- | --- | --- | --- |
| 役目 | 画面と API | ActiveJob のジョブ([lambda.md](lambda.md#background-jobs)) | rake、`rails runner`、メールの取り込み |
| 拡張機能(`/opt/extensions/lambda-adapter`) | Lambda Web Adapter を起動する | 何もしない拡張機能として登録し、待つだけ | 同左 |
| 入口(`/var/task/bin/start`) | Puma を起動する | `/lambda-entrypoint.sh` で、`aws-activejob-sqs` のハンドラーを動かす(Rails を読み込む) | `/lambda-entrypoint.sh` で、自前のハンドラー(`handler.TaskHandler.process`)を動かす(Rails を読み込まない) |
| Lambda とのやり取り | Lambda Web Adapter | 土台のイメージのランタイムインターフェイスクライアント | 同左 |
| 呼ぶもの | CloudFront(関数 URL)、EventBridge Scheduler(業務時間の温め。使うときだけ) | SQS(イベントソースマッピング) | 手元のコマンド、デプロイ、SES、EventBridge Scheduler |
| タイムアウト | 60 秒 | 900 秒 | 900 秒 |
| 同時実行数の予約 | 10 | 3 | 2 |
| 関数 URL | あり | なし | なし |

```mermaid
sequenceDiagram
  participant C as 呼び出し元
  participant H as ハンドラー<br>(Ruby)
  participant P as 子プロセス<br>(rake)
  C->>H: Invoke(JSON)
  H->>H: イベントの種類を見分ける
  H->>P: bundle exec rake …
  P-->>H: 終了コード、出力
  H-->>C: 終了コード、出力の末尾
```

`redmine-worker` と `redmine-task` は、動かし方が違うので関数を分けます。`redmine-worker` は、ジョブを速く動かすために Rails を読み込んだまま使います。`redmine-task` は、rake ごとに新しい子プロセスで動かし、前のタスクの状態を残しません。そのハンドラーは Rails を読み込まず、受け取った内容を確認して子プロセスを起動するだけで、Rails の処理は子プロセスの rake の中で行います。メールの取得も、プラグイン `redmine_serverless_ses` の rake のタスクです([mail.md](mail.md#receiving))。

Lambda は、`/opt/extensions` にあるファイルをすべて拡張機能として起動します。Lambda Web Adapter は、拡張機能として登録したうえで Lambda とのやり取り(Runtime API)も自分で行うので、`redmine-task` でも起動するとハンドラーとぶつかります。そこで、`/opt/extensions/lambda-adapter` を小さなシェルのスクリプトにし、本物の Lambda Web Adapter は `/opt/lambda-web-adapter/` に置きます。スクリプトは、`REDMINE_ROLE=web` のときだけ本物を起動します。

`redmine-task` では、スクリプトは代わりに、受けるイベントのない拡張機能として登録し(`{"events": []}`)、次のイベントを待ち続けます。Lambda Web Adapter 自身も同じ形で登録しています(`src/lib.rs` の `register_extension_internal`)。拡張機能が失敗すると Lambda が環境を作り直すので、登録せずに終わらせてはいけません。登録の名前はファイルの名前と同じにし(`Lambda-Extension-Name: lambda-adapter`)、土台のイメージにある `curl` で書きます。

<a id="kinds-of-events"></a>

## イベントの種類

| 呼び出し元 | イベント | 処理 |
| --- | --- | --- |
| `bin/rake`、デプロイ | `{"command": "rake", "args": ["redmine:load_default_data"], "env": {"REDMINE_LANG": "ja"}}` | rake を実行する |
| `bin/rails` | `{"command": "runner", "args": ["puts User.count"]}` | `rails runner` を実行する |
| `bin/rake` | `{"command": "rake", "args": ["redmine_serverless_ses:receive_mail"], "env": {"MESSAGE_ID": "<メッセージ ID>"}}` | S3 のメールを取り込む([mail.md](mail.md#receiving)) |
| SES の受信のルール | SES のイベント(`Records[0].ses`) | 同上。イベントから、メッセージ ID(`mail.messageId` → `MESSAGE_ID`)、宛先(`receipt.recipients` → `SES_RECIPIENTS`。カンマ区切り)、判定(`receipt.spamVerdict.status`、`virusVerdict`、`dmarcVerdict`、`spfVerdict`、`dkimVerdict` → `SES_SPAM_VERDICT`、`SES_VIRUS_VERDICT`、`SES_DMARC_VERDICT`、`SES_SPF_VERDICT`、`SES_DKIM_VERDICT`。`receipt.dmarcPolicy` → `SES_DMARC_POLICY`)を取る。形の正しくない値は入れない。コマンドのイベントでは、これらの変数を渡せない([mail.md](mail.md#spoofing-and-spam)) |
| EventBridge Scheduler | `{"command": "rake", "args": ["redmine:attachments:prune"]}` | 定期のタスク(下記) |

- **`command`:** `rake` と `runner` だけを受け付けます。SES のイベントは、形で見分けます。
- **`env`:** 決めた名前(`REDMINE_LANG` など)だけを受け付け、`REDMINE_DB_HOST` やデータベースのユーザーの名前などの設定を上書きさせません。
- **実行:** rake と `rails runner` は、`bundle exec` で子プロセスとして実行します。タスクごとに新しいプロセスで動くので、前のタスクの状態が残りません。子プロセスも Rails の環境を読み込むときに、SSM Parameter Store から設定を読みます([lambda.md](lambda.md#settings-and-secrets-ssm-parameter-store))。ハンドラーは、ランタイムの `RUBYLIB`、`GEM_HOME`、`GEM_PATH` を子プロセスの環境から外し、子プロセスが Redmine の bundle だけを使うようにします(2026-11-09 にランタイムインターフェイスエミュレーターで確認)。
- **出力:** 標準出力と標準エラーは、そのまま CloudWatch Logs に入ります。応答には、終了コードと、出力の末尾(256 KB まで、文字の区切りで切る)を入れます。同期の呼び出しの応答は 6 MB までなので、全文は入れません。
- **時間:** 関数のタイムアウトは 900 秒(Lambda の上限)です。これを超えるタスクは実行できません(下記)。
- **同時実行数の予約:** 2 にします。migration と、メールの取り込みが重なっても動けるようにし、それ以上は増やしません。

<a id="permissions"></a>

## 権限

`redmine-task` を呼べるのは、SSO の管理者のロール、デプロイ用のロール(migration と初めのデータのため)、SES(メールの受信のため)、EventBridge Scheduler だけで、関数 URL は付けません。rake と `rails runner` はデータベースと S3 のすべてを読み書きできるので、呼べる人を絞ることでデータを守ります。権限の詳しい内容は [iam.md](iam.md) にあります。

<a id="migrations-during-deployment"></a>

## デプロイのときの migration

デプロイの段は [deploy-config.md](deploy-config.md#deployment-commands) にあります。migration は、`redmine-task` のイメージを先に新しいものにしてから実行し、成功したら `redmine-web` と `redmine-worker` を更新します(段 7、9)。初めて立てるときは、同じ migration が空のデータベースにスキーマを作り、そのあと `redmine-task` が初めのデータを入れます(段 8)。

migration から `redmine-web` の更新までのあいだは、古いコードが新しいスキーマで動きます。Redmine のバージョンアップは、利用の少ない時間に行います。バージョンアップの前に、増えた migration をこのプロジェクトで確認します([upgrade.md](upgrade.md))。

<a id="notes-on-the-read-only-file-system"></a>

## 読み取り専用のファイルシステムでの注意

Rails は、`db:migrate` のあとに `db/schema.rb` を書き出します(`ActiveRecord.dump_schema_after_migration` の既定は `true`)。Redmine の `production.rb` はこの設定をコメントアウトしたままなので、Lambda では書き込みに失敗します。`additional_environment.rb` で `false` にします。

`redmine:attachments:move_to_subdirectories` など、`files/` の下のファイルを動かすタスクは、S3 のファイルを動かさないので使いません。`redmine:attachments:update_digests` など、添付ファイルを読むタスクは、`/tmp` のキャッシュの仕組み([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/ja/attachments.html#the-tmp-cache))で S3 から取得して読みます。

<a id="scheduled-runs"></a>

## 定期の実行

EventBridge Scheduler から、上の形の入力で `redmine-task` を呼びます。

| タスク | 周期 |
| --- | --- |
| `redmine:attachments:prune` | 毎日 |
| `redmine:send_reminders`(期日の通知) | 使うなら、平日の朝 |
| `redmine_serverless_costexplorer:refresh`(プラグインを足したイメージ、派生のイメージで。Cost Explorer から、管理画面のためにアカウントの費用を取る) | 毎日。`costExplorer.enabled` のときだけ([deploy-config.md](deploy-config.md#fields-of-redminejson)) |
| `redmine_serverless_sqs:prune_records[<日数>]` と `redmine_serverless_ses:prune_records[<日数>]`(プラグインの記録を、保持の期間 `retention.recordsDays` より古いものから消す。失敗したジョブと受け取ったメール。[security.md](security.md#retention-periods)) | 毎日 |

<a id="stopping-unused-functions"></a>

## 使われない関数の停止

Lambda は、数週間呼ばれないコンテナイメージの関数を `Inactive` にします。次の最初の呼び出しは失敗し、関数はイメージの最適化が終わるまで `Pending` になります。`redmine-task` は毎日の定期の実行で呼ばれるので、ふつうは `Inactive` になりません。`bin/rake` と `bin/rails` は、念のため、呼ぶ前に関数の状態を確認し、`Active` になるまで待ちます。

<a id="tasks-longer-than-15-minutes"></a>

## 15 分を超えるタスク

多くの添付ファイルの digest の作り直し(`redmine:attachments:update_digests`)のように、15 分を超えるおそれのあるタスクは、Lambda では実行できません。分けて呼べるタスクは分けます。分けられないときは、同じイメージを ECS の Fargate のタスク(`RunTask`)で 1 回だけ動かします。タスクは、RDS と同じプライベートのサブネットで動かします([rds.md](rds.md))。イメージの取得とログの書き込みに、ECR と CloudWatch Logs への道が要るので、いっしょに用意します。古い Redmine からの移行の migration は、一時の PostgreSQL の上で行うので、Lambda の 15 分には当たりません([migration.md](migration.md))。入口は差し替えて、rake を直接実行します。使った時間だけの料金です。必要になったときに用意します。

<a id="to-verify"></a>

## 未確認の事項

- 何もしない拡張機能を登録した状態で、Lambda の停止のときに環境が正しく終わるか(ランタイムインターフェイスエミュレーターでは、拡張機能が登録され、ハンドラーが動くことを 2026-11-09 に確認)
- 初めのデータの投入(`redmine:load_default_data`)と、空のデータベースへの migration の時間
