import { describe, expect, it, vi } from 'vitest';
import { NotFoundException } from '@nestjs/common';
import { DevController } from './dev.controller';

const prisma: any = { user: { findMany: vi.fn().mockResolvedValue([]) } };
const cfg = (m: Record<string, string>) => ({ get: (k: string) => m[k] }) as any;

describe('DevController production guard', () => {
  it('refuses account list in production', async () => {
    const c = new DevController(
      cfg({ NODE_ENV: 'production', DEV_DEFAULT_MEMBER_PASSWORD: 'test-only-pw-0001' }),
      prisma,
    );
    await expect(c.accounts()).rejects.toBeInstanceOf(NotFoundException);
  });
  it('refuses when APP_ENV=production even if NODE_ENV=development', async () => {
    const c = new DevController(
      cfg({ NODE_ENV: 'development', APP_ENV: 'production', DEV_DEFAULT_MEMBER_PASSWORD: 'test-only-pw-0001' }),
      prisma,
    );
    await expect(c.accounts()).rejects.toBeInstanceOf(NotFoundException);
  });
  it('lists accounts in development', async () => {
    const c = new DevController(
      cfg({ NODE_ENV: 'development', DEV_DEFAULT_MEMBER_PASSWORD: 'test-only-pw-0001' }),
      prisma,
    );
    const res = await c.accounts();
    expect(res.items).toEqual([]);
  });
});
