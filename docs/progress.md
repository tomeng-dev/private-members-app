# Progress — Phase 1 complete (Stages 1–7) + UX round

**Updated:** 21 October 2026 (Asia/Manila)

## Requirement status summary

| Status | Count (approx) |
|---|---|
| Done | Majority of Phase 1 functional IDs (AUTH/APP/PRO/FED/MSG/EVT/CHK/DIR/NOT/ADM + NFR security/privacy/IaC) |
| Partial | See list below |
| Deferred | See list below |

### Partial
| ID / topic | Reason |
|---|---|
| Push (Flutter Firebase) | `firebase_core`/`firebase_messaging` integrated with **config guard**; needs `flutterfire configure` + platform files before live push |
| V10 malicious uploads | Virus-scan port exists (noop); production scanner not wired |
| Unit coverage overall | ~34% statements; critical paths have unit+e2e but not full service coverage |
| npm audit highs | Prisma `deepmerge-ts` / swagger `js-yaml` need major upgrades (breaking) — tracked for early Phase 2 |
| Admin cover upload | Storage key UX (not full picker) |

### Deferred (Phase 2 / ops)
| Topic | Reason |
|---|---|
| Real AWS apply | No credentials on this box — Terraform validate only |
| Redis Socket.IO | Documented; enable at scale |
| In-app payments | Stripe Payment Links only by design |
| Full k6 soak on prod-like | Script + notes provided; run on staging |
| Store submission | Manual Apple/Google steps for Tomeng |

## Stage 7 (M9) delivered
Security hardening, privacy export/deletion grace, Secrets Manager loader, JWT kid rotation, lockout, HIBP toggle, sessions revoke, FCM Flutter guard, Terraform (validate green), runbooks, launch/handover docs, load smoke script, coverage report.

## UX round delivered (21 Oct 2026)
- **A. Dev password login.** Seeded demo members `member1…5@example.com`. `DEV_DEFAULT_MEMBER_PASSWORD` is documented
  in `.env.example`. Dev approvals set the default password and still log the set-password link. The member app's
  quick-login panel only exists with `APP_ENV=development` (compile-time; absent from production JS).
  `/api/dev/accounts` 404s in production/staging. The production flow (set-password email) is unchanged. Guard tests
  exist on both the API and Flutter sides.
- **B. Member app redesign.** Tokens and a component library; responsive nav (bottom bar / rail / sidebar); redesigned
  welcome, login, apply, feed (with a desktop "Coming up" rail), events (list/calendar/past), event detail (desktop
  RSVP card, mobile bottom bar), ticket, members directory, profile, chat and notifications; deep-link-safe back
  buttons; motion and accessibility pass.
- **C. Admin console redesign.**
  - Shell and overview: a grouped, collapsible sidebar with badges; global search (Ctrl/⌘K); an env badge; a profile
    menu with a light/dark toggle. The Overview has KPIs, fl_chart charts (applications/week, a membership donut,
    RSVP capacity, check-ins), pending tasks and recent activity.
  - Data views: server-side tables (Applications, Members, Dues, Staff & roles) with paging, sort, search, facets,
    column visibility, selection and bulk approve/decline/suspend/reinstate, plus CSV export. The member detail drawer
    has Profile/Vehicles/Dues/Activity/Audit tabs. Events is a card grid with a validated create dialog.
  - Moderation, broadcast and audit: content and message report queues with in-context previews, segment broadcast
    (dry-run reach, preview, confirm), an audit log with filters and CSV, and Settings.
  - New RBAC'd, audit-logged endpoints live under `/api/admin/console/*`.
- **D. Screenshots** were captured locally (not in the repo) (member mobile 390×844, member desktop 1440×900, admin
  1440×900). They were reviewed and iterated; fixes include table column widths, the search field height, drawer
  chip labels, the event card layout, StatusChip ellipsis, and the mobile RSVP bar stretch bug.

## Test counts (final box)
| Suite | Result |
|---|---|
| API unit | **25 files / 61 tests** (lint clean, `tsc` clean, `nest build` OK) |
| API e2e | **15 tests** |
| API coverage (stmts) | ~34% (not re-measured this round) |
| Flutter app | analyze clean, **41 tests**, web build OK (dev + production) |
| Flutter admin | analyze clean, **12 tests**, web build OK (dev + production) |
| Terraform | `fmt` + `validate` **Success** |

## Deliverable
Delivered as a zip during Phase 1; now tracked in this repository.
