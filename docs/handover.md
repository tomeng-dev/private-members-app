# Handover — Private Members App (Phase 1)

**Audience:** Tomeng Sanchez and the client's future developers.

## System map
- `api/` NestJS 11 + Prisma 6 + MySQL — auth, applications, profiles, feed, messaging (Socket.IO `/realtime`), events/RSVP/QR, admin, notifications, jobs
- `app/` Flutter member (Android/iOS/Web)
- `admin/` Flutter Web staff dashboard
- `infra/terraform/` AWS VPC, EB, RDS, S3, CloudFront, SES, Secrets, alarms, GitHub OIDC
- `docs/` privacy, security, runbooks, Firebase/SES, scheduled jobs

## Local boot
See root `README.md`. Node **24**, MySQL, `STAFF_2FA_REQUIRED=false` locally.

## Critical invariants
- No public content; RBAC everywhere.
- QR tokens: HMAC, no PII.
- Payments: Stripe links only; admin marks paid.
- Push/mail adapters degrade without credentials.
- Last `super_admin` cannot be demoted.

## Where secrets live
Local `.env` (gitignored). Production: Secrets Manager via `loadSecretsIntoEnv()`.

## CI/CD
Workflows under `.github/workflows/` per `cicd-guide.md`. OIDC role from Terraform output `github_actions_role_arn`.
