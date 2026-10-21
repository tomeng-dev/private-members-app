# Scheduled jobs

Stage 6 uses `@nestjs/schedule` with a MySQL `job_locks` table (`JobLockService`).

- Safe on a **single** API instance.
- On multiple instances, every node receives the cron tick; only the node that acquires the lock runs the work. No Redis required for Stage 6.
- Later: optional Redis/Redlock if lock contention becomes an issue.

Jobs:

| Name | Cadence | Purpose |
|---|---|---|
| `event-reminders-1d` | daily | Push/email members RSVP’d going for events in ~24h |
| `dues-reminders` | daily | Remind members with renewal in 14 days / overdue |
| `verification-doc-cleanup` | daily | Soft-delete verification media older than retention (default 30 days after decision) |

Set `SCHEDULE_ENABLED=false` to disable crons (tests / local).
