# Sessions

Redmine keeps sessions in an encrypted cookie and checks them against a token in the database. Nothing is kept in the Lambda environment or in a cache, so a sign-in continues whichever environment serves the next request.

## How Redmine keeps a session

Checked in the code of Redmine 7.0.3 on 2026-11-09.

| Item | How it works |
| --- | --- |
| The session | Rails' `cookie_store`, set in Redmine's `config/application.rb`: the cookie `_redmine_session`, `SameSite=Lax`, `HttpOnly`. The cookie is encrypted and signed with a key derived from `SECRET_KEY_BASE`. Nothing is stored on the server for it |
| The session token | At sign-in, Redmine creates a token in the `tokens` table (action `session`) and puts its value in the session. Every request checks that the token exists (`User.verify_session_token`). Signing out deletes it |
| Tokens per user | Up to 10 session tokens per user (one per browser or device). A new sign-in beyond that removes the one used least recently |
| Autologin ("Stay logged in") | A separate cookie, `autologin`, with a token of its own (action `autologin`), valid for the days set in "Autologin". Off by default |
| API | REST API requests use the API key, not the session |

## On Lambda

- **Every environment reads every cookie:** All environments read `SECRET_KEY_BASE` from SSM Parameter Store at start-up ([lambda.md](lambda.md#settings-and-secrets-ssm-parameter-store)), so each one can read the cookie that another one wrote.
- **Every environment checks the same tokens:** The tokens are in RDS, which all environments use.
- **Writes:** With "Session inactivity timeout" set, checking the token updates its time at most once a minute per session, which is one small write to the database.
- **Changing `SECRET_KEY_BASE`:** Every session cookie becomes unreadable, and everyone signs in again (also listed as a step after an incident in [security.md](security.md)).

## What can be set

| Setting | Where | Default | Effect |
| --- | --- | --- | --- |
| Session maximum lifetime | Administration › Settings › Authentication | Off | A session ends this long after sign-in, whatever is done |
| Session inactivity timeout | Same | Off | A session ends after this long without a request |
| Autologin | Same | Off | Days that "Stay logged in" keeps a user signed in, with its own cookie and token |
| `autologin_cookie_secure` | `config/configuration.yml` | The request's protocol | Whether the autologin cookie has the `Secure` attribute. Behind CloudFront, requests reach Redmine as HTTPS, so it is set |

Changes to the first two are sent to administrators as security notifications by Redmine.

## The `Secure` attribute of the session cookie

Redmine's session cookie has no `Secure` attribute, even over HTTPS (checked in the image on 2026-11-09: a request with `X-Forwarded-Proto: https` got `_redmine_session` with only `path`, `httponly` and `samesite=lax`). Redmine's `session_store` does not set `secure`, and `config.force_ssl` is commented out in Redmine's `production.rb`.

The image adds it: `image/config/additional_environment.rb` sets the same `session_store` as Redmine's, with `secure: true` added. It is evaluated after Redmine's setting, so it replaces it. It is set only in the production environment, which the image runs: Redmine's own tests send plain HTTP requests and would get no session cookie. The image tests check that `_redmine_session` has `Secure` ([testing.md](testing.md#image-tests)).

```ruby
config.session_store :cookie_store, key: '_redmine_session', path: config.relative_url_root || '/',
                                    same_site: :lax, secure: true
```

- **Why:** CloudFront redirects HTTP to HTTPS and sends `Strict-Transport-Security` ([security.md](security.md)), so after the first visit the browser does not send the cookie over plain HTTP anyway. `Secure` is the usual protection for the first visit and for anything outside that path.
- **Why not `config.force_ssl`:** With `hsts: false` in `ssl_options`, Rails sends `Strict-Transport-Security: max-age=0`, which would undo the header CloudFront adds.
- **Locally:** Rails writes a `Secure` cookie only on HTTPS requests (behind CloudFront and the function URL, requests arrive as HTTPS), and a browser does not send one over plain HTTP, so signing in to the image over `http://` does not work. The image tests send `X-Forwarded-Proto: https`.

## To verify

- That the session cookie and the autologin cookie have `Secure` behind CloudFront and the function URL after deployment
- How many writes "Session inactivity timeout" adds with many users
