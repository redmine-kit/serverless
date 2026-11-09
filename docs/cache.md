# Cache and sessions

Each Lambda environment keeps Redmine's cache in its own memory. No shared cache service (such as ElastiCache) is used. Sessions do not depend on the cache.

## What Redmine caches

Redmine 7.0.3 uses the Rails cache in only a few places (checked in the code on 2026-11-09).

| What | Where in Redmine | When |
| --- | --- | --- |
| Formatted text (wiki, issue descriptions and notes rendered to HTML) | `Redmine::WikiFormatting.to_html` | Only when "Cache formatted text" is on in the administration settings (`cache_formatted_text`; off by default), and only for text over 2 KB |
| Search results (the IDs of the results, for paging through them) | `Redmine::Search`, with its own store `redmine_search_cache_store` (memory, up to 32 MB) | Every search |
| The list of languages for the language selector | `Redmine::I18n` | The first time it is shown |
| Repository pages | `RepositoriesController` | Not used: repositories are turned off on Lambda ([lambda.md](lambda.md#features-that-cannot-be-used)) |

## The design: memory in each environment

| Item | Value |
| --- | --- |
| `config.cache_store` | `:memory_store`, up to 64 MB per environment (`image/config/additional_environment.rb`) |
| Search results | Redmine's own memory store (32 MB) |
| Cost | None |

- **Why not the Rails default:** The Rails 8.1 default is files in `tmp/cache/`, which is in `/tmp` on Lambda and would grow without limit ([lambda.md](lambda.md#read-only-file-system)).
- **What is lost:** Each environment has its own cache, and a new environment starts empty. A page that is served by another environment computes the formatted text again, and paging through search results in another environment runs the search again. The results are the same; only the time differs.
- **Why it is enough:** For a small team the cache saves little. Formatted text is cached only when the setting is on and the text is long, and searches are run again only when the next page goes to another environment.

## Sessions

Sessions do not use the cache, so they work across environments.

- **In a cookie:** Redmine keeps the session in an encrypted cookie (`_redmine_session`, Rails' `cookie_store`, set in Redmine's `config/application.rb`). Nothing is stored on the server for it.
- **Checked against the database:** At sign-in, Redmine creates a session token in the `tokens` table (up to 10 per user), puts it in the session, and checks it on every request. Signing out deletes it. The session timeout settings in the administration pages work through this token.
- **On Lambda:** Every environment reads the cookie with the same `SECRET_KEY_BASE` (from SSM Parameter Store; [lambda.md](lambda.md#settings-and-secrets-ssm-parameter-store)) and checks the token in the same database, so a sign-in continues whichever environment serves the next request.
- **Changing `SECRET_KEY_BASE`:** Every session ends, and everyone signs in again.

## When a shared cache is worth it

A shared cache keeps the formatted text and the search results for all environments. It is worth considering when the formatted-text cache is turned on for long wiki pages, or when many people page through search results.

| Option | What it is | Monthly cost (Tokyo, 730 hours) |
| --- | --- | --- |
| Memory in each environment (this design) | `:memory_store` | USD 0 |
| ElastiCache Serverless for Valkey | Managed, sized automatically. Billed for the data stored (at least 100 MB per cache) and for ElastiCache Processing Units (ECPUs; a simple read or write is 1 ECPU per KB) | Data: 0.1 GB × USD 0.101 per GB-hour = USD 7.37. ECPUs: USD 0.0027 per million, for example USD 0.03 for 10 million. About USD 7.4 |
| ElastiCache for Valkey, one `cache.t4g.micro` node | A node (0.5 GiB) without a replica | USD 0.02 per hour = USD 14.60 |

- **Prices:** From the AWS price list for ElastiCache in ap-northeast-1 (published 2026-10-28) and the 100 MB minimum for Valkey on the ElastiCache pricing page (checked on 2026-11-09). Valkey costs less than Redis OSS for the same node (`cache.t4g.micro` is USD 0.025 per hour for Redis OSS) and has a lower minimum on Serverless (1 GB for Redis OSS and Memcached).
- **Network:** The functions are in the VPC already, so they reach ElastiCache directly in the private subnets, without a VPC endpoint or a NAT instance. A security group allows the functions' security group.
- **In Rails:** `config.cache_store = :redis_cache_store` with the cache's endpoint (Valkey speaks the Redis protocol; ElastiCache Serverless requires TLS), and the same for `config.redmine_search_cache_store`. The `redis` gem is added to the image.
- **Not chosen now:** For a small team, about USD 7.4 or more per month is a large share of the base cost ([cost.md](cost.md)), for a cache that saves little. It can be added later without changing Redmine.

## To verify

- How many ECPUs Redmine's use would take in a month (the estimate above assumes 10 million)
- Whether ElastiCache Serverless adds a charge for the endpoints it creates in the VPC (not checked)
- How long the first connection to ElastiCache with TLS takes when a Lambda environment starts
