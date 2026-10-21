import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { AddressInfo } from 'net';
import { io, Socket } from 'socket.io-client';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import sharp from 'sharp';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { TokenService } from '../src/infrastructure/crypto/token.service';

/**
 * Seeded credentials come from api/.env (loaded by ConfigModule when AppModule boots) or the CI env.
 * Nothing is hard-coded so the public repo carries no reusable passwords.
 */
function requiredEnv(...names: string[]): string {
  for (const n of names) {
    const v = process.env[n];
    if (v) return v;
  }
  throw new Error(`e2e: set ${names.join(' or ')} (same value used by \`npx prisma db seed\`)`);
}

describe('API e2e (Vitest + Nest)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let adminToken: string;
  let memberToken: string;
  let memberId: string;
  let member2Token: string;
  let member2Id: string;
  let baseUrl: string;
  const email = `e2e_${Date.now()}@example.com`;
  const email2 = `e2e2_${Date.now()}@example.com`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useWebSocketAdapter(new IoAdapter(app));
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.listen(0);
    const addr = app.getHttpServer().address() as AddressInfo;
    baseUrl = `http://127.0.0.1:${addr.port}`;
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('health', async () => {
    await request(app.getHttpServer()).get('/api/health').expect(200);
  });

  it('admin login + member apply/approve/login', async () => {
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({
        email: process.env.SUPER_ADMIN_EMAIL ?? 'admin@example.com',
        password: requiredEnv('SEED_ADMIN_PASSWORD', 'SUPER_ADMIN_PASSWORD'),
      })
      .expect(200);
    adminToken = login.body.accessToken;

    const apply = await request(app.getHttpServer())
      .post('/api/applications')
      .send({
        email,
        firstName: 'E2E',
        lastName: 'Member',
        company: 'E2E Co',
        title: 'CEO',
        city: 'Austin',
        state: 'TX',
        vehicleMake: 'Porsche',
        vehicleModel: '911',
        vehicleYear: 2022,
        vehicleEstimatedValue: 250000,
        inviteCode: requiredEnv('SEED_INVITE_CODE'),
        consentPrivacy: true,
        consentTerms: true,
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/admin/applications/${apply.body.id}/review`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ decision: 'approve', grantFoundingMember: false })
      .expect(201);

    const user = await prisma.user.findUniqueOrThrow({ where: { email } });
    memberId = user.id;
    const ts = new TokenService();
    const raw = ts.generateOpaque();
    await prisma.passwordReset.create({
      data: {
        userId: user.id,
        tokenHash: ts.hash(raw),
        expiresAt: new Date(Date.now() + 86400000),
      },
    });
    await request(app.getHttpServer())
      .post('/api/auth/set-password')
      .send({ token: raw, password: 'MemberPass1!' })
      .expect(200);

    const mLogin = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: 'MemberPass1!' })
      .expect(200);
    memberToken = mLogin.body.accessToken;

    await request(app.getHttpServer())
      .get('/api/admin/applications')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(403);

    // Second member for DMs
    const apply2 = await request(app.getHttpServer())
      .post('/api/applications')
      .send({
        email: email2,
        firstName: 'E2E',
        lastName: 'Two',
        company: 'E2E Co',
        title: 'COO',
        city: 'Dallas',
        state: 'TX',
        vehicleMake: 'Ferrari',
        vehicleModel: 'F8',
        vehicleYear: 2021,
        vehicleEstimatedValue: 300000,
        inviteCode: requiredEnv('SEED_INVITE_CODE'),
        consentPrivacy: true,
        consentTerms: true,
      })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/admin/applications/${apply2.body.id}/review`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ decision: 'approve' })
      .expect(201);
    const user2 = await prisma.user.findUniqueOrThrow({ where: { email: email2 } });
    member2Id = user2.id;
    const raw2 = ts.generateOpaque();
    await prisma.passwordReset.create({
      data: {
        userId: user2.id,
        tokenHash: ts.hash(raw2),
        expiresAt: new Date(Date.now() + 86400000),
      },
    });
    await request(app.getHttpServer())
      .post('/api/auth/set-password')
      .send({ token: raw2, password: 'MemberPass2!' })
      .expect(200);
    const m2 = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: email2, password: 'MemberPass2!' })
      .expect(200);
    member2Token = m2.body.accessToken;
  });

  it('profile update + vehicle + media', async () => {
    await request(app.getHttpServer())
      .patch('/api/me/profile')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ bio: 'Hello', city: 'Austin', showEmail: false })
      .expect(200);

    const vehicle = await request(app.getHttpServer())
      .post('/api/me/vehicles')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ make: 'Lotus', model: 'Emira', year: 2023, blurPlate: true })
      .expect(201);

    const jpeg = await sharp({
      create: { width: 32, height: 24, channels: 3, background: { r: 1, g: 2, b: 3 } },
    })
      .jpeg()
      .toBuffer();

    const upload = await request(app.getHttpServer())
      .post('/api/media/upload')
      .set('Authorization', `Bearer ${memberToken}`)
      .field('folder', 'vehicles')
      .field('ownerType', 'vehicle')
      .field('ownerId', vehicle.body.id)
      .field('vehicleId', vehicle.body.id)
      .attach('file', jpeg, 'car.jpg')
      .expect(201);
    expect(upload.body.exifStripped).toBe(true);
  });

  it('feed: create / like / comment / share / report / hide permissions', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/posts')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'First post from e2e' })
      .expect(201);
    const postId = created.body.id as string;

    const feed = await request(app.getHttpServer())
      .get('/api/feed')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(200);
    expect(feed.body.items.some((p: { id: string }) => p.id === postId)).toBe(true);

    await request(app.getHttpServer())
      .post(`/api/posts/${postId}/like`)
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/posts/${postId}/comments`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'Nice car' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/api/posts')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'Sharing this', sharedFromPostId: postId })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/admin/posts/${postId}/hide`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ hide: true })
      .expect(403);

    await request(app.getHttpServer())
      .post('/api/posts')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'bad link', linkUrl: 'http://127.0.0.1/secret' })
      .expect(400);
  });

  it('messaging REST: DM / unread / block / report / share post / permissions', async () => {
    const conv = await request(app.getHttpServer())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ memberId: member2Id })
      .expect(201);
    const conversationId = conv.body.id as string;

    const msg = await request(app.getHttpServer())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'Hello peer' })
      .expect(201);
    expect(msg.body.body).toBe('Hello peer');

    const list2 = await request(app.getHttpServer())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${member2Token}`)
      .expect(200);
    const item = list2.body.items.find((c: { id: string }) => c.id === conversationId);
    expect(item.unreadCount).toBeGreaterThanOrEqual(1);

    await request(app.getHttpServer())
      .post(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${member2Token}`)
      .expect(201);

    // non-participant cannot read
    await request(app.getHttpServer())
      .get(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(403);

    const post = await request(app.getHttpServer())
      .post('/api/posts')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'Share me via DM' })
      .expect(201);

    const shared = await request(app.getHttpServer())
      .post('/api/messages/share-post')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ postId: post.body.id, memberId: member2Id, note: 'Check this' })
      .expect(201);
    expect(shared.body.sharedPostId).toBe(post.body.id);

    const report = await request(app.getHttpServer())
      .post('/api/messages/report')
      .set('Authorization', `Bearer ${member2Token}`)
      .send({ messageId: msg.body.id, reason: 'harassment test' })
      .expect(201);

    const reports = await request(app.getHttpServer())
      .get('/api/admin/reports?status=open')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    const found = reports.body.find((r: { id: string }) => r.id === report.body.id);
    expect(found.targetType).toBe('message');
    expect(found.reportedMessage?.body).toBe('Hello peer');

    await request(app.getHttpServer())
      .post('/api/blocks')
      .set('Authorization', `Bearer ${member2Token}`)
      .send({ memberId })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'should fail' })
      .expect(403);

    await request(app.getHttpServer())
      .delete(`/api/blocks/${memberId}`)
      .set('Authorization', `Bearer ${member2Token}`)
      .expect(200);
  });

  it('socket.io: JWT handshake + realtime message', async () => {
    const conv = await request(app.getHttpServer())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ memberId: member2Id })
      .expect(201);
    const conversationId = conv.body.id as string;

    const received = new Promise<any>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('socket timeout')), 10000);
      const socket: Socket = io(`${baseUrl}/realtime`, {
        auth: { token: member2Token },
        transports: ['websocket'],
        forceNew: true,
      });
      socket.on('connect_error', (err) => {
        clearTimeout(timer);
        reject(err);
      });
      const join = () => {
        socket.emit(
          'conversation:join',
          { conversationId },
          (ack: { ok?: boolean; error?: string }) => {
            if (!ack?.ok) {
              clearTimeout(timer);
              reject(new Error(`join failed: ${ack?.error ?? 'unknown'}`));
            }
          },
        );
      };
      socket.on('ready', () => join());
      // fallback if ready missed
      socket.on('connect', () => setTimeout(join, 200));
      socket.on('message:new', (payload) => {
        clearTimeout(timer);
        socket.close();
        resolve(payload);
      });
    });

    await new Promise((r) => setTimeout(r, 600));

    await request(app.getHttpServer())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'Realtime hello' })
      .expect(201);

    const payload = await received;
    expect(payload.body).toBe('Realtime hello');

    // Reject missing token
    await new Promise<void>((resolve, reject) => {
      const s = io(`${baseUrl}/realtime`, {
        transports: ['websocket'],
        forceNew: true,
      });
      const t = setTimeout(() => {
        s.close();
        resolve();
      }, 1500);
      s.on('connect', () => {
        clearTimeout(t);
        s.close();
        reject(new Error('should not connect without token'));
      });
      s.on('disconnect', () => {
        clearTimeout(t);
        resolve();
      });
    });
  });

  it('event thread: RSVP gate + comments', async () => {
    const event = await request(app.getHttpServer())
      .post('/api/admin/events')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        title: 'E2E Gala',
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        venueName: 'Austin',
        status: 'published',
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/events/${event.body.id}/thread/comments`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'Cannot post yet' })
      .expect(403);

    await request(app.getHttpServer())
      .post(`/api/events/${event.body.id}/rsvp-going`)
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(201);

    const comment = await request(app.getHttpServer())
      .post(`/api/events/${event.body.id}/thread/comments`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ body: 'Looking forward' })
      .expect(201);
    expect(comment.body.body).toBe('Looking forward');

    // All members can read
    const thread = await request(app.getHttpServer())
      .get(`/api/events/${event.body.id}/thread`)
      .set('Authorization', `Bearer ${member2Token}`)
      .expect(200);
    expect(thread.body.items.some((c: { body: string }) => c.body === 'Looking forward')).toBe(
      true,
    );
  });


  it('events M6: RSVP cut-off/capacity, QR, double check-in, privacy, directory filter', async () => {
    const starts = new Date(Date.now() + 7 * 86400000).toISOString();
    const event = await request(app.getHttpServer())
      .post('/api/admin/events')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        title: 'M6 Gala',
        startsAt: starts,
        venueName: 'Austin Club',
        status: 'published',
        capacity: 1,
        feeUsdCents: 100000,
        paymentLinkUrl: 'https://pay.example.com/event',
        speakers: [
          { name: 'Chef Ana', role: 'chef', menuNotes: 'Wagyu' },
          { name: 'Key Host', role: 'keynote', topic: 'Future of cars', bio: 'CEO' },
        ],
      })
      .expect(201);
    const eventId = event.body.id as string;
    expect(event.body.speakers?.length).toBe(2);

    // member1 attending fills capacity
    const r1 = await request(app.getHttpServer())
      .post(`/api/events/${eventId}/rsvp`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ status: 'going' })
      .expect(201);
    expect(r1.body.status).toBe('going');

    // member2 waitlisted
    const r2 = await request(app.getHttpServer())
      .post(`/api/events/${eventId}/rsvp`)
      .set('Authorization', `Bearer ${member2Token}`)
      .send({ status: 'going' })
      .expect(201);
    expect(r2.body.status).toBe('waitlisted');

    // ticket + QR for member1
    const ticket = await request(app.getHttpServer())
      .get(`/api/events/${eventId}/ticket`)
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(200);
    expect(ticket.body.token.startsWith('pm1.')).toBe(true);

    // tampered QR rejected
    await request(app.getHttpServer())
      .post(`/api/admin/events/${eventId}/checkin/preview`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ token: ticket.body.token + 'nope' })
      .expect(400);

    const preview = await request(app.getHttpServer())
      .post(`/api/admin/events/${eventId}/checkin/preview`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ token: ticket.body.token })
      .expect(201);
    expect(preview.body.member.id).toBe(memberId);

    await request(app.getHttpServer())
      .post(`/api/admin/events/${eventId}/checkin/confirm`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ token: ticket.body.token })
      .expect(201);

    // double check-in
    await request(app.getHttpServer())
      .post(`/api/admin/events/${eventId}/checkin/confirm`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ token: ticket.body.token })
      .expect(409);

    // ICS
    await request(app.getHttpServer())
      .get(`/api/events/${eventId}/ics`)
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(200)
      .expect('Content-Type', /text\/calendar/);

    // privacy: member1 hide attendance
    await request(app.getHttpServer())
      .patch('/api/me/profile')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ showEventsAttended: false })
      .expect(200);

    const attendees = await request(app.getHttpServer())
      .get(`/api/events/${eventId}/attendees`)
      .set('Authorization', `Bearer ${member2Token}`)
      .expect(200);
    expect(attendees.body.items.some((a: { userId: string }) => a.userId === memberId)).toBe(false);

    // restore visibility for directory filter
    await request(app.getHttpServer())
      .patch('/api/me/profile')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ showEventsAttended: true })
      .expect(200);

    const dir = await request(app.getHttpServer())
      .get('/api/members')
      .query({ eventId })
      .set('Authorization', `Bearer ${member2Token}`)
      .expect(200);
    expect(dir.body.some((m: { id: string }) => m.id === memberId)).toBe(true);

    // cut-off: create event with past cutoff
    const closed = await request(app.getHttpServer())
      .post('/api/admin/events')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        title: 'Closed RSVP',
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        rsvpCutoffAt: new Date(Date.now() - 1000).toISOString(),
        status: 'published',
      })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/events/${closed.body.id}/rsvp`)
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ status: 'going' })
      .expect(403);

    // CSV export
    await request(app.getHttpServer())
      .get(`/api/admin/events/${eventId}/attendance.csv`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200)
      .expect('Content-Type', /text\/csv/);

    // mark payment
    await request(app.getHttpServer())
      .patch(`/api/admin/events/${eventId}/rsvps/${r1.body.id}/payment`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ paymentStatus: 'paid' })
      .expect(200);
  });


  it('stage6 admin overview, invites, audit csv, roles safeguard', async () => {
    const overview = await request(app.getHttpServer())
      .get('/api/admin/overview')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    expect(overview.body).toHaveProperty('members');
    expect(overview.body).toHaveProperty('pendingApplications');
    expect(overview.body).toHaveProperty('upcomingEvents');
    expect(overview.body).toHaveProperty('openReports');
    expect(overview.body).toHaveProperty('rsvpsGoing');

    const invite = await request(app.getHttpServer())
      .post('/api/admin/invites')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ maxUses: 2 })
      .expect(201);
    expect(invite.body.code).toBeTruthy();

    await request(app.getHttpServer())
      .get('/api/admin/invites')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .post(`/api/admin/invites/${invite.body.id}/revoke`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(201);

    const audit = await request(app.getHttpServer())
      .get('/api/admin/audit-logs')
      .query({ action: 'invite' })
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    expect(Array.isArray(audit.body)).toBe(true);

    await request(app.getHttpServer())
      .get('/api/admin/audit-logs.csv')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200)
      .expect('Content-Type', /text\/csv/);

    // Attempt to demote last super_admin should fail (seed admin is typically the only one)
    const adminUser = await prisma.user.findFirst({
      where: { email: process.env.SUPER_ADMIN_EMAIL ?? 'admin@example.com' },
    });
    expect(adminUser).toBeTruthy();
    await request(app.getHttpServer())
      .patch(`/api/admin/members/${adminUser!.id}/roles`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ roles: ['admin'] })
      .expect(403);
  });

  it('stage6 dues, moderation, notification prefs + devices', async () => {
    await request(app.getHttpServer())
      .patch(`/api/admin/members/${memberId}/dues`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        membershipStatus: 'dues_due',
        amountUsdCents: 100000,
        renewalDate: '2027-01-01',
        notes: 'e2e dues',
      })
      .expect(200);

    await request(app.getHttpServer())
      .post(`/api/admin/members/${memberId}/moderation`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ action: 'warn', reason: 'e2e warning' })
      .expect(201);

    const prefs = await request(app.getHttpServer())
      .get('/api/me/notification-preferences')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(200);
    expect(prefs.body).toHaveProperty('pushEvents');

    await request(app.getHttpServer())
      .patch('/api/me/notification-preferences')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ pushEvents: false, emailDues: false })
      .expect(200);

    await request(app.getHttpServer())
      .post('/api/devices')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ fcmToken: 'e2e-token-1', platform: 'android' })
      .expect(201);

    await request(app.getHttpServer())
      .get('/api/notifications')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .post('/api/devices/unregister')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ fcmToken: 'e2e-token-1' })
      .expect(201);
  });

  it('stage6 2FA endpoints require preAuth when enforced off still validate body', async () => {
    // With STAFF_2FA_REQUIRED=false, admin login returns full session — 2FA setup needs preAuth
    const bad = await request(app.getHttpServer())
      .post('/api/auth/2fa/setup')
      .send({ preAuthToken: 'not-a-jwt' })
      .expect(401);
    expect(bad.status).toBe(401);
  });

  it('stage7 export + sessions', async () => {
    const exp = await request(app.getHttpServer())
      .get('/api/me/export')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(200);
    expect(exp.body.profile.email).toBe(email);

    const sessions = await request(app.getHttpServer())
      .get('/api/auth/sessions')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(200);
    expect(Array.isArray(sessions.body.items)).toBe(true);
  });

  it('ux round: dev accounts, admin console tables/stats/bulk/broadcast + RBAC', async () => {
    const srv = app.getHttpServer();
    // dev accounts are available in non-production test env
    const dev = await request(srv).get('/api/dev/accounts');
    if (process.env.DEV_DEFAULT_MEMBER_PASSWORD) expect(dev.status).toBe(200);
    // member cannot use admin console
    await request(srv).get('/api/admin/console/members').set('Authorization', `Bearer ${memberToken}`).expect(403);
    const auth = { Authorization: `Bearer ${adminToken}` };
    const env = await request(srv).get('/api/admin/console/env').set(auth).expect(200);
    expect(['DEV', 'STAGING', 'PROD']).toContain(env.body.environment);
    const members = await request(srv).get('/api/admin/console/members?page=1&pageSize=5&sort=email&order=asc').set(auth).expect(200);
    expect(members.body.items.length).toBeLessThanOrEqual(5);
    expect(members.body.total).toBeGreaterThan(0);
    expect(members.body.sort).toBe('email');
    const bad = await request(srv).get('/api/admin/console/members?sort=passwordHash').set(auth).expect(200);
    expect(bad.body.sort).toBe('createdAt');
    const detail = await request(srv).get(`/api/admin/console/members/${memberId}`).set(auth).expect(200);
    expect(detail.body.profile.passwordHash).toBeUndefined();
    expect(Array.isArray(detail.body.audit)).toBe(true);
    const apps = await request(srv).get('/api/admin/console/applications?status=approved').set(auth).expect(200);
    expect(apps.body.facets).toBeTruthy();
    const stats = await request(srv).get('/api/admin/console/stats').set(auth).expect(200);
    expect(stats.body.applicationsPerWeek).toHaveLength(8);
    const csv = await request(srv).get(`/api/admin/console/members.csv?ids=${memberId}`).set(auth).expect(200);
    expect(csv.text.split('\n')[0]).toContain('email');
    // bulk suspend + reinstate, audited
    const s = await request(srv).post('/api/admin/console/members/bulk').set(auth).send({ ids: [member2Id], action: 'suspend', reason: 'e2e bulk' }).expect(201);
    expect(s.body.results[0].ok).toBe(true);
    await request(srv).post('/api/admin/console/members/bulk').set(auth).send({ ids: [member2Id], action: 'reinstate', reason: 'e2e bulk' }).expect(201);
    const logs = await prisma.auditLog.count({ where: { action: 'member.bulk_suspend' } });
    expect(logs).toBeGreaterThan(0);
    await request(srv).post('/api/admin/console/members/bulk').set(auth).send({ ids: ['nope'], action: 'suspend', reason: 'x' }).expect(400);
    const dry = await request(srv).post('/api/admin/console/broadcast').set(auth).send({ title: 'Hello', body: 'Members only', segment: 'all', channels: ['in_app'], dryRun: true }).expect(201);
    expect(dry.body.recipients).toBeGreaterThan(0);
    await request(srv).post('/api/admin/console/broadcast').set('Authorization', `Bearer ${memberToken}`).send({ title: 'Hello', body: 'x', segment: 'all', channels: ['in_app'] }).expect(403);
  });

  it('ux round: comma-list filters and report previews', async () => {
    const srv = app.getHttpServer();
    const auth = { Authorization: `Bearer ${adminToken}` };
    // role filter accepts comma lists; unknown values are ignored instead of erroring
    const staff = await request(srv).get('/api/admin/console/members?role=super_admin,admin,not_a_role').set(auth).expect(200);
    expect(staff.body.items.some((m: { email: string }) => m.email === (process.env.SUPER_ADMIN_EMAIL ?? 'admin@example.com'))).toBe(true);
    const all = await request(srv).get('/api/admin/console/members').set(auth).expect(200);
    const multi = await request(srv).get('/api/admin/console/members?membershipStatus=active,dues_due,overdue,suspended,bogus').set(auth).expect(200);
    const single = await request(srv).get('/api/admin/console/members?membershipStatus=dues_due').set(auth).expect(200);
    expect(multi.body.total).toBeGreaterThanOrEqual(single.body.total);
    expect(multi.body.total).toBeLessThanOrEqual(all.body.total);
    const junk = await request(srv).get('/api/admin/console/members?membershipStatus=bogus').set(auth).expect(200);
    expect(junk.body.total).toBe(all.body.total);

    // a reported post comes back with a preview so moderators need not open the feed
    const post = await request(srv).post('/api/posts').set('Authorization', `Bearer ${member2Token}`).send({ body: 'Reported preview e2e' }).expect(201);
    const rep = await request(srv)
      .post('/api/reports')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ targetType: 'post', targetId: post.body.id, reason: 'e2e preview' })
      .expect(201);
    const reports = await request(srv).get('/api/admin/reports?status=open').set(auth).expect(200);
    const found = reports.body.find((r: { id: string }) => r.id === rep.body.id);
    expect(found.reportedPost?.body).toBe('Reported preview e2e');
    expect(found.reportedPost?.author).toBeTruthy();
    expect(found.reportedPost?.author?.passwordHash).toBeUndefined();
  });

  it('refresh + logout', async () => {
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: 'MemberPass1!' })
      .expect(200);
    let refresh = login.body.refreshToken as string;
    const access = login.body.accessToken as string;
    const rotated = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: refresh })
      .expect(200);
    refresh = rotated.body.refreshToken;
    await request(app.getHttpServer())
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${rotated.body.accessToken ?? access}`)
      .send({ refreshToken: refresh })
      .expect(200);
    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: refresh })
      .expect(401);
  });
});
