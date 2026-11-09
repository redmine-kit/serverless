# セッション

Redmine は、セッションを暗号化した Cookie に入れ、データベースのトークンで確認します。Lambda の環境にもキャッシュにも何も置かないので、次の要求がどの環境に届いても、ログインは続きます。

<a id="how-redmine-keeps-a-session"></a>

## Redmine のセッションの持ち方

2026-11-09 に、Redmine 7.0.3 のコードで確認しました。

| 項目 | しくみ |
| --- | --- |
| セッション | Rails の `cookie_store`。Redmine の `config/application.rb` で設定する。Cookie は `_redmine_session` で、`SameSite=Lax`、`HttpOnly`。`SECRET_KEY_BASE` から作る鍵で暗号化し、署名する。サーバーの側には何も置かない |
| セッションのトークン | ログインのときに、Redmine はデータベースの `tokens` の表にトークンを作り(action は `session`)、その値をセッションに入れる。要求のたびに、トークンがあるかを確認する(`User.verify_session_token`)。ログアウトで消す |
| 1 人あたりのトークン | 1 人 10 件まで(ブラウザーや端末ごとに 1 件)。それを超えてログインすると、最後に使ってから長いものを消す |
| 自動ログイン(「ログインを維持」) | 別の Cookie(`autologin`)と、別のトークン(action は `autologin`)。有効な日数は「自動ログイン」の設定。既定は無効 |
| API | REST API の要求は、セッションではなく API キーを使う |

<a id="on-lambda"></a>

## Lambda では

- **どの環境もどの Cookie も読める:** どの環境も、起動のときに `SECRET_KEY_BASE` を SSM Parameter Store から読むので([lambda.md](lambda.md#settings-and-secrets-ssm-parameter-store))、ほかの環境が書いた Cookie を読めます。
- **どの環境も同じトークンを確認する:** トークンは、すべての環境が使う RDS にあります。
- **書き込み:** 「無操作タイムアウト」を設定すると、トークンの確認のときに、1 つのセッションにつき最大で 1 分に 1 回、トークンの時刻を更新します。データベースへの小さな書き込みが 1 回です。
- **`SECRET_KEY_BASE` を変えると:** すべてのセッションの Cookie が読めなくなり、全員がログインし直します(事故のあとの手順として [security.md](security.md) にもあります)。

<a id="what-can-be-set"></a>

## 設定できるところ

| 設定 | 場所 | 既定 | 効き方 |
| --- | --- | --- | --- |
| 有効期間の最大値 | 管理 › 設定 › 認証 | 無効 | ログインからこの時間がたつと、何をしていてもセッションが切れる |
| 無操作タイムアウト | 同じ | 無効 | 要求のないまま、この時間がたつとセッションが切れる |
| 自動ログイン | 同じ | 無効 | 「ログインを維持」でログインしたままにする日数。専用の Cookie とトークンを使う |
| `autologin_cookie_secure` | `config/configuration.yml` | 要求のプロトコルに合わせる | 自動ログインの Cookie に `Secure` の属性を付けるか。CloudFront の後ろでは、要求は HTTPS として Redmine に届くので、付く |

最初の 2 つを変えると、Redmine が、管理者にセキュリティの通知を送ります。

<a id="the-secure-attribute-of-the-session-cookie"></a>

## セッションの Cookie の `Secure` の属性

Redmine のセッションの Cookie には、HTTPS でも `Secure` の属性が付きません(2026-11-09 にイメージで確認。`X-Forwarded-Proto: https` を付けた要求で、`_redmine_session` には `path`、`httponly`、`samesite=lax` だけが付いた)。Redmine の `session_store` は `secure` を指定せず、Redmine の `production.rb` では `config.force_ssl` がコメントになっています。

イメージで付けています。`image/config/additional_environment.rb` で、Redmine と同じ `session_store` に `secure: true` だけを足して設定します。Redmine の設定のあとに評価されるので、置き換わります。設定するのは、イメージが動く本番の環境(production)だけです。Redmine 本体のテストは暗号化なしの HTTP で要求を送るので、セッションの Cookie が書き込まれなくなるためです。イメージのテストで、`_redmine_session` に `Secure` が付くことを確認します([testing.md](testing.md#image-tests))。

```ruby
config.session_store :cookie_store, key: '_redmine_session', path: config.relative_url_root || '/',
                                    same_site: :lax, secure: true
```

- **理由:** CloudFront は HTTP を HTTPS に送り直し、`Strict-Transport-Security` を付けるので([security.md](security.md))、初めて訪れたあとは、ブラウザーが暗号化なしの HTTP で Cookie を送ることはありません。`Secure` は、初めての訪問と、その経路の外に向けた、ふつうの守りです。
- **`config.force_ssl` にしない理由:** `ssl_options` で `hsts: false` にすると、Rails は `Strict-Transport-Security: max-age=0` を送り、CloudFront が付けるヘッダーを打ち消してしまいます。
- **手元では:** Rails は、`Secure` の Cookie を HTTPS の要求にだけ書き込み(CloudFront と関数 URL の後ろでは、要求は HTTPS として届きます)、ブラウザーも暗号化なしの HTTP では送らないので、`http://` でイメージにログインすることはできません。イメージのテストは `X-Forwarded-Proto: https` を付けて確認します。

<a id="to-verify"></a>

## 未確認の事項

- デプロイのあと、CloudFront と関数 URL の後ろで、セッションと自動ログインの Cookie に `Secure` が付いているか
- 利用者が多いときに、「無操作タイムアウト」でどれだけ書き込みが増えるか
