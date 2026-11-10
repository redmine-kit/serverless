# キャッシュ

Redmine のキャッシュは、Lambda の実行環境ごとに、その環境のメモリに置きます。共有キャッシュのサービス (ElastiCache など) は使いません。セッションはキャッシュを使いません ([session.md](session.md))。

<a id="what-redmine-caches"></a>

## Redmine がキャッシュするデータ

Redmine 7.0.3 がキャッシュを使うのは、次の数か所だけです (2026-11-09 にコードで確認)。

| データ | Redmine のコード | 保存先 | 使用する条件 |
| --- | --- | --- | --- |
| 整形済みのテキスト (wiki ページ、チケットの説明と注記を HTML に変換したもの) | `Redmine::WikiFormatting.to_html` | `config.cache_store` | 「テキスト書式の変換結果をキャッシュ」が有効 (管理 › 設定 › 全般。`cache_formatted_text`。既定は無効) で、2 KB を超えるテキストの場合だけ |
| 検索結果 (ページ送りのための、結果の ID の一覧) | `Redmine::Search` | Redmine 専用の `config.redmine_search_cache_store` (メモリ、32 MB まで) | 検索のたび |
| 言語の選択肢の一覧 | `Redmine::I18n` | `config.cache_store` | 初回の表示 |
| リポジトリ画面 | `RepositoriesController` | `config.cache_store` | 使用しない。Lambda ではリポジトリを無効にする ([lambda.md](lambda.md#features-that-cannot-be-used)) |

<a id="the-design-memory-in-each-environment"></a>

## この設計: 環境別のメモリ

| 項目 | 値 |
| --- | --- |
| `config.cache_store` | `:memory_store`。環境ごとに 64 MB まで (`image/config/additional_environment.rb`) |
| `config.redmine_search_cache_store` | Redmine の既定の `:memory_store` (32 MB) |
| 費用 | なし |

Rails 8.1 の既定は `tmp/cache/` のファイルですが、Lambda では `/tmp` に置くことになり、際限なく増えます ([lambda.md](lambda.md#read-only-file-system))。

メモリに置くと、キャッシュは環境ごとに分かれ、新しい環境は空の状態から始まります。別の環境が返すページでは整形済みのテキストを作り直し、検索結果のページ送りのリクエストが別の環境に振り分けられると検索をやり直します。結果は同じで、かかる時間だけが違います。少人数のチームなら、この差は小さく済みます。整形済みのテキストをキャッシュするのは設定が有効で長いテキストの場合だけで、検索をやり直すのは次のページのリクエストが別の環境に振り分けられた場合だけだからです。

<a id="what-can-be-tuned"></a>

## 調整できる項目

| 項目 | 設定場所 | 効果 |
| --- | --- | --- |
| 整形済みのテキストのキャッシュ | 管理 › 設定 › 全般 ›「テキスト書式の変換結果をキャッシュ」 | 有効: 長いテキスト (2 KB を超えるもの) を、環境ごとに 1 回だけ HTML に変換する。長い wiki ページがあるなら有効にする価値がある。無効 (既定): 表示のたびに HTML に変換する |
| キャッシュサイズ | `image/config/additional_environment.rb` の `config.cache_store = :memory_store, { size: … }` | メモリキャッシュは、いっぱいになると、最も長く使われていない項目から破棄する。関数のメモリは 2,048 MB で ([lambda.md](lambda.md#function-settings))、キャッシュはその一部。長い wiki ページをキャッシュしていて、環境のメモリに余裕があれば大きくする (呼び出しごとの最大メモリ使用量は CloudWatch で確認できる) |
| 項目の有効期間 | 同じ行の `expires_in:` | 指定なし: 環境が続くあいだ保持する。整形済みのテキストは、テキストのダイジェストからキーを作るので、テキストを変更すると古い項目は使われない |
| 検索キャッシュのサイズ | `additional_environment.rb` の `config.redmine_search_cache_store = :memory_store, { size: … }` | Redmine は `additional_environment.rb` より前に `config/application.rb` でこれを設定するので、ここで書いた値が Redmine の値を置き換える。`nil` にすると、検索をキャッシュしない |
| 環境の存続期間 | Provisioned Concurrency か、ウォームアップの呼び出し ([deploy-config.md](deploy-config.md#fields-of-redminejson) の `lambda.warmup`) | キャッシュは環境と同じ期間だけ残る。ウォームアップで維持する環境はキャッシュを保ち、Lambda がリクエストの集中に対応するために開始した環境は、空の状態から始まる。Provisioned Concurrency は 2 GB の環境 1 つで月額約 23 ドル ([cost.md](cost.md#what-adds-cost)) |
| 共有キャッシュ | `config.cache_store` と `config.redmine_search_cache_store` の接続先を ElastiCache にする (下記) | どの環境も同じ項目を使い、新しい環境も最初からそれを使える |

キャッシュのヒット率は、まだ計測していません。Rails はキャッシュの読み取りを ActiveSupport の通知 (`cache_read.active_support`) として発行するので、検証のあいだはそれをログに出力できます。

<a id="when-a-shared-cache-is-worth-it"></a>

## 共有キャッシュを使う場合

共有キャッシュなら、整形済みのテキストと検索結果を、すべての環境で再利用できます。長い wiki ページで書式のキャッシュを有効にする場合や、多くの人が検索結果のページ送りを使う場合に、検討する価値があります。

| 選択肢 | 内容 | 月額費用 (ap-northeast-1、730 時間) |
| --- | --- | --- |
| 環境別のメモリ (この設計) | `:memory_store` | 0 ドル |
| ElastiCache Serverless for Valkey | マネージドで、容量は自動。保存したデータ量 (1 つのキャッシュで最低 100 MB) と、ElastiCache Processing Unit (ECPU。単純な読み書きは 1 KB ごとに 1 ECPU) で課金 | データ: 0.1 GB × 1 GB 時間あたり 0.101 ドル = 7.37 ドル。ECPU: 100 万あたり 0.0027 ドルで、たとえば 1,000 万なら 0.03 ドル。合計約 7.4 ドル |
| ElastiCache for Valkey の `cache.t4g.micro` ノード 1 台 | レプリカなしのノード (0.5 GiB) | 1 時間 0.02 ドル = 14.60 ドル |

価格は、ap-northeast-1 の ElastiCache の AWS の料金表 (2026-10-28 公開) と、ElastiCache の料金ページにある Valkey の最低 100 MB に基づきます (2026-11-09 に確認)。同じノードでも Valkey は Redis OSS より安く (`cache.t4g.micro` は Redis OSS で 1 時間 0.025 ドル)、Serverless の最低容量も小さくなります (Redis OSS と Memcached は 1 GB)。

関数はすでに VPC 内にあるので、VPC エンドポイントも NAT インスタンスも使わずに、プライベートサブネットの ElastiCache に直接接続できます。セキュリティグループでは、関数のセキュリティグループからの接続を許可します。Rails では、キャッシュのエンドポイントを指定して `config.cache_store = :redis_cache_store` にし (Valkey は Redis のプロトコルで通信します。ElastiCache Serverless は TLS が必須です)、`config.redmine_search_cache_store` も同じ設定にして、イメージに `redis` gem を追加します。

今は採用しません。少人数のチームでは、月額約 7.4 ドル以上の費用は基本の費用 ([cost.md](cost.md)) の大きな割合を占めるのに、キャッシュで省ける処理はわずかです。Redmine を変更せずに、あとから追加できます。

<a id="to-verify"></a>

## 未確認の事項

- Redmine の使い方での、環境ごとのキャッシュのヒット率 (未計測)
- Redmine の使い方で、1 か月にかかる ECPU (上の見積もりは 1,000 万と仮定)
- ElastiCache Serverless が VPC 内に作るエンドポイントに、別の料金がかかるか (未確認)
- Lambda の環境の起動時に、TLS で ElastiCache に初めて接続するのにかかる時間
