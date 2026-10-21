import { Injectable } from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';

@Injectable()
export class TokenService {
  /** Opaque random token for refresh / password-reset / invite. */
  generateOpaque(bytes = 32): string {
    return randomBytes(bytes).toString('base64url');
  }

  hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
