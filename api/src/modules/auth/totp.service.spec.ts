import { describe, expect, it } from 'vitest';
import { TotpService } from './totp.service';

describe('TotpService', () => {
  const svc = new TotpService();

  it('generates secret and verifies code', () => {
    const secret = svc.generateSecret();
    const token = svc.generateCode(secret);
    expect(svc.verify(token, secret)).toBe(true);
    expect(svc.verify('000000', secret)).toBe(false);
  });

  it('hashes recovery codes', () => {
    const codes = svc.generateRecoveryCodes(2);
    expect(codes).toHaveLength(2);
    expect(svc.hashRecovery(codes[0])).toHaveLength(64);
  });
});
