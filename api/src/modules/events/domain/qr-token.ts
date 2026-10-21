import { createHmac, timingSafeEqual } from 'crypto';

/**
 * QR payload format (no PII — only opaque RSVP id + expiry + HMAC):
 *   pm1.<rsvpId>.<expUnix>.<sigBase64url>
 */
export function signQrToken(
  rsvpId: string,
  secret: string,
  expUnix: number,
): string {
  const sig = createHmac('sha256', secret)
    .update(`${rsvpId}.${expUnix}`)
    .digest('base64url');
  return `pm1.${rsvpId}.${expUnix}.${sig}`;
}

export type QrParseResult =
  { ok: true; rsvpId: string; expUnix: number } | { ok: false; reason: string };

export function verifyQrToken(
  token: string,
  secret: string,
  nowUnix = Math.floor(Date.now() / 1000),
): QrParseResult {
  const parts = token.split('.');
  if (parts.length !== 4 || parts[0] !== 'pm1') {
    return { ok: false, reason: 'malformed' };
  }
  const [, rsvpId, expStr, sig] = parts;
  if (!rsvpId || !expStr || !sig) return { ok: false, reason: 'malformed' };
  const expUnix = Number(expStr);
  if (!Number.isFinite(expUnix)) return { ok: false, reason: 'malformed' };
  if (expUnix < nowUnix) return { ok: false, reason: 'expired' };
  const expected = createHmac('sha256', secret)
    .update(`${rsvpId}.${expUnix}`)
    .digest('base64url');
  try {
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      return { ok: false, reason: 'tampered' };
    }
  } catch {
    return { ok: false, reason: 'tampered' };
  }
  return { ok: true, rsvpId, expUnix };
}

export function qrExpiryUnix(startsAt: Date, endsAt?: Date | null): number {
  const end = endsAt ?? new Date(startsAt.getTime() + 12 * 3600_000);
  // Valid until end of event + 6h grace
  return Math.floor((end.getTime() + 6 * 3600_000) / 1000);
}
