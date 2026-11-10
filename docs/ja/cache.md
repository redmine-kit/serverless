# キャッシュ

Lambda の環境ごとに、Redmine のキャッシュを、その環境のメモリに置きます。共有のキャッシュのサービス (ElastiCache など) は使いません。セッションは、キャッシュを使いません ([session.md](session.md))。

<a id="what-redmine-caches"></a>

## Redmine がキャッシュするもの

Redmine 7.0.3 がキャッシュを使うのは、次の数か所だけです (2026-11-09 にコードで確認)。

| もの | Redmine の中の場所 | 保存先 | 使うとき |
| --- | --- | --- | --- |
| 整形済みのテキスト (wiki のページ、チケットの説明と注記を HTML にしたもの) | `Redmine::WikiFormatting.to_html` | `config.cache_store` | 「テキスト書式の変換結果をキャッシュ」が有効 (管理 › 設定 › 全般。`cache_formatted_text`。既定は無効) で、2 KB を超えるテキストのときだけ |
| 検索の結果 (ページを送るための、結果の ID の一覧) | `Redmine::Search` | Redmine 専用の `config.redmine_search_cache_store` (メモリ、32 MB まで) | 検索のたび |
| 言語の選択肢の一覧 | `Redmine::I18n` | `config.cache_store` | 初めて表示するとき |
| リポジトリの画面 | `RepositoriesController` | `config.cache_store` | 使わない。Lambda ではリポジトリを無効にする ([lambda.md](lambda.md#features-that-cannot-be-used)) |

<a id="the-design-memory-in-each-environment"></a>

## この設計: 環境別のメモリ

| 項目 | 値 |
| --- | --- |
| `config.cache_store` | `:memory_store`。環境ごとに 64 MB まで (`image/config/additional_environment.rb`) |
| `config.redmine_search_cache_store` | Redmine の既定の `:memory_store` (32 MB) |
| 費用 | なし |

Rails 8.1 の既定は `tmp/cache/` のファイルですが、Lambda では `/tmp` に置くことになり、際限なく増えます ([lambda.md](lambda.md#read-only-file-system))。

メモリに置くと、キャッシュは環境ごとになり、新しい環境は空から始まります。別の環境が出すページでは整形済みのテキストを作り直し、検索の結果のページを別の環境で送ると検索をやり直します。結果は同じで、かかる時間だけが違います。少人数のチームなら、この差は小さく済みます。整形済みのテキストは、設定が有効で長いテキストのときだけキャッシュし、検索のやり直しは、次のページが別の環境に届いたときだけだからです。

<a id="what-can-be-tuned"></a>

## 調整できるところ

| 何を | どこで | 効き方 |
| --- | --- | --- |
| 整形済みのテキストのキャッシュ | 管理 › 設定 › 全般 ›「テキスト書式の変換結果をキャッシュ」 | 有効: 長いテキスト (2 KB を超えるもの) を、環境ごとに 1 回だけ HTML にする。wiki のページが長いなら有効にする価値がある。無効 (既定): 表示のたびに HTML にする |
| キャッシュの大きさ | `image/config/additional_environment.rb` の `config.cache_store = :memory_store, { size: … }` | メモリのキャッシュは、いっぱいになると、最後に使ってから長いものから捨てる。関数のメモリは 2,048 MB で ([lambda.md](lambda.md#function-settings))、キャッシュはその一部。長い wiki のページをキャッシュしていて、環境のメモリに余裕があれば大きくする (呼び出しごとの最大のメモリの使用量は CloudWatch で見られる) |
| 項目の寿命 | 同じ行の `expires_in:` | 指定なし: 環境が続くあいだ残る。整形済みのテキストは、テキストのダイジェストで鍵を作るので、テキストを変えても古いものは使われない |
| 検索のキャッシュの大きさ | `additional_environment.rb` の `config.redmine_search_cache_store = :memory_store, { size: … }` | Redmine は `additional_environment.rb` より前に `config/application.rb` でこれを設定するので、ここで書いた値が Redmine の値に代わる。`nil` にすると、検索をキャッシュしない |
| 環境の寿命 | Provisioned Concurrency か、温めるための呼び出し ([deploy-config.md](deploy-config.md#fields-of-redminejson) の `lambda.warmup`) | キャッシュは環境と同じだけ残る。温めておく環境はキャッシュを保ち、Lambda が要求の集中のために始めた環境は、空から始まる。Provisioned Concurrency は 2 GB の環境 1 つで月に約 23 ドル ([cost.md](cost.md#what-adds-cost)) |
| 共有のキャッシュ | `config.cache_store` と `config.redmine_search_cache_store` を ElastiCache に向ける (下記) | どの環境も同じ項目を使い、新しい環境も最初からそれを使える |

キャッシュの項目がどれだけ見つかるかは、まだ測っていません。Rails はキャッシュの読み取りを ActiveSupport の通知 (`cache_read.active_support`) に出すので、試すあいだはそれをログに出せます。

<a id="when-a-shared-cache-is-worth-it"></a>

## 共有のキャッシュが見合うとき

共有のキャッシュなら、整形済みのテキストと検索の結果を、すべての環境で使い回せます。長い wiki のページで書式のキャッシュを有効にするときや、多くの人が検索の結果のページを送るときに、検討する価値があります。

| 選択肢 | 内容 | 月の費用 (ap-northeast-1、730 時間) |
| --- | --- | --- |
| 環境別のメモリ (この設計) | `:memory_store` | 0 ドル |
| ElastiCache Serverless for Valkey | マネージドで、大きさは自動。置いたデータの量 (1 つのキャッシュで最低 100 MB) と、ElastiCache Processing Unit (ECPU。単純な読み書きは 1 KB ごとに 1 ECPU) で課金 | データ: 0.1 GB × 1 GB 時間あたり 0.101 ドル = 7.37 ドル。ECPU: 100 万あたり 0.0027 ドルで、たとえば 1,000 万なら 0.03 ドル。合わせて約 7.4 ドル |
| ElastiCache for Valkey の `cache.t4g.micro` のノード 1 台 | レプリカなしのノード (0.5 GiB) | 1 時間 0.02 ドル = 14.60 ドル |

価格は、ap-northeast-1 の ElastiCache の AWS の価格表 (2026-10-28 公開) と、ElastiCache の料金のページにある Valkey の最低 100 MB によります (2026-11-09 に確認)。同じノードでも Valkey は Redis OSS より安く (`cache.t4g.micro` は Redis OSS で 1 時間 0.025 ドル)、Serverless の最低の量も小さくなります (Redis OSS と Memcached は 1 GB)。

関数はもう VPC の中にあるので、VPC エンドポイントも NAT インスタンスも使わずに、プライベートサブネットの ElastiCache に直接接続できます。セキュリティグループでは、関数のセキュリティグループからの接続を許します。Rails では、キャッシュのエンドポイントを指定して `config.cache_store = :redis_cache_store` にし (Valkey は Redis のプロトコルで話します。ElastiCache Serverless は TLS が必須です)、`config.redmine_search_cache_store` も同じにして、イメージに `redis` の gem を足します。

今は選びません。少人数のチームでは、月に約 7.4 ドル以上は基本の費用 ([cost.md](cost.md)) の大きな割合になるのに、キャッシュで省ける手間は少しです。Redmine を変えずに、あとから足せます。

<a id="to-verify"></a>

## 未確認の事項

- Redmine の使い方で、環境ごとのキャッシュの項目がどれだけ見つかるか (未計測)
- Redmine の使い方で、1 か月に ECPU がどれだけかかるか (上の見積もりは 1,000 万と仮定)
- ElastiCache Serverless が VPC の中に作るエンドポイントに、別の料金がかかるか (未確認)
- Lambda の環境が始まるときに、TLS で ElastiCache に初めてつなぐのに、どれだけかかるか
