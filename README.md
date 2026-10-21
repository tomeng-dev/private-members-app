# Private Members App

> **Proprietary — all rights reserved.** This repository is published for collaboration and review only.
> No license is granted to use, copy, modify or distribute this code. See [Copyright](#copyright).

A private, invite- and approval-only social app for owners of luxury and exotic cars (vehicles valued at $200k+).
Members share posts and media, message each other, and RSVP to club events (calendar, speakers, roundtables,
QR check-in, archives). Staff run membership, verification, dues, moderation and events from a separate admin console.
Payments are handled outside the app (payment links); the admin marks dues as paid.

Phase 1 (Stages 1–7 plus a UX round) is implemented. Phase 2 (auctions, marketplace, fundraisers, pitch meetings) is
planned, not built.

## Repository layout

| Folder | What |
|---|---|
| `api/` | NestJS 11 + TypeScript + Prisma 6 + **MySQL** (MariaDB OK locally). Clean architecture: domain / application / infrastructure / presentation |
| `app/` | Flutter member app (Android, iOS, Web), Riverpod + go_router, feature-first clean architecture — `com.privatemembers.app` |
| `admin/` | Flutter Web admin console — `com.privatemembers.admin` |
| `infra/` | Terraform for AWS (VPC, RDS, Elastic Beanstalk, S3, CloudFront, SES, Secrets Manager, GitHub OIDC) and IAM policy JSON |
| `docs/` | Dev environment, security, privacy, runbooks, launch checklist, handover |
| `.github/` | CI/CD workflows and Dependabot |
| `CLAUDE.md` | Project rules for AI-assisted development (architecture, security, design system) |

## Prerequisites

- **Node.js 24 LTS** (`api/.nvmrc`) and npm
- MySQL 8.4 **or** MariaDB 10.11+ (a `docker-compose.yml` with MySQL + Mailpit is included)
- Flutter stable 3.35+ with web enabled
- Windows: PowerShell or Git Bash works. Android emulator API URL: `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api`

## Quick start

### 1. Database

```bash
cp .env.example .env          # docker compose reads this; set your own DB passwords
docker compose up -d          # or create the DB/user on a local MySQL (docs/dev-environment.md)
```

### 2. API

```bash
cd api
cp .env.example .env          # then fill in the values (see "Dev login" below)
npm ci
npx prisma migrate deploy
npx prisma db seed
npm run start:dev
```

- API: http://localhost:3000/api · Swagger: http://localhost:3000/docs · Health: http://localhost:3000/api/health

### 3. Member app

```bash
cd app
flutter pub get
# Development build: shows the dev quick-login panel and a DEV BUILD badge
flutter run -d chrome --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:3000/api \
  --dart-define=DEV_MEMBER_PASSWORD=<same as DEV_DEFAULT_MEMBER_PASSWORD>
# Production-like build (default when APP_ENV is omitted): no dev shortcuts compiled in
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com/api
```

### 4. Admin console

```bash
cd admin
flutter pub get
flutter run -d chrome --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

## Dev login (local / non-production only)

**No passwords or invite codes are stored in this repository.** You choose them in your untracked `api/.env`;
`api/.env.example` lists every key with placeholder or empty values.

| Key in `api/.env` | Used for | If empty |
|---|---|---|
| `SEED_ADMIN_PASSWORD` | Super-admin account (`SUPER_ADMIN_EMAIL`, default `admin@example.com`) | Dev: the seed generates one and prints it once. **Production/staging: the seed refuses to run.** |
| `SEED_INVITE_CODE` | Invite code applicants enter on the apply form | Dev: generated and printed. **Production/staging: the seed refuses to run.** |
| `DEV_DEFAULT_MEMBER_PASSWORD` (≥ 10 chars) | Password for the seeded demo members and for members approved in development | Demo members are skipped and the dev quick-login list is off |

Demo members (created only when `NODE_ENV`/`APP_ENV` are not production):

| Account | Role / state | Use it to see |
|---|---|---|
| `member1@example.com` — Alexander Whitmore | Founding member, active | Feed, events (attending + ticket), chat, notifications |
| `member2@example.com` — Isabella Laurent | Active, moderator | Moderator view, DM with member1 |
| `member3@example.com` — Marcus Chen | Active, **dues due** | Dues reminders; Dues view in admin |
| `member4@example.com` — Victoria Hale | **Suspended**, overdue | Suspended-account handling (login refused) |
| `member5@example.com` — Sophia Castellano | Pending applicant (no account yet) | Approve in admin → account created |

**How dev shortcuts are kept out of production**

- *Member app:* the quick-login panel exists only with `--dart-define=APP_ENV=development`. It is a compile-time
  constant that defaults to `production`, so the code is tree-shaken from release builds. The demo password is never
  baked in; pass it with `--dart-define=DEV_MEMBER_PASSWORD=...` or type it.
- *API:* `GET /api/dev/accounts` returns **404** when `NODE_ENV=production`, `APP_ENV=production` or `APP_ENV=staging`,
  or when `DEV_DEFAULT_MEMBER_PASSWORD` is unset/short. It lists demo accounts only and never returns a password.
- *Approvals:* in development an approval also sets the default member password (and still logs the set-password
  link). In production the applicant only receives the set-password email.
- Guard tests: `api/src/modules/dev/dev.controller.spec.ts`, `app/test/dev_login_guard_test.dart`.

## Tests

```bash
cd api && npm test && npm run test:e2e && npm run lint:ci   # Vitest unit + Nest e2e (needs MySQL + seeded DB)
cd ../app && flutter analyze && flutter test
cd ../admin && flutter analyze && flutter test
```

The API e2e tests read `SEED_ADMIN_PASSWORD` and `SEED_INVITE_CODE` from `api/.env` (or the CI environment), so run
`npx prisma db seed` with the same values first.

## CI/CD (GitHub Actions)

| Workflow | Trigger | What it does |
|---|---|---|
| `api-ci.yml` | PR / push touching `api/` | Lint → Prisma validate → migrate a throw-away MySQL → seed (random per-run credentials) → unit + e2e → build → `npm audit` |
| `flutter-ci.yml` | PR / push touching `app/` or `admin/` | `flutter analyze`, tests, web build |
| `deploy-api.yml` | Push to `main` touching `api/`, or manual | Builds the API bundle and deploys to Elastic Beanstalk via **GitHub OIDC** (no long-lived AWS keys) |
| `deploy-web.yml` | Push to `main` touching `app/`/`admin/`, or manual | Builds the Flutter web apps and syncs to S3 + CloudFront invalidation |
| `mobile-release.yml` | Manual, or tag `mobile-v*` | Android (signed with a keystore restored from GitHub Environment secrets) and iOS (fastlane) |

All deploy credentials live in GitHub Environments/Secrets and AWS Secrets Manager — never in the repo. IAM trust and
permission policies are in `infra/iam/`; the Elastic Beanstalk migrate hook is `api/.ebextensions/01-migrate.config`.

## Security

See [SECURITY.md](SECURITY.md) and [docs/security.md](docs/security.md). Highlights: argon2id passwords, short-lived
JWT access + rotating refresh tokens with reuse detection and `kid` rotation, RBAC (member / moderator / admin /
super_admin), TOTP 2FA for staff, rate limits, Helmet, CORS allowlist, audit log, HMAC QR tickets, EXIF/GPS stripping.

## More docs

- [docs/dev-environment.md](docs/dev-environment.md) — local setup
- [docs/firebase-ses-setup.md](docs/firebase-ses-setup.md) — push and email providers
- [docs/android-signing.md](docs/android-signing.md) — release signing (`key.properties`, never committed)
- [docs/scheduled-jobs.md](docs/scheduled-jobs.md), [docs/realtime-redis-adapter.md](docs/realtime-redis-adapter.md)
- [docs/launch-checklist.md](docs/launch-checklist.md), [docs/handover.md](docs/handover.md), [docs/progress.md](docs/progress.md)

## Copyright

Copyright © 2026 the project owner. **Proprietary — all rights reserved.** No license is granted. Viewing this public
repository does not grant any right to use, copy, modify, or distribute the code.
