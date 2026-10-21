import { describe, expect, it } from 'vitest';
import { signQrToken, verifyQrToken } from './qr-token';

describe('qr-token', () => {
  const secret = 'test-qr-secret-value';

  it('signs and verifies', () => {
    const exp = Math.floor(Date.now() / 1000) + 3600;
    const token = signQrToken('rsvp-1', secret, exp);
    expect(token.startsWith('pm1.')).toBe(true);
    expect(token.includes('@')).toBe(false);
    const v = verifyQrToken(token, secret);
    expect(v.ok).toBe(true);
    if (v.ok) expect(v.rsvpId).toBe('rsvp-1');
  });

  it('rejects expired', () => {
    const token = signQrToken('rsvp-1', secret, Math.floor(Date.now() / 1000) - 10);
    expect(verifyQrToken(token, secret).ok).toBe(false);
    expect((verifyQrToken(token, secret) as any).reason).toBe('expired');
  });

  it('rejects tampered', () => {
    const exp = Math.floor(Date.now() / 1000) + 3600;
    const token = signQrToken('rsvp-1', secret, exp) + 'x';
    expect((verifyQrToken(token, secret) as any).reason).toBe('tampered');
  });
});
