import { Injectable } from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';
import { generateSecret, generateSync, generateURI, verifySync } from 'otplib';

@Injectable()
export class TotpService {
  generateSecret() {
    return generateSecret();
  }

  keyuri(email: string, secret: string, issuer = 'Private Members Admin') {
    return generateURI({ issuer, label: email, secret });
  }

  /** Used in tests to mint a valid code for a secret. */
  generateCode(secret: string) {
    return generateSync({ secret });
  }

  verify(token: string, secret: string) {
    const res = verifySync({ token, secret });
    return !!res.valid;
  }

  generateRecoveryCodes(count = 8): string[] {
    return Array.from({ length: count }, () => randomBytes(5).toString('hex'));
  }

  hashRecovery(code: string) {
    return createHash('sha256').update(code).digest('hex');
  }
}
