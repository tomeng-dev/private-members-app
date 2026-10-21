import { spawn } from 'child_process';
import { createHash, randomBytes } from 'crypto';
import { setTimeout as sleep } from 'timers/promises';
import { readFileSync } from 'fs';
import sharp from 'sharp';

const BASE = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3000/api';
const ADMIN_EMAIL = process.env.SUPER_ADMIN_EMAIL ?? 'admin@example.com';
const ADMIN_PASS = process.env.SEED_ADMIN_PASSWORD ?? process.env.SUPER_ADMIN_PASSWORD;
const INVITE_CODE = process.env.SEED_INVITE_CODE;
if (!ADMIN_PASS || !INVITE_CODE) {
  console.error('smoke: set SEED_ADMIN_PASSWORD and SEED_INVITE_CODE (same values used by `npx prisma db seed`).');
  process.exit(1);
}

let child = null;
let startedByUs = false;

async function req(method, path, { body, token, formData } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (formData) {
    payload = formData;
  } else if (body) {
    headers['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(`${BASE}${path}`, { method, headers, body: payload });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, body: json };
}

async function waitHealthy(retries = 40) {
  for (let i = 0; i < retries; i++) {
    try {
      const r = await req('GET', '/health');
      if (r.status === 200) return;
    } catch {}
    await sleep(250);
  }
  throw new Error('API did not become healthy');
}

async function ensureServer() {
  try {
    const r = await req('GET', '/health');
    if (r.status === 200) return;
  } catch {}
  startedByUs = true;
  child = spawn('node', ['dist/main.js'], {
    cwd: process.cwd(),
    env: { ...process.env },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stderr.on('data', (d) => process.stderr.write(d));
  child.stdout.on('data', (d) => process.stdout.write(d));
  await waitHealthy();
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function main() {
  await ensureServer();
  const email = `smoke_${Date.now()}@example.com`;
  let failed = 0;
  const check = (name, cond) => {
    if (cond) console.log(`  ✓ ${name}`);
    else { console.error(`  ✗ ${name}`); failed++; }
  };

  console.log('1) health');
  check('health ok', (await req('GET', '/health')).status === 200);

  console.log('2) admin login');
  const login = await req('POST', '/auth/login', {
    body: { email: ADMIN_EMAIL, password: ADMIN_PASS },
  });
  check('admin login', login.status === 200);
  const adminToken = login.body.accessToken;

  console.log('3) apply + approve + member login');
  const apply = await req('POST', '/applications', {
    body: {
      email, firstName: 'Smoke', lastName: 'Tester', company: 'Smoke Inc', title: 'Founder',
      city: 'NYC', state: 'NY', vehicleMake: 'McLaren', vehicleModel: '720S', vehicleYear: 2022,
      vehicleEstimatedValue: 280000, inviteCode: INVITE_CODE, consentPrivacy: true, consentTerms: true,
    },
  });
  check('apply', apply.status === 201);
  const applicationId = apply.body.id;
  const review = await req('POST', `/admin/applications/${applicationId}/review`, {
    token: adminToken,
    body: { decision: 'approve', grantFoundingMember: true },
  });
  check('approve', review.status === 201);

  const { PrismaClient } = await import('@prisma/client');
  const prisma = new PrismaClient();
  const user = await prisma.user.findUnique({ where: { email } });
  const raw = randomBytes(32).toString('base64url');
  await prisma.passwordReset.create({
    data: {
      userId: user.id,
      tokenHash: createHash('sha256').update(raw).digest('hex'),
      expiresAt: new Date(Date.now() + 86400000),
    },
  });
  check('set password', (await req('POST', '/auth/set-password', {
    body: { token: raw, password: 'MemberPass1!' },
  })).status === 200);

  const memberLogin = await req('POST', '/auth/login', {
    body: { email, password: 'MemberPass1!' },
  });
  check('member login', memberLogin.status === 200);
  let memberToken = memberLogin.body.accessToken;
  let refreshToken = memberLogin.body.refreshToken;

  check('member forbidden admin', (await req('GET', '/admin/applications', { token: memberToken })).status === 403);

  console.log('4) Stage2 profile / directory / vehicle / business / media');
  const patched = await req('PATCH', '/me/profile', {
    token: memberToken,
    body: { bio: 'Collector', city: 'Miami', showEmail: false, company: 'Smoke Motors', title: 'CEO' },
  });
  check('patch profile', patched.status === 200 && patched.body.bio === 'Collector');

  const me = await req('GET', '/me/profile', { token: memberToken });
  check('get my profile', me.status === 200 && me.body.vehicles?.length >= 1);

  const dir = await req('GET', '/members?q=Smoke', { token: memberToken });
  check('member directory', dir.status === 200 && Array.isArray(dir.body));

  const vehicle = await req('POST', '/me/vehicles', {
    token: memberToken,
    body: { make: 'Ferrari', model: 'F8', year: 2021, color: 'Rosso', plateNumber: 'ABC123', blurPlate: true, isPrimary: true },
  });
  check('create vehicle', vehicle.status === 201 || vehicle.status === 200);
  const vehicleId = vehicle.body.id;

  const jpeg = await sharp({
    create: { width: 64, height: 48, channels: 3, background: { r: 10, g: 20, b: 30 } },
  }).jpeg().toBuffer();

  const form = new FormData();
  form.append('folder', 'vehicles');
  form.append('ownerType', 'vehicle');
  form.append('ownerId', vehicleId);
  form.append('vehicleId', vehicleId);
  form.append('file', new Blob([jpeg], { type: 'image/jpeg' }), 'car.jpg');
  const upload = await req('POST', '/media/upload', { token: memberToken, formData: form });
  check('media upload+exif strip', upload.status === 201 || upload.status === 200);
  if (upload.body?.exifStripped !== true) {
    console.error('  body', upload.body);
  }
  check('exif stripped flag', upload.body?.exifStripped === true);

  const biz = await req('PUT', '/me/business-page', {
    token: memberToken,
    body: {
      companyName: 'Smoke Motors LLC',
      services: 'Advisory',
      background: 'Hello <script>alert(1)</script> world',
      website: 'https://example.com',
      showContactEmail: true,
    },
  });
  check('business page upsert', biz.status === 200 || biz.status === 201);
  check('script stripped', !String(biz.body.background || '').includes('<script>'));

  const publicProfile = await req('GET', `/members/${user.id}`, { token: adminToken });
  check('public profile', publicProfile.status === 200);
  check('email hidden by privacy', publicProfile.body.email === undefined);

  const hide = await req('POST', '/admin/moderation/hide', {
    token: adminToken,
    body: { type: 'vehicle', id: vehicleId, hide: true },
  });
  check('admin hide vehicle', hide.status === 201 || hide.status === 200);

  console.log('5) refresh + logout');
  const refreshed = await req('POST', '/auth/refresh', { body: { refreshToken } });
  check('refresh', refreshed.status === 200);
  refreshToken = refreshed.body.refreshToken;
  memberToken = refreshed.body.accessToken;
  check('logout', (await req('POST', '/auth/logout', { token: memberToken, body: { refreshToken } })).status === 200);
  check('revoked refresh', (await req('POST', '/auth/refresh', { body: { refreshToken } })).status === 401);

  await prisma.$disconnect();
  if (startedByUs && child) child.kill('SIGTERM');
  if (failed) {
    console.error(`\nFAILED: ${failed}`);
    process.exit(1);
  }
  console.log('\nAll smoke e2e checks passed.');
}

main().catch((e) => {
  console.error(e);
  if (child) child.kill('SIGTERM');
  process.exit(1);
});
