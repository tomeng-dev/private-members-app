# Dev environment

Recorded: 19 October 2026 (Asia/Manila) — Stage 2

## Runtime

| Tool | Version / notes |
|---|---|
| **Node.js** | **v24.22.0 LTS** via nvm (`api/.nvmrc` = `24`). Node 20 is EOL (April 2026) — do not use it. |
| npm | 11.19.x (ships with Node 24) |
| MariaDB | 11.8.x (MySQL-compatible) or Docker `mysql:8.4` from compose |
| Flutter | 3.35.6 stable + web |
| sharp | Native image pipeline (EXIF strip + thumbnails) on the API host |
| AWS SDK v3 | `@aws-sdk/client-s3` + presigner (used when `STORAGE_PROVIDER=s3`) |

## Install Node 24 with nvm

```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
unset NPM_CONFIG_PREFIX   # if set, nvm will refuse to switch
export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh"
nvm install 24
nvm use 24
node -v   # expect v24.x
```

Windows: install nvm-windows or use the Node 24 LTS MSI from nodejs.org, then match `api/.nvmrc`.

## Elastic Beanstalk

Use a **Node.js 24** platform branch (or the newest Node 24 AL2023 solution stack). `api/.nvmrc` and `package.json#engines` declare `>=24 <25`. The migrate hook (`api/.ebextensions/01-migrate.config`) runs `npx prisma migrate deploy` and requires `prisma` in production dependencies.

## Storage

- Default: `STORAGE_PROVIDER=local` (signed local URLs; good for tests).
- Production-ready path: `STORAGE_PROVIDER=s3` + `S3_BUCKET` + AWS credentials/role. Objects stay private; clients receive short-lived signed GET/PUT URLs (CloudFront can wrap later).
- Image processing runs in-process with **sharp** in Stage 2; production may move resize to Lambda (same EXIF-strip contract).

## Not on this box

Android SDK / Xcode — web builds verify Flutter here.
