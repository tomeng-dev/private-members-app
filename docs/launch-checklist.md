# Launch checklist (stores + ops)

## Accounts & keys (Tomeng / client)
- [ ] Apple Developer + App Store Connect (invite-only notes)
- [ ] Google Play Console (internal testing track)
- [ ] Firebase project + Android/iOS/Web apps; APNs key uploaded
- [ ] AWS account; Terraform applied (staging then prod)
- [ ] SES production access / domain verified
- [ ] Stripe Payment Links for dues + event fee (no card storage)
- [ ] GitHub org secrets + Environments approvals

## Privacy nutrition / data safety (draft answers)
- Data collected: name, email, phone (optional), photos, messages, location **not** collected continuously
- Linked to user: yes (account)
- Tracking: **no** advertising trackers in Phase 1
- Encryption in transit: yes; at rest: yes (RDS/S3)
- Account deletion: in-app + grace period

## Screenshots to capture
Welcome, Apply, Feed, Event detail + RSVP, Ticket QR, Messages, Directory, Profile, Admin overview

## Demo reviewer account
Create `reviewer@…` approved member with sample vehicles/events; document password in 1Password (not git).

## Versioning
Use `app`/`admin` `pubspec` version + API git tag `v1.0.0`. Release notes from `docs/release-notes-template.md`.
