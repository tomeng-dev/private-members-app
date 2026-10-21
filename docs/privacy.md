# Privacy data map (Phase 1)

**For counsel review — not legal advice.** US (CCPA/CPRA) and Philippines Data Privacy Act (RA 10173) may both apply depending on residency and processing location.

## Categories

| Category | Examples | Purpose | Retention | Processors |
|---|---|---|---|---|
| Identity | Name, email, phone, company | Membership, directory | Account life + grace | AWS RDS |
| Credentials | Password hash, TOTP secret | Auth | Account life | AWS RDS |
| Vehicle | Make/model/year, verification docs | Eligibility | Docs purged ~30d after decision | AWS S3 |
| Content | Posts, comments, messages, media | Club social | Until delete / account anonymize | AWS S3/RDS |
| Events | RSVPs, check-ins | Events ops | Event archive | AWS RDS |
| Devices | FCM tokens | Push | Until revoke/delete | Firebase / RDS |
| Billing refs | External payment refs (no card data) | Dues tracking | Membership | Stripe links (external) |
| Consent | Privacy/terms version stamps | Compliance | Application record | AWS RDS |

## Member rights (app support)

- **Export:** `GET /api/me/export` (JSON)
- **Delete:** `POST /api/me/delete` → grace period (default 14 days) → anonymize + media delete job; `POST /api/me/delete/cancel` during grace
- **Notification prefs:** `/api/me/notification-preferences`

## Notices

Consent captured at application (`consentPrivacyVersion` / `consentTermsVersion`). Update `PRIVACY_VERSION` / `TERMS_VERSION` env when policies change.
