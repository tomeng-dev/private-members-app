import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';

/** Optional Have I Been Pwned range API (k-anonymity). Off by default. */
@Injectable()
export class HibpService {
  private readonly logger = new Logger(HibpService.name);

  constructor(private readonly config: ConfigService) {}

  enabled() {
    return (
      (this.config.get('HIBP_ENABLED') ?? 'false').toLowerCase() === 'true'
    );
  }

  async isBreached(password: string): Promise<boolean> {
    if (!this.enabled()) return false;
    const sha1 = createHash('sha1')
      .update(password)
      .digest('hex')
      .toUpperCase();
    const prefix = sha1.slice(0, 5);
    const suffix = sha1.slice(5);
    try {
      const res = await fetch(
        `https://api.pwnedpasswords.com/range/${prefix}`,
        {
          headers: {
            'Add-Padding': 'true',
            'User-Agent': 'private-members-app',
          },
        },
      );
      if (!res.ok) {
        this.logger.warn(`HIBP HTTP ${res.status}`);
        return false;
      }
      const text = await res.text();
      return text.split('\n').some((line) => line.startsWith(suffix));
    } catch (e) {
      this.logger.warn(`HIBP check failed: ${String(e)}`);
      return false;
    }
  }
}
