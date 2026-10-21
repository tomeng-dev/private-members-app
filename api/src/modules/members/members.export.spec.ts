import { beforeEach, describe, expect, it, vi } from 'vitest';
import { MembersService } from './members.service';

describe('MembersService export', () => {
  const prisma: any = {
    user: { findUnique: vi.fn() },
  };
  const audit = { log: vi.fn() };
  const config = { get: vi.fn() };
  const storage = { delete: vi.fn() };
  const push = { send: vi.fn() };
  const mail = { send: vi.fn() };
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

  it('exports profile payload', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      email: 'a@b.c',
      firstName: 'A',
      lastName: 'B',
      phone: null,
      company: null,
      title: null,
      city: null,
      state: null,
      bio: null,
      foundingMember: false,
      membershipStatus: 'active',
      renewalDate: null,
      createdAt: new Date(),
      roles: [{ role: { name: 'member' } }],
      vehicles: [],
      businessPage: null,
      posts: [],
      comments: [],
      eventRsvps: [],
      notificationPreference: null,
      duesRecords: [],
      applications: [],
    });
    const data = await svc.exportMyData('u1');
    expect(data.profile.email).toBe('a@b.c');
    expect(audit.log).toHaveBeenCalled();
  });
});
