# Security Policy

## Reporting a vulnerability

Please **do not open a public GitHub issue** for security problems.

Report privately through GitHub's **"Report a vulnerability"** button (Security tab → Advisories) on this repository,
or contact the repository maintainers directly. Include:

- what you found and where (file, endpoint, or screen),
- steps to reproduce or a proof of concept,
- the impact you believe it has.

We aim to acknowledge reports within 3 business days and to share a fix timeline after triage. Please give us a
reasonable time to fix the issue before any disclosure, and do not access, change or delete data that is not yours.

## Scope

In scope: the API (`api/`), the member app (`app/`), the admin console (`admin/`), infrastructure code (`infra/`)
and the CI/CD workflows (`.github/`).

## No secrets in this repository

- Real secrets (JWT/HMAC/storage signing keys, database passwords, AWS credentials, Firebase/APNs keys, Android
  keystores, seed passwords) are **never** committed. Production secrets live in AWS Secrets Manager and GitHub
  Environment secrets; local values live in untracked `.env` files.
- Only `*.example` files (`.env.example`, `*.tfvars.example`) are tracked, and they contain placeholders only.
- `.gitignore` excludes `.env*`, keystores, `key.properties`, `google-services.json`, `GoogleService-Info.plist`,
  private keys, Terraform state and `*.tfvars`.
- Seed credentials come from `SEED_ADMIN_PASSWORD` / `SEED_INVITE_CODE`; the seed refuses to run in production or
  staging without them.

If you find a secret committed here, report it as above. Maintainers will rotate it immediately — removing it from
history alone is not enough.

## For contributors

Run a secret scan before pushing, for example:

```bash
gitleaks git . --no-banner        # history
gitleaks dir . --no-banner        # working tree
```
