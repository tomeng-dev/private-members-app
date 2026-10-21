# Project rules for Claude Code

## Product
- Private invite/approval-only social app for luxury/exotic car owners ($200k+ vehicles).
- Audience: executives (often older); UI must be large-text, simple, black/white/gold.
- Five bottom tabs only: Home, Events, Members, Messages, Profile.
- No public content. No algorithmic feed. Chronological only.
- Payments are external (Stripe Payment Links). Admin marks dues paid. No in-app charging in Phase 1.

## Stack
- API: **Node.js 24 LTS** + TypeScript, NestJS, Prisma ORM, **MySQL** (MariaDB OK locally). Never PostgreSQL.
- Apps: Flutter (Android, iOS, Web). Admin: Flutter Web.
- Media: storage port with **local** + **S3** adapters; sharp EXIF/GPS strip + thumbnails in API (Lambda optional in prod).
- Push: FCM. Email: SES (console mailer in Stage 1). Region: us-east-1.
- Passwords: **argon2id** via `@node-rs/argon2`.

## Architecture
- Clean architecture. Domain depends on nothing.
- API feature modules: domain / application / infrastructure / presentation (Nest controllers).
- Flutter: `core/` + `features/<feature>/{data,domain,presentation}` with Riverpod.
- Wire ports with Nest DI tokens (`STORAGE_PORT`, `MAIL_PORT`, `PUSH_PORT`, `REALTIME_ADAPTER_PORT`).
- Real-time: Socket.IO namespace `/realtime`, JWT on handshake; single-instance in-memory adapter now; Redis later (`docs/realtime-redis-adapter.md`).
- Moderators **cannot** read private DMs; only reported message snapshots appear in the reports queue.
- Event QR tickets: HMAC tokens (`QR_HMAC_SECRET`) with opaque RSVP id only — never name/email in the code.
- Attendance lists and directory event-filter respect `showEventsAttended`.
- Staff 2FA: TOTP + recovery codes when `STAFF_2FA_REQUIRED=true` (admin/moderator/super_admin).
- Push/Mail: `PUSH_PORT` / `MAIL_PORT` with noop|fcm and console|smtp|ses; never commit Firebase/AWS secrets.
- Scheduled jobs use MySQL `job_locks` (`docs/scheduled-jobs.md`). Verification media purged after retention.
- Cannot demote the last `super_admin`.

## Conventions
- TypeScript strict-ish; small modules.
- REST JSON + class-validator DTOs.
- Prisma migrations only — no hand-edited prod schema.
- App IDs: member `com.privatemembers.app`, admin `com.privatemembers.admin`.

## Security (non-negotiable)
- JWT access (short) + rotating refresh tokens (hashed at rest); reuse detection.
- RBAC: member | moderator | admin | super_admin.
- Rate limit auth/write. Helmet. CORS allowlist. Safe error filter.
- Audit log every admin/security action.
- No secrets in git. `.env` never committed; use `.env.example`.
- Android release signing via `key.properties` (gitignored), not debug keys.

## Testing
- **Vitest + unplugin-swc** for API unit and Nest e2e (not Jest). Nest 11 ESM packages break Jest’s CJS loader.
- Unit: `src/**/*.spec.ts`. E2E: `test/**/*.e2e-spec.ts` via `npm run test:e2e`.
- Optional HTTP smoke: `npm run test:e2e:smoke`.
- Flutter widget/use-case tests; `flutter analyze` clean.

## How to change code
1. Read existing files before editing.
2. One feature per change.
3. Update `.env.example` when adding config keys.
4. Do not invent client brand names or fake legal text.


## Stage 7 notes
- Production: `STAFF_2FA_REQUIRED=true`, Secrets Manager via `loadSecretsIntoEnv()`, Swagger off.
- Privacy: `GET /me/export`, `POST /me/delete` (+ cancel), grace job `accountDeletionFinalize`.
- Terraform under `infra/terraform` — never commit real tfstate/secrets.
- Flutter push: `isFirebaseConfigured` guard in `app/lib/firebase_options.dart`.

## Design system (UX round)
Both apps share one visual language: a quiet, "private club after dark" look with Playfair Display headings, Inter for
UI and body text, and a single gold accent (`#C9A961`). In light mode the accent becomes deep gold `#8A6A25` for text so
it keeps AA contrast. Dark is the default (evening events, low glare); a light theme exists and is persisted per device.
Fonts are bundled as assets, so there are no runtime font downloads. Use tokens and components; never hard-code
colours, radii or durations in feature code.

**Member app** (`app/lib/core/theme`, `app/lib/core/ui`, barrel `core/ui/ui.dart`)
- Tokens (`tokens.dart`): `AppSpacing` (2/4/8/12/16/24/32/48, page gutter 20), `AppRadii` (8/12/16/24/pill),
  `AppElevation`, `AppMotion` (150/250/400 ms), `AppBreakpoints` (600 = bottom nav → rail, 900 = sidebar; feed max
  680, content 1120, forms 460). Colours live in `AppColors` and the `LuxTokens` ThemeExtension (`context.lux`).
- Components: `LuxButton` (primary/secondary/ghost, `loading`), `LuxCard`, `LuxTextField`, `MemberAvatar` +
  `FoundingBadge`, `CoverArt` / `DateBadge` (generated event art, no stock photos), `EmptyState` / `ErrorState` /
  `ErrorBanner` / `Skeleton*`, `showToast`, `CenteredContent`, `AppBackButton` (falls back to a route when there is
  no history, e.g. on deep links).
- Navigation: `HomeShell` switches between a bottom bar (<600), a rail (600–900) and a sidebar (≥900). The feed shows
  a "Coming up" rail at ≥1280.
- Motion: short fades and slides only, using `AppMotion` durations. Respect `MediaQuery.disableAnimations`.
- Accessibility: tap targets ≥48 px; every icon-only button has a tooltip or semantics label; theme contrast is
  covered by `test/theme_contrast_test.dart`.
- Never use `CrossAxisAlignment.stretch` in a horizontal Flex inside a `bottomNavigationBar`: its height is unbounded
  (regression test: `test/event_detail_layout_test.dart`).

**Admin console** (`admin/lib/core/theme`, `admin/lib/core/ui`, barrel `core/ui/ui.dart`)
- `AppTheme.dark` / `.light` with the `AdminTokens` ThemeExtension (`context.tokens`); `Gap` / `Radii` scales.
- Shell (`features/admin/presentation/shell.dart`): a grouped, collapsible sidebar (Overview · Membership · Events ·
  Community · Administration) with live badges, global search (Ctrl/⌘K), an environment badge (DEV/STAGING/PROD from
  the API) and a profile menu (theme toggle, sign out).
- `widgets.dart`: `PageScaffold`, `SectionCard`, `KpiCard`, `StatusChip` + `toneForStatus`, `Avatar`, `EmptyView`,
  `ErrorView`, `SkeletonBox` / `TableSkeleton`, `showToast`, `confirmAction` (optional mandatory reason), `InfoRow`,
  and the formatters `humanize`, `fmtDate`, `fmtRelative` and `fmtUsd`.
- `data_table.dart`: `AdminDataTable` is server-driven. It is paged via `TableQueryState` and supports sortable
  headers, row selection, an active row, and horizontal scroll when narrow. Companions: `TableSearchField`
  (debounced), `ColumnVisibilityButton`, `BulkActionBar` and `FacetChip`. List endpoints accept
  `page, pageSize, sort, order, q` plus comma-separated filters (`membershipStatus=dues_due,overdue`,
  `role=admin,super_admin`). Unknown sort keys or filter values are ignored, never echoed into the query.
- Destructive or bulk actions always go through `confirmAction`. Suspensions and declines require a reason, and every
  console mutation is audit-logged server-side.
- Charts use `fl_chart`. Don't wrap charts in `IntrinsicHeight` (their LayoutBuilder breaks).

**Dev shortcuts.** `AppConfig.isDevelopment` is a compile-time constant
(`--dart-define=APP_ENV=development`, default production). Gate dev-only UI behind it so it is tree-shaken from
release builds. On the API, use `isProductionEnv()` / `devDefaultMemberPassword()` from
`common/env/runtime-env.ts`; never add a dev route that bypasses them.
