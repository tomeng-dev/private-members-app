# Prisma + MySQL

- Stage 1–2 use **Prisma 6** with `provider = "mysql"` and `url = env("DATABASE_URL")` in `api/prisma/schema.prisma`.
- Never switch this project to PostgreSQL.
- Prisma 7: add `prisma.config.ts` + `@prisma/adapter-mariadb` (or MySQL adapter); keep MySQL.
- A root `prisma.config.ts` was intentionally omitted on Prisma 6 because the CLI attempts to parse it and breaks `prisma generate`.
