import { describe, expect, it, vi } from 'vitest';
import { HibpService } from './hibp.service';

describe('HibpService', () => {
  it('skips when disabled', async () => {
    const svc = new HibpService({ get: () => 'false' } as any);
    expect(await svc.isBreached('password')).toBe(false);
  });

  it('detects breached hash when enabled', async () => {
    const svc = new HibpService({ get: () => 'true' } as any);
    // sha1("password") = 5BAA6... — mock fetch
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        text: async () => '1E4C9B93F3F0682250B6CF8331B7EE68FD8:100\n',
      }),
    );
    // "password" -> 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8
    expect(await svc.isBreached('password')).toBe(true);
    vi.unstubAllGlobals();
  });
});
