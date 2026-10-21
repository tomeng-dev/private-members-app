# Runbook — Rollback

## API (Elastic Beanstalk)
1. EB console → environment → Deployments → Redeploy previous version label.
2. Or `eb deploy` previous application version from CI artifacts.
3. If migration is forward-only and unsafe, restore RDS snapshot first (see db-restore).

## Web
1. Re-upload previous `build/web` artifact to S3.
2. Invalidate CloudFront `/*`.
