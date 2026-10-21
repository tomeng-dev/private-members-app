# Security — threat model (STRIDE-lite) & ASVS-lite checklist

## STRIDE-lite

| Threat | Area | Mitigations |
|---|---|---|
| Spoofing | Auth | Argon2id, JWT + rotating refresh, staff TOTP, lockout after failures |
| Tampering | Media/QR | Private S3, signed URLs, HMAC QR without PII |
| Repudiation | Admin | Append-only audit log for admin/moderation/security actions |
| Information disclosure | API/logs | Safe error filter, PII redaction in structured logs, CORS allowlist, Swagger off in prod |
| Denial of service | Auth/API | Throttling, account lockout, ALB + budgets/alarms |
| Elevation of privilege | RBAC | Roles guard, last super_admin protection, IDOR checks on me/* resources |

## OWASP ASVS-lite (Phase 1 status)

| Control | Status | Notes |
|---|---|---|
| V2 Password security | Done | Policy + optional HIBP k-anonymity |
| V3 Session management | Done | Refresh rotation, reuse detection, session list/revoke |
| V4 Access control | Done | JWT + RolesGuard; export/delete scoped to `me` |
| V5 Validation | Done | class-validator whitelist DTOs |
| V7 Error handling | Done | No stack traces to clients; request IDs |
| V8 Data protection | Partial | Encryption at rest (RDS/S3 IaC); TLS via ALB/CloudFront |
| V9 Communications | Done | HTTPS only at edge (IaC) |
| V10 Malicious code | Partial | Dependency audit in CI; no virus scanner beyond noop port |
| V14 Config | Done | Secrets Manager loader; prod STAFF_2FA_REQUIRED |

## Production musts

- `STAFF_2FA_REQUIRED=true`
- `CORS_ORIGINS` explicit
- `SWAGGER_ENABLED=false`
- Secrets via Secrets Manager (`AWS_SECRETS_ENABLED=true`)
- JWT rotation: set `JWT_KID`, keep `JWT_ACCESS_SECRET_PREVIOUS` during rollout

## Dependency audit (2026-10-20)

`npm audit --omit=dev` reported high issues in Prisma 6 / `deepmerge-ts` and moderate in `@nestjs/swagger`→`js-yaml`. Fixes require major version jumps (`npm audit fix --force`). **Deferred** to a controlled Phase 2 upgrade window; CI still runs `npm audit` for visibility.
