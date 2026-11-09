# キャッシュとセッション

Lambda の環境ごとに、Redmine のキャッシュを、その環境のメモリに置きます。共有のキャッシュのサービス(ElastiCache など)は使いません。セッションは、キャッシュに依存しません。

<a id="what-redmine-caches"></a>

## Redmine がキャッシュするもの

Redmine 7.0.3 が Rails のキャッシュを使うのは、次の数か所だけです(2026-11-09 にコードで確認)。

| もの | Redmine の中の場所 | 使うとき |
| --- | --- | --- |
| 整形済みのテキスト(wiki、チケットの説明と注記を HTML にしたもの) | `Redmine::WikiFormatting.to_html` | 管理画面の設定の「テキスト書式の変換結果をキャッシュ」(`cache_formatted_text`。既定は無効)が有効で、2 KB を超えるテキストのときだけ |
| 検索の結果(ページを送るための、結果の ID の一覧) | `Redmine::Search`。専用のキャッシュ `redmine_search_cache_store`(メモリ、32 MB まで)を使う | 検索のたび |
| 言語の選択肢の一覧 | `Redmine::I18n` | 初めて表示するとき |
| リポジトリの画面 | `RepositoriesController` | 使わない。Lambda ではリポジトリを無効にする([lambda.md](lambda.md#features-that-cannot-be-used)) |

<a id="the-design-memory-in-each-environment"></a>

## この設計: 環境ごとのメモリ

| 項目 | 値 |
| --- | --- |
| `config.cache_store` | `:memory_store`。環境ごとに 64 MB まで(`image/config/additional_environment.rb`) |
| 検索の結果 | Redmine 自身のメモリのキャッシュ(32 MB) |
| 費用 | なし |

- **Rails の既定を使わない理由:** Rails 8.1 の既定は `tmp/cache/` のファイルです。Lambda では `/tmp` に置くことになり、際限なく増えます([lambda.md](lambda.md#read-only-file-system))。
- **失うもの:** キャッシュは環境ごとで、新しい環境は空から始まります。別の環境が出すページでは整形済みのテキストを作り直し、検索の結果のページを別の環境で送ると、検索をやり直します。結果は同じで、かかる時間だけが違います。
- **これで足りる理由:** 少人数のチームでは、キャッシュで省ける手間は少しです。整形済みのテキストは、設定が有効で長いテキストのときだけキャッシュし、検索のやり直しは、次のページが別の環境に届いたときだけです。

<a id="sessions"></a>

## セッション

セッションはキャッシュを使わないので、環境をまたいで続きます。

- **Cookie に入れる:** Redmine は、セッションを暗号化した Cookie(`_redmine_session`。Rails の `cookie_store`。Redmine の `config/application.rb` で設定)に入れます。サーバーの側には何も置きません。
- **データベースで確認する:** ログインのときに、Redmine はデータベースの `tokens` の表にセッションのトークンを作り(1 人 10 件まで)、セッションに入れて、要求のたびに確認します。ログアウトで消します。管理画面のセッションの有効期間の設定も、このトークンで効きます。
- **Lambda では:** どの環境も、同じ `SECRET_KEY_BASE`(SSM Parameter Store から読む。[lambda.md](lambda.md#settings-and-secrets-ssm-parameter-store))で Cookie を読み、同じデータベースでトークンを確認します。そのため、次の要求がどの環境に届いても、ログインは続きます。
- **`SECRET_KEY_BASE` を変えると:** すべてのセッションが切れ、全員がログインし直します。

<a id="when-a-shared-cache-is-worth-it"></a>

## 共有のキャッシュが見合うとき

共有のキャッシュなら、整形済みのテキストと検索の結果を、すべての環境で使い回せます。長い wiki のページで書式のキャッシュを有効にするときや、多くの人が検索の結果のページを送るときに、検討する価値があります。

| 選択肢 | 中身 | 月の費用(東京、730 時間) |
| --- | --- | --- |
| 環境ごとのメモリ(この設計) | `:memory_store` | 0 ドル |
| ElastiCache Serverless for Valkey | マネージドで、大きさは自動。置いたデータの量(1 つのキャッシュで最低 100 MB)と、ElastiCache Processing Unit(ECPU。単純な読み書きは 1 KB ごとに 1 ECPU)で課金 | データ: 0.1 GB × 1 GB 時間あたり 0.101 ドル = 7.37 ドル。ECPU: 100 万あたり 0.0027 ドルで、たとえば 1,000 万なら 0.03 ドル。合わせて約 7.4 ドル |
| ElastiCache for Valkey の `cache.t4g.micro` のノード 1 台 | レプリカなしのノード(0.5 GiB) | 1 時間 0.02 ドル = 14.60 ドル |

- **価格:** 東京(ap-northeast-1)の ElastiCache の AWS の価格表(2026-10-28 公開)と、ElastiCache の料金のページの Valkey の最低 100 MB です(2026-11-09 に確認)。同じノードでも Valkey は Redis OSS より安く(`cache.t4g.micro` は Redis OSS で 1 時間 0.025 ドル)、Serverless の最低の量も小さくなります(Redis OSS と Memcached は 1 GB)。
- **ネットワーク:** 関数はもう VPC の中にあるので、VPC のエンドポイントも NAT インスタンスも使わずに、プライベートのサブネットの ElastiCache に直接つなげます。セキュリティグループで、関数のセキュリティグループからを許します。
- **Rails では:** キャッシュのエンドポイントを指定して `config.cache_store = :redis_cache_store` にし(Valkey は Redis のプロトコルで話します。ElastiCache Serverless は TLS が必須です)、`config.redmine_search_cache_store` も同じにします。イメージに `redis` の gem を足します。
- **今は選ばない理由:** 少人数のチームでは、月に約 7.4 ドル以上は、基本の費用([cost.md](cost.md))の大きな割合になります。それに対して、キャッシュで省ける手間は少しです。Redmine を変えずに、あとから足せます。

<a id="to-verify"></a>

## 確認すること

- Redmine の使い方で、1 か月に ECPU がどれだけかかるか(上の見積もりは 1,000 万と仮定)
- ElastiCache Serverless が VPC の中に作るエンドポイントに、別の料金がかかるか(未確認)
- Lambda の環境が始まるときに、TLS で ElastiCache に初めてつなぐのに、どれだけかかるか
