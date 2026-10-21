import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ForbiddenException } from '@nestjs/common';
import { AdminService } from './admin.service';

describe('AdminService role safeguards', () => {
  const prisma: any = {
    user: { findUnique: vi.fn(), count: vi.fn() },
    userRole: { count: vi.fn(), deleteMany: vi.fn(), createMany: vi.fn() },
    role: { findMany: vi.fn() },
    $transaction: vi.fn((fn: any) => fn(prisma)),
    memberApplication: { count: vi.fn() },
    event: { count: vi.fn() },
    report: { count: vi.fn() },
    eventRsvp: { count: vi.fn() },
    vehicle: { count: vi.fn(), findMany: vi.fn() },
    media: { findUnique: vi.fn() },
  };
  const audit = { log: vi.fn() };
  const storage = { createSignedReadUrl: vi.fn() };
  let svc: AdminService;

  beforeEach(() => {
    vi.clearAllMocks();
    svc = new AdminService(prisma, audit as any, storage as any);
  });

  it('blocks demoting last super_admin', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      roles: [{ role: { name: 'super_admin' } }],
    });
    prisma.userRole.count.mockResolvedValue(1);
    await expect(
      svc.assignRoles('actor', 'u1', ['admin' as any]),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('overview returns metric keys', async () => {
    prisma.user.count.mockResolvedValue(10);
    prisma.memberApplication.count.mockResolvedValue(2);
    prisma.event.count.mockResolvedValue(3);
    prisma.report.count.mockResolvedValue(1);
    prisma.eventRsvp.count.mockResolvedValue(4);
    prisma.vehicle.count.mockResolvedValue(5);
    const o = await svc.overview();
    expect(o).toMatchObject({
      members: 10,
      pendingApplications: 2,
      upcomingEvents: 3,
      openReports: 1,
      rsvpsGoing: 4,
      pendingVehicles: 5,
    });
  });
});
