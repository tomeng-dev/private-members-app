# API — NestJS + Prisma + MySQL

Proprietary — all rights reserved. See the [root README](../README.md) for setup, dev login and CI/CD.

```bash
cp .env.example .env     # fill in values; never commit .env
npm ci
npx prisma migrate deploy && npx prisma db seed
npm run start:dev        # http://localhost:3000/api, Swagger at /docs
npm test && npm run test:e2e && npm run lint:ci
```

Layout: `src/modules/<feature>/{domain,application,infrastructure,presentation}`, shared adapters in
`src/infrastructure/` (Prisma, storage local/S3, mail console/SMTP/SES, push noop/FCM, realtime Socket.IO), seed in
`prisma/seed.ts`.
