import { beforeEach, describe, expect, it, vi } from 'vitest';
import { JobLockService } from './job-lock.service';

describe('JobLockService', () => {
  const prisma: any = {
    jobLock: {
      findUnique: vi.fn(),
      upsert: vi.fn(),
    },
  };
  let svc: JobLockService;

  beforeEach(() => {
    vi.clearAllMocks();
    svc = new JobLockService(prisma);
  });

  it('skips when lock held', async () => {
    prisma.jobLock.findUnique.mockResolvedValue({
      name: 'x',
      expiresAt: new Date(Date.now() + 60_000),
    });
    const fn = vi.fn(async () => 1);
    const res = await svc.withLock('x', 1000, fn);
    expect(res).toBeNull();
    expect(fn).not.toHaveBeenCalled();
  });

  it('runs when free', async () => {
    prisma.jobLock.findUnique.mockResolvedValue(null);
    prisma.jobLock.upsert.mockResolvedValue({});
    const res = await svc.withLock('x', 1000, async () => 42);
    expect(res).toBe(42);
  });
});
