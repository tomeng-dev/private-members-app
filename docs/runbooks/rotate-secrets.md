# Runbook — Rotate secrets

1. Generate new `JWT_ACCESS_SECRET`; set `JWT_ACCESS_SECRET_PREVIOUS` to old; bump `JWT_KID`.
2. Update Secrets Manager JSON; EB picks up on instance refresh (or restart).
3. Wait for access-token TTL to expire; then remove previous secret.
4. Rotate DB password via RDS + Secrets Manager together.
5. Rotate `QR_HMAC_SECRET` only in a maintenance window (invalidates outstanding QR codes).
