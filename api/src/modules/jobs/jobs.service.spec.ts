import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { JobsService } from './jobs.service';

describe('JobsService scheduled work', () => {
  const prisma: any = {
    event: { findMany: vi.fn() },
    eventRsvp: { findMany: vi.fn() },
    user: { findMany: vi.fn() },
    vehicle: { findMany: vi.fn() },
    media: { findMany: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
    notificationPreference: { findUnique: vi.fn().mockResolvedValue(null) },
  };
  const locks = {
    withLock: vi.fn(async (_n: string, _t: number, fn: () => Promise<unknown>) =>
      fn(),
    ),
  };
  const config = {
    get: vi.fn((k: string) => {
      if (k === 'SCHEDULE_ENABLED') return 'true';
      return undefined;
    }),
  };
  const push = { send: vi.fn().mockResolvedValue(undefined) };
  const mail = { send: vi.fn().mockResolvedValue(undefined) };
  const storage = { delete: vi.fn().mockResolvedValue(undefined) };
  let svc: JobsService;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-19T12:00:00+08:00'));
    const members = { finalizeDeletion: vi.fn() };
    svc = new JobsService(
      prisma,
      locks as any,
      config as any,
      members as any,
      push as any,
      mail as any,
      storage as any,
    );
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('skips when schedule disabled', async () => {
    config.get.mockReturnValue('false');
    await svc.eventReminders1d();
    expect(locks.withLock).not.toHaveBeenCalled();
  });

  it('queues event reminders for tomorrow', async () => {
    config.get.mockImplementation((k: string) =>
      k === 'SCHEDULE_ENABLED' ? 'true' : undefined,
    );
    prisma.event.findMany.mockResolvedValue([
      { id: 'e1', title: 'Dinner', startsAt: new Date('2026-10-20T19:00:00+08:00') },
    ]);
    prisma.eventRsvp.findMany.mockResolvedValue([
      {
        userId: 'u1',
        user: { id: 'u1', email: 'a@b.c', firstName: 'Ann' },
      },
    ]);
    await svc.eventReminders1d();
    expect(push.send).toHaveBeenCalled();
    expect(mail.send).toHaveBeenCalled();
  });
});
