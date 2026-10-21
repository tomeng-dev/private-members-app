# Runbook — Deploy

1. Merge to `main` after green CI.
2. GitHub Action `deploy-api.yml` → EB staging; approve production.
3. `deploy-web.yml` builds Flutter web → S3 + CloudFront invalidation.
4. Smoke: `GET https://api.<domain>/api/health`, login, feed, socket connect.
5. Watch CloudWatch 5xx / latency for 30 minutes.
