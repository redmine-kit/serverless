# Cache

Each Lambda environment keeps Redmine's cache in its own memory. No shared cache service (such as ElastiCache) is used. Sessions do not use the cache ([session.md](session.md)).

## What Redmine caches

Redmine 7.0.3 uses the cache in only a few places (checked in the code on 2026-11-09).

| What | Where in Redmine | Store | When |
| --- | --- | --- | --- |
| Formatted text (wiki pages, issue descriptions and notes rendered to HTML) | `Redmine::WikiFormatting.to_html` | `config.cache_store` | Only when "Cache formatted text" is on (Administration › Settings › General; `cache_formatted_text`, off by default), and only for text over 2 KB |
| Search results (the IDs of the results, for paging through them) | `Redmine::Search` | Redmine's own store, `config.redmine_search_cache_store` (memory, up to 32 MB) | Every search |
| The list of languages for the language selector | `Redmine::I18n` | `config.cache_store` | The first time it is shown |
| Repository pages | `RepositoriesController` | `config.cache_store` | Not used: repositories are turned off on Lambda ([lambda.md](lambda.md#features-that-cannot-be-used)) |

## The design: memory in each environment

| Item | Value |
| --- | --- |
| `config.cache_store` | `:memory_store`, up to 64 MB per environment (`image/config/additional_environment.rb`) |
| `config.redmine_search_cache_store` | Redmine's default, `:memory_store` (32 MB) |
| Cost | None |

The Rails 8.1 default would be files in `tmp/cache/`, which is in `/tmp` on Lambda and would grow without limit ([lambda.md](lambda.md#read-only-file-system)).

With memory, each environment has its own cache, and a new environment starts empty. A page served by another environment computes the formatted text again, and paging through search results in another environment runs the search again. The results are the same; only the time differs. For a small team this costs little: formatted text is cached only when the setting is on and the text is long, and a search is run again only when the next page goes to another environment.

## What can be tuned

| What | Where | Effect |
| --- | --- | --- |
| Caching formatted text | Administration › Settings › General › "Cache formatted text" | On: long text (over 2 KB) is rendered once per environment. Worth turning on when wiki pages are long. Off (the default): every page view renders the text |
| Size of the cache | `config.cache_store = :memory_store, { size: … }` in `image/config/additional_environment.rb` | The memory store drops the least recently used entries when it is full. The functions have 2,048 MB ([lambda.md](lambda.md#function-settings)); the cache is a small part of it. Raise it if long wiki pages are cached and the environment's memory use leaves room (CloudWatch shows the maximum memory used per invocation) |
| How long entries live | `expires_in:` on the same line | Not set: entries live as long as the environment. Formatted text is keyed by the text's digest, so it does not go stale when the text changes |
| Size of the search cache | `config.redmine_search_cache_store = :memory_store, { size: … }` in `additional_environment.rb` | Redmine sets it in `config/application.rb` before `additional_environment.rb`, so a value there replaces Redmine's. `nil` turns search caching off |
| How long environments live | Provisioned Concurrency, or the warm-up invocations (`lambda.warmup` in [deploy-config.md](deploy-config.md#fields-of-redminejson)) | The cache lives as long as its environment. Environments that are kept warm keep their cache; an environment that Lambda starts for a burst of requests starts empty. Provisioned Concurrency costs about USD 23 a month per 2 GB environment ([cost.md](cost.md#what-adds-cost)) |
| A shared cache | `config.cache_store` and `config.redmine_search_cache_store` pointing at ElastiCache (below) | Every environment uses the same entries, and new environments start with them |

How often an entry is found has not been measured yet. Rails reports cache reads (`cache_read.active_support`) to ActiveSupport notifications, which can be logged while trying it out.

## When a shared cache is worth it

A shared cache keeps the formatted text and the search results for all environments. It is worth considering when the formatted-text cache is turned on for long wiki pages, or when many people page through search results.

| Option | What it is | Monthly cost (Tokyo, 730 hours) |
| --- | --- | --- |
| Memory in each environment (this design) | `:memory_store` | USD 0 |
| ElastiCache Serverless for Valkey | Managed, sized automatically. Billed for the data stored (at least 100 MB per cache) and for ElastiCache Processing Units (ECPUs; a simple read or write is 1 ECPU per KB) | Data: 0.1 GB × USD 0.101 per GB-hour = USD 7.37. ECPUs: USD 0.0027 per million, for example USD 0.03 for 10 million. About USD 7.4 |
| ElastiCache for Valkey, one `cache.t4g.micro` node | A node (0.5 GiB) without a replica | USD 0.02 per hour = USD 14.60 |

The prices come from the AWS price list for ElastiCache in ap-northeast-1 (published 2026-10-28) and the 100 MB minimum for Valkey on the ElastiCache pricing page (checked on 2026-11-09). Valkey costs less than Redis OSS for the same node (`cache.t4g.micro` is USD 0.025 per hour for Redis OSS) and has a lower minimum on Serverless (1 GB for Redis OSS and Memcached).

The functions are in the VPC already, so they reach ElastiCache directly in the private subnets, without a VPC endpoint or a NAT instance; a security group allows the functions' security group. In Rails, set `config.cache_store = :redis_cache_store` with the cache's endpoint (Valkey speaks the Redis protocol; ElastiCache Serverless requires TLS), set `config.redmine_search_cache_store` the same way, and add the `redis` gem to the image.

It is not chosen now. For a small team, about USD 7.4 or more per month is a large share of the base cost ([cost.md](cost.md)), for a cache that saves little, and it can be added later without changing Redmine.

## To verify

- How often entries are found in each environment's cache with Redmine's use (not measured)
- How many ECPUs Redmine's use would take in a month (the estimate above assumes 10 million)
- Whether ElastiCache Serverless adds a charge for the endpoints it creates in the VPC (not checked)
- How long the first connection to ElastiCache with TLS takes when a Lambda environment starts
