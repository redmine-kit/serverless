# セッション

Redmine は、セッションを暗号化した Cookie に保存し、データベースのトークンで検証します。Lambda の環境にもキャッシュにも何も保存しないので、次のリクエストがどの環境に振り分けられても、ログインは維持されます。

<a id="how-redmine-keeps-a-session"></a>

## Redmine のセッション管理

2026-11-09 に、Redmine 7.0.3 のコードで確認しました。

| 項目 | しくみ |
| --- | --- |
| セッション | Rails の `cookie_store`。Redmine の `config/application.rb` で設定する。Cookie は `_redmine_session` で、`SameSite=Lax`、`HttpOnly`。`SECRET_KEY_BASE` から生成するキーで暗号化し、署名する。サーバー側には何も保存しない |
| セッショントークン | ログイン時に、Redmine はデータベースの `tokens` テーブルにトークンを作成し (action は `session`)、その値をセッションに保存する。リクエストのたびに、トークンが存在するかを確認する (`User.verify_session_token`)。ログアウトで削除する |
| ユーザーあたりのトークン | 1 人 10 件まで (ブラウザーや端末ごとに 1 件)。それを超えてログインすると、最も長く使われていないトークンを削除する |
| 自動ログイン (「ログインを維持」) | 別の Cookie (`autologin`) と、別のトークン (action は `autologin`)。有効な日数は「自動ログイン」の設定。デフォルトは無効 |
| API | REST API のリクエストは、セッションではなく API キーを使う |

<a id="on-lambda"></a>

## Lambda での動作

どの環境でも、ほかの環境で開始したセッションを継続できます。どの環境も、起動時に `SECRET_KEY_BASE` を SSM Parameter Store から読み込むので ([lambda.md](lambda.md#settings-and-secrets-ssm-parameter-store))、ほかの環境が書いた Cookie を読むことができ、トークンもすべての環境が使う RDS で確認します。

「無操作タイムアウト」を設定すると、トークンの確認時に、1 つのセッションにつき最大で 1 分に 1 回トークンの時刻を更新します。データベースへの小さな書き込みが 1 回発生します。`SECRET_KEY_BASE` を変更すると、すべてのセッションの Cookie が読めなくなり、全員がログインし直します。この操作は、インシデント対応の手順として [security.md](security.md) にも記載しています。

<a id="what-can-be-set"></a>

## 設定項目

| 設定 | 場所 | デフォルト | 効果 |
| --- | --- | --- | --- |
| 有効期間の最大値 | 「管理」›「設定」›「認証」 | 無効 | ログインからこの時間が経過すると、操作中であってもセッションが切れる |
| 無操作タイムアウト | 同上 | 無効 | リクエストがないまま、この時間が経過するとセッションが切れる |
| 自動ログイン | 同上 | 無効 | 「ログインを維持」でログインしたままにする日数。専用の Cookie とトークンを使う |
| `autologin_cookie_secure` | `config/configuration.yml` | リクエストのプロトコルに従う | 自動ログインの Cookie に `Secure` 属性を付けるか。CloudFront の背後では、リクエストは HTTPS として Redmine に転送されるので、付く |

最初の 2 つを変更すると、Redmine がシステム管理者にセキュリティ通知を送信します。

<a id="the-secure-attribute-of-the-session-cookie"></a>

## セッション Cookie の `Secure` 属性

Redmine のセッション Cookie には、HTTPS でも `Secure` 属性が付きません (2026-11-09 にイメージで確認。`X-Forwarded-Proto: https` を付けたリクエストで、`_redmine_session` には `path`、`httponly`、`samesite=lax` だけが付いた)。Redmine の `session_store` は `secure` を指定せず、Redmine の `production.rb` では `config.force_ssl` がコメントアウトされています。

この属性はイメージで付けています。`image/config/additional_environment.rb` で、Redmine と同じ `session_store` に `secure: true` だけを追加して設定します。Redmine の設定のあとに評価されるので、置き換わります。設定するのは、イメージが動作する本番環境 (production) だけです。Redmine 本体のテストは暗号化なしの HTTP でリクエストを送るので、セッション Cookie が書き込まれなくなるためです。イメージテストで、`_redmine_session` に `Secure` が付くことを確認します ([testing.md](testing.md#image-tests))。

```ruby
config.session_store :cookie_store, key: '_redmine_session', path: config.relative_url_root || '/',
                                    same_site: :lax, secure: true
```

CloudFront は HTTP を HTTPS にリダイレクトし、`Strict-Transport-Security` を付けるので ([security.md](security.md))、初回の訪問のあとは、ブラウザーが暗号化なしの HTTP で Cookie を送ることはありません。`Secure` は、初回の訪問と、その経路の外に対する、一般的な対策です。`config.force_ssl` は使いません。`ssl_options` で `hsts: false` にすると、Rails は `Strict-Transport-Security: max-age=0` を送り、CloudFront が付けるヘッダーを打ち消してしまうためです。

そのためローカル環境では、`http://` でイメージにログインできません。Rails は `Secure` の Cookie を HTTPS のリクエストにだけ書き込み (CloudFront と関数 URL の背後では、リクエストは HTTPS として転送されます)、ブラウザーも暗号化なしの HTTP では送らないためです。イメージテストは `X-Forwarded-Proto: https` を付けて確認します。

<a id="to-verify"></a>

## 未確認の事項

- デプロイ後に、CloudFront と関数 URL の背後で、セッションと自動ログインの Cookie に `Secure` が付いているか
- 利用者が多い場合に、「無操作タイムアウト」で書き込みがどれだけ増えるか
