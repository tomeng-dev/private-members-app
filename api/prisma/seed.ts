import { PrismaClient, RoleName, UserStatus } from '@prisma/client';
import { hash } from '@node-rs/argon2';
import { randomBytes } from 'node:crypto';

const prisma = new PrismaClient();

async function main() {
  // Validate credentials before any DB write, so production never gets a half-seeded state.
  const { password, generated: generatedPassword } = seedAdminPassword();
  const { code: inviteCode, generated: generatedInvite } = seedInviteCode();

  const roles: { name: RoleName; description: string }[] = [
    { name: RoleName.member, description: 'Approved member' },
    { name: RoleName.moderator, description: 'Content moderator' },
    { name: RoleName.admin, description: 'Club staff admin' },
    { name: RoleName.super_admin, description: 'Owner / lead administrator' },
  ];
  for (const r of roles) {
    await prisma.role.upsert({
      where: { name: r.name },
      create: r,
      update: { description: r.description },
    });
  }

  const email = (process.env.SUPER_ADMIN_EMAIL ?? 'admin@example.com').toLowerCase();
  const firstName = process.env.SUPER_ADMIN_FIRST_NAME ?? 'Super';
  const lastName = process.env.SUPER_ADMIN_LAST_NAME ?? 'Admin';
  const passwordHash = await hash(password, {
    memoryCost: 19456,
    timeCost: 2,
    parallelism: 1,
  });

  const superRole = await prisma.role.findUniqueOrThrow({
    where: { name: RoleName.super_admin },
  });
  const adminRole = await prisma.role.findUniqueOrThrow({
    where: { name: RoleName.admin },
  });

  const admin = await prisma.user.upsert({
    where: { email },
    create: {
      email,
      passwordHash,
      firstName,
      lastName,
      status: UserStatus.active,
      membershipStatus: 'active',
      foundingMember: false,
      roles: {
        create: [
          { roleId: superRole.id },
          { roleId: adminRole.id },
        ],
      },
    },
    // A generated (dev-only) password is set on first create only, so re-seeding never
    // silently rotates a password you are already using.
    update: generatedPassword
      ? { status: UserStatus.active }
      : { passwordHash, status: UserStatus.active },
  });

  // Demo invite (clearly marked)
  await prisma.invite.upsert({
    where: { code: inviteCode },
    create: {
      code: inviteCode,
      createdById: admin.id,
      maxUses: 100,
      status: 'active',
      emailHint: 'seeded invite',
    },
    update: { status: 'active', maxUses: 100 },
  });

  await seedDemo(admin.id);

  console.log('Seed complete.');
  console.log(`  Super admin: ${email}`);
  if (generatedPassword) {
    console.log(`  Super admin password (generated, dev only — set SEED_ADMIN_PASSWORD to fix it): ${password}`);
  }
  console.log(
    `  Invite code: ${inviteCode}${generatedInvite ? ' (generated, dev only — set SEED_INVITE_CODE to fix it)' : ''}`,
  );
}

/** Values that must never be used as real credentials (copied from .env.example). */
const PLACEHOLDER = /^(change[-_ ]?me|replace|placeholder|example)/i;

/**
 * Super-admin password: SEED_ADMIN_PASSWORD (legacy alias SUPER_ADMIN_PASSWORD).
 * Production/staging: required, >= 12 chars, not a placeholder; otherwise the seed refuses to run.
 * Development: if unset, a random password is generated and printed once.
 */
function seedAdminPassword(): { password: string; generated: boolean } {
  const fromEnv = process.env.SEED_ADMIN_PASSWORD ?? process.env.SUPER_ADMIN_PASSWORD;
  if (isProduction()) {
    if (!fromEnv || fromEnv.length < 12 || PLACEHOLDER.test(fromEnv)) {
      throw new Error(
        'Refusing to seed in production/staging: set SEED_ADMIN_PASSWORD to a strong, non-placeholder value (>= 12 chars).',
      );
    }
    return { password: fromEnv, generated: false };
  }
  if (fromEnv && fromEnv.length >= 10) return { password: fromEnv, generated: false };
  return { password: `Dev-${randomBytes(12).toString('base64url')}`, generated: true };
}

/**
 * Invite code: SEED_INVITE_CODE.
 * Production/staging: required (>= 8 chars, not a placeholder); otherwise the seed refuses to run.
 * Development: if unset, a random code is generated and printed once.
 */
function seedInviteCode(): { code: string; generated: boolean } {
  const fromEnv = process.env.SEED_INVITE_CODE?.trim();
  if (isProduction()) {
    if (!fromEnv || fromEnv.length < 8 || PLACEHOLDER.test(fromEnv)) {
      throw new Error(
        'Refusing to seed in production/staging: set SEED_INVITE_CODE to a non-placeholder value (>= 8 chars).',
      );
    }
    return { code: fromEnv, generated: false };
  }
  if (fromEnv) return { code: fromEnv, generated: false };
  return { code: `DEV-${randomBytes(4).toString('hex').toUpperCase()}`, generated: true };
}

function isProduction() {
  const node = (process.env.NODE_ENV ?? '').toLowerCase();
  const app = (process.env.APP_ENV ?? '').toLowerCase();
  return node === 'production' || app === 'production' || app === 'staging';
}

const argon = { memoryCost: 19456, timeCost: 2, parallelism: 1 };
const days = (n: number) => new Date(Date.now() + n * 86400000);

/**
 * DEMO DATA — development only. Never runs when NODE_ENV/APP_ENV is production.
 * All demo accounts use @example.com and the DEV_DEFAULT_MEMBER_PASSWORD.
 */
async function seedDemo(adminId: string) {
  if (isProduction()) {
    console.log('  (production) skipping demo members');
    return;
  }
  const pw = process.env.DEV_DEFAULT_MEMBER_PASSWORD;
  if (!pw || pw.length < 10) {
    console.log('  DEV_DEFAULT_MEMBER_PASSWORD not set (>=10 chars) — skipping demo members');
    return;
  }
  const passwordHash = await hash(pw, argon);
  const memberRole = await prisma.role.findUniqueOrThrow({ where: { name: RoleName.member } });
  const modRole = await prisma.role.findUniqueOrThrow({ where: { name: RoleName.moderator } });

  const people = [
    { n: 1, first: 'Alexander', last: 'Whitmore', company: 'Whitmore Capital', title: 'Managing Partner', city: 'Miami', state: 'FL', founding: true, status: UserStatus.active, ms: 'active', car: ['Ferrari', 'SF90 Stradale', 2024, 520000], bio: 'Founding member. Collector of modern Ferraris and vintage Porsches.' },
    { n: 2, first: 'Isabella', last: 'Laurent', company: 'Laurent Design House', title: 'Founder & CEO', city: 'New York', state: 'NY', founding: false, status: UserStatus.active, ms: 'active', car: ['Rolls-Royce', 'Spectre', 2025, 420000], bio: 'Design, architecture, and grand touring.' },
    { n: 3, first: 'Marcus', last: 'Chen', company: 'Chen Ventures', title: 'General Partner', city: 'Los Angeles', state: 'CA', founding: false, status: UserStatus.active, ms: 'dues_due', car: ['Lamborghini', 'Revuelto', 2024, 610000], bio: 'Early-stage investor. Track days on weekends.' },
    { n: 4, first: 'Victoria', last: 'Hale', company: 'Hale Realty Group', title: 'Principal', city: 'Dallas', state: 'TX', founding: false, status: UserStatus.suspended, ms: 'overdue', car: ['Bentley', 'Continental GT Speed', 2023, 310000], bio: 'Suspended demo account (dues overdue).' },
  ] as const;

  const users: Record<number, string> = {};
  for (const p of people) {
    const email = `member${p.n}@example.com`;
    const u = await prisma.user.upsert({
      where: { email },
      create: {
        email, passwordHash, firstName: p.first, lastName: p.last,
        company: p.company, title: p.title, city: p.city, state: p.state, bio: p.bio,
        status: p.status, foundingMember: p.founding, membershipStatus: p.ms as any,
        renewalDate: days(p.ms === 'active' ? 300 : -5),
        roles: { create: [{ roleId: memberRole.id }, ...(p.n === 2 ? [{ roleId: modRole.id }] : [])] },
        vehicles: { create: { make: p.car[0], model: p.car[1], year: p.car[2], estimatedValueUsd: p.car[3], verificationStatus: 'approved', isPrimary: true, color: 'Nero' } },
        duesRecords: { create: { status: p.ms as any, amountUsdCents: p.founding ? 2000000 : 1000000, notes: 'DEMO dues record' } },
      },
      update: { passwordHash, status: p.status, foundingMember: p.founding, membershipStatus: p.ms as any, failedLoginCount: 0, lockedUntil: null },
    });
    users[p.n] = u.id;
  }

  // member5: pending applicant (no account yet) + a few historical applications for charts
  const existingApps = await prisma.memberApplication.count({ where: { email: 'member5@example.com' } });
  if (existingApps === 0) {
    const apps = [
      { email: 'member5@example.com', first: 'Sophia', last: 'Castellano', make: 'McLaren', model: '750S', year: 2025, value: 340000, status: 'submitted', ago: 1 },
      { email: 'applicant6@example.com', first: 'James', last: 'Okafor', make: 'Porsche', model: '911 GT3 RS', year: 2024, value: 260000, status: 'under_review', ago: 4 },
      { email: 'applicant7@example.com', first: 'Elena', last: 'Rossi', make: 'Aston Martin', model: 'DBS', year: 2023, value: 330000, status: 'more_info_needed', ago: 9 },
      { email: 'applicant8@example.com', first: 'Daniel', last: 'Park', make: 'Mercedes-AMG', model: 'G 63', year: 2024, value: 210000, status: 'declined', ago: 16 },
      { email: 'applicant9@example.com', first: 'Olivia', last: 'Grant', make: 'Ferrari', model: 'Roma Spider', year: 2025, value: 280000, status: 'submitted', ago: 20 },
      { email: 'applicant10@example.com', first: 'Henry', last: 'Vance', make: 'Bugatti', model: 'Chiron Sport', year: 2022, value: 3200000, status: 'submitted', ago: 27 },
    ];
    for (const a of apps) {
      await prisma.memberApplication.create({
        data: {
          email: a.email, firstName: a.first, lastName: a.last, city: 'Miami', state: 'FL',
          company: 'DEMO Applicant Co.', vehicleMake: a.make, vehicleModel: a.model, vehicleYear: a.year,
          vehicleEstimatedValue: a.value, status: a.status as any,
          consentPrivacyAt: days(-a.ago), consentPrivacyVersion: '2026-01', consentTermsAt: days(-a.ago), consentTermsVersion: '2026-01',
          createdAt: days(-a.ago), internalNote: 'DEMO application',
        },
      });
    }
  }

  // Content (only once)
  const hasContent = await prisma.post.count({ where: { authorId: users[1] } });
  if (hasContent === 0) {
    const posts = [
      { a: 1, body: 'What a morning at the Keys coastal run. Thank you all for joining — the SF90 finally met its match on the Seven Mile Bridge.', ago: 0.1 },
      { a: 2, body: 'Reminder: the Design & Drive salon is next Thursday. Bring your favourite piece of automotive design history to discuss.', ago: 0.6 },
      { a: 3, body: 'Looking for recommendations on a detailer in LA who handles matte wraps properly. Any members have someone they trust?', ago: 1.2 },
      { a: 1, body: 'Welcome to our newest members this month. The directory is growing — say hello in the event threads.', ago: 2.5, link: ['https://example.com/club-journal', 'Club Journal — Autumn Edition'] },
    ];
    const created: string[] = [];
    for (const p of posts) {
      const post = await prisma.post.create({
        data: { authorId: users[p.a], body: p.body, createdAt: days(-p.ago), linkUrl: p.link?.[0], linkTitle: p.link?.[1] },
      });
      created.push(post.id);
    }
    await prisma.comment.createMany({
      data: [
        { postId: created[0], authorId: users[2], body: 'Stunning route. Count me in for the next one.' },
        { postId: created[0], authorId: users[3], body: 'The photos are incredible!' },
        { postId: created[2], authorId: users[1], body: 'DM me — I have a great contact in Santa Monica.' },
      ],
    });
    await prisma.like.createMany({
      data: [
        { postId: created[0], userId: users[2] }, { postId: created[0], userId: users[3] },
        { postId: created[1], userId: users[1] }, { postId: created[3], userId: users[2] },
      ],
      skipDuplicates: true,
    });

    const events = [
      { title: 'Founders Dinner at The Surf Club', venue: 'The Surf Club', addr: '9011 Collins Ave, Surfside, FL', d: 6, cap: 40, fee: 100000, speakers: [['Chef Thomas Keller', 'chef', 'A seven-course tasting menu'], ['Alexander Whitmore', 'keynote', 'Building a club worth belonging to']] },
      { title: 'Design & Drive Salon', venue: 'Laurent Design House', addr: '41 Greene St, New York, NY', d: 13, cap: 25, fee: 50000, speakers: [['Isabella Laurent', 'roundtable', 'Coachbuilding in the 21st century']] },
      { title: 'Track Day — Homestead', venue: 'Homestead-Miami Speedway', addr: '1 Speedway Blvd, Homestead, FL', d: 24, cap: 30, fee: 150000, speakers: [['Lars Eriksen', 'guest', 'Advanced car control clinic']] },
      { title: 'Autumn Rally Recap', venue: 'The Breakers', addr: '1 S County Rd, Palm Beach, FL', d: -10, cap: 50, fee: 0, speakers: [] },
    ];
    const eventIds: string[] = [];
    for (const e of events) {
      const start = days(e.d); start.setUTCHours(23, 0, 0, 0);
      const ev = await prisma.event.create({
        data: {
          title: e.title, venueName: e.venue, venueAddress: e.addr, startsAt: start,
          endsAt: new Date(start.getTime() + 3 * 3600000), status: e.d < 0 ? 'completed' : 'published',
          capacity: e.cap, feeUsdCents: e.fee, rsvpCutoffAt: days(e.d - 1),
          description: `${e.title}. An evening for members only — attire smart casual. DEMO event.`,
          speakers: { create: e.speakers.map((s, i) => ({ name: s[0], role: s[1] as any, topic: s[2], sortOrder: i })) },
        },
      });
      eventIds.push(ev.id);
      for (const n of [1, 2, 3].slice(0, e.d < 0 ? 3 : e.d % 3 === 0 ? 3 : 2)) {
        await prisma.eventRsvp.create({
          data: { eventId: ev.id, userId: users[n], status: 'going', paymentStatus: n === 1 ? 'paid' : 'unpaid', qrNonce: randomBytes(24).toString('hex') },
        });
        if (e.d < 0) await prisma.eventCheckin.create({ data: { eventId: ev.id, userId: users[n], checkedInBy: adminId, checkedInAt: start } });
      }
    }

    const convo = await prisma.conversation.create({
      data: { type: 'direct', participants: { create: [{ userId: users[1], lastReadAt: new Date() }, { userId: users[2] }] } },
    });
    const msgs = [
      [2, 'Alexander — are you joining the Founders Dinner?', 50],
      [1, 'Wouldn\u2019t miss it. Bringing the SF90.', 45],
      [2, 'Perfect. I\u2019ll save you a seat near the chef\u2019s table.', 40],
      [1, 'See you there 🥂', 5],
    ] as const;
    for (const [s, body, minAgo] of msgs) {
      await prisma.message.create({ data: { conversationId: convo.id, senderId: users[s], body, createdAt: new Date(Date.now() - minAgo * 60000) } });
    }

    await prisma.report.create({ data: { reporterId: users[2], targetType: 'post', targetId: created[2], reason: 'DEMO report: possible solicitation' } });
    await prisma.report.create({ data: { reporterId: users[3], targetType: 'user', targetId: users[4], reason: 'DEMO report: unsolicited messages' } });
    // DEMO: a reported direct message (moderators see only the reported message, never the thread).
    const convo2 = await prisma.conversation.create({ data: { type: 'direct', participants: { create: [{ userId: users[3] }, { userId: users[4] }] } } });
    const pitch = await prisma.message.create({
      data: { conversationId: convo2.id, senderId: users[4], body: 'DEMO: Exclusive investment opportunity — reply for details.', createdAt: new Date(Date.now() - 26 * 3600000) },
    });
    await prisma.report.create({ data: { reporterId: users[3], targetType: 'message', targetId: pitch.id, reason: 'DEMO report: unsolicited sales pitch in DMs' } });

    const minsAgo = (m: number) => new Date(Date.now() - m * 60000);
    for (const n of [1, 2, 3]) {
      await prisma.notification.createMany({
        data: [
          { userId: users[n], title: 'Founders Dinner — RSVP open', body: 'Seats are limited to 40 members.', dataJson: JSON.stringify({ type: 'event', eventId: eventIds[0] }), createdAt: minsAgo(3) },
          ...(n === 1 ? [{ userId: users[n], title: 'New message from Isabella Laurent', body: 'Perfect. I\u2019ll save you a seat near the chef\u2019s table.', dataJson: JSON.stringify({ type: 'message', conversationId: convo.id }), createdAt: minsAgo(40), readAt: n === 1 ? null : minsAgo(30) }] : []),
          { userId: users[n], title: 'Marcus Chen commented on your post', body: '“The photos are incredible!”', dataJson: JSON.stringify({ type: 'comment', postId: created[0] }), createdAt: minsAgo(60 * 5), readAt: minsAgo(60 * 4) },
          { userId: users[n], title: 'Design & Drive Salon is in two weeks', body: 'Reserve your seat — 25 places available.', dataJson: JSON.stringify({ type: 'event', eventId: eventIds[1] }), createdAt: minsAgo(60 * 30), readAt: minsAgo(60 * 29) },
          { userId: users[n], title: 'Annual dues receipt', body: 'Thank you — your 2026 membership dues have been received.', dataJson: JSON.stringify({ type: 'dues' }), createdAt: minsAgo(60 * 24 * 9), readAt: minsAgo(60 * 24 * 9) },
        ],
      });
    }
    await prisma.auditLog.createMany({
      data: [
        { actorId: adminId, action: 'seed.demo', targetType: 'system', metadata: JSON.stringify({ note: 'DEMO data seeded' }) },
        { actorId: adminId, action: 'member.suspended', targetType: 'user', targetId: users[4], metadata: JSON.stringify({ reason: 'DEMO overdue dues' }) },
      ],
    });
  }

  console.log('  DEMO members (dev only, password = DEV_DEFAULT_MEMBER_PASSWORD):');
  console.log('    member1@example.com  founding, active');
  console.log('    member2@example.com  active, moderator');
  console.log('    member3@example.com  active, dues due');
  console.log('    member4@example.com  suspended');
  console.log('    member5@example.com  pending applicant (no account until approved)');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
