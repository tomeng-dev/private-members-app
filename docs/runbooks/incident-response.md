# Runbook — Incident response

1. **Detect:** SNS alarm / user report.
2. **Triage:** severity (auth breach > data leak > availability).
3. **Contain:** revoke sessions (`POST /auth/sessions/revoke-all` for impacted users), rotate JWT, disable public routes if needed.
4. **Eradicate:** patch, deploy, audit log review.
5. **Recover:** restore service, confirm health.
6. **Notify:** client + counsel if personal data involved (CCPA/PH DPA timelines).
