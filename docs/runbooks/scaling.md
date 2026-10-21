# Runbook — Scaling

1. EB: raise Min/Max instances; prefer multiple AZs.
2. Enable Redis adapter for Socket.IO (`REALTIME_ADAPTER=redis`, `REDIS_URL`) — see `docs/realtime-redis-adapter.md`.
3. Job locks already use MySQL; at high multi-instance load consider Redlock.
4. RDS: enable Multi-AZ (prod tfvar), raise instance class.
5. CloudFront caches static assets; API remains dynamic.
