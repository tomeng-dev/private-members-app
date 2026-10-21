# Runbook — RDS restore from snapshot

1. Identify snapshot in RDS console (automated daily).
2. Restore to **new** instance (do not overwrite blindly).
3. Update Secrets Manager `DATABASE_URL` to new endpoint.
4. Bounce EB environment / restart instances to pick up secret.
5. Verify `/api/health` and a read-only query.
6. Document incident timeline.
