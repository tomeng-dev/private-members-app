import { beforeEach, describe, expect, it, vi } from 'vitest';
import { UserStatus } from '@prisma/client';
import { MembersService } from './members.service';

describe('MembersService moderation + dues', () => {
  const prisma: any = {
    user: {
      findUnique: vi.fn(),
      update: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
    },
    refreshToken: { updateMany: vi.fn() },
    duesRecord: { create: vi.fn() },
    $transaction: vi.fn(async (arg: any) => {
      if (typeof arg === 'function') return arg(prisma);
      return arg;
    }),
  };
  const audit = { log: vi.fn() };
  const config = { get: vi.fn() };
  const storage = { getAbsolutePath: vi.fn() };
  const push = { send: vi.fn().mockResolvedValue(undefined) };
  const mail = { send: vi.fn().mockResolvedValue(undefined) };
  let svc: MembersService;

  beforeEach(() => {
    vi.clearAllMocks();
    svc = new MembersService(
      prisma,
      audit as any,
      config as any,
      storage as any,
      push as any,
      mail as any,
    );
  });

  it('suspends member, revokes tokens, notifies', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'm1',
      email: 'a@b.c',
      firstName: 'Ann',
      status: UserStatus.active,
    });
    prisma.user.update.mockResolvedValue({
      id: 'm1',
      status: UserStatus.suspended,
    });
    const res = await svc.moderate(
      'm1',
      { action: 'warn', reason: 'be kind' } as any,
      'actor',
      {},
    );
    expect(res.action).toBe('warn');
    expect(push.send).toHaveBeenCalled();
    expect(mail.send).toHaveBeenCalled();
  });

  it('updates dues with renewal and overdue', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'm1',
      foundingMember: false,
      membershipStatus: 'active',
    });
    prisma.user.update.mockResolvedValue({
      id: 'm1',
      membershipStatus: 'overdue',
      foundingMember: false,
      renewalDate: new Date('2026-01-01'),
    });
    prisma.$transaction.mockImplementation(async (fn: any) => {
      if (typeof fn === 'function') {
        return fn({
          user: { update: prisma.user.update },
          duesRecord: { create: vi.fn() },
        });
      }
      return fn;
    });
    const res = await svc.updateDues(
      'm1',
      {
        membershipStatus: 'overdue',
        renewalDate: '2026-01-01',
        amountUsdCents: 50000,
        notes: 'late',
      } as any,
      'actor',
      {},
    );
    expect(res.membershipStatus).toBe('overdue');
    expect(audit.log).toHaveBeenCalled();
  });
});
