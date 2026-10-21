import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ForbiddenException } from '@nestjs/common';
import { EventsService } from './events.service';

describe('EventsService', () => {
  const prisma: any = {
    event: { findMany: vi.fn(), findFirst: vi.fn(), findUnique: vi.fn(), create: vi.fn(), update: vi.fn() },
    eventRsvp: {
      findUnique: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
      upsert: vi.fn(),
      count: vi.fn(),
      update: vi.fn(),
    },
    eventCheckin: { findUnique: vi.fn(), findMany: vi.fn(), count: vi.fn(), create: vi.fn() },
    eventThread: { upsert: vi.fn() },
    threadComment: {
      findMany: vi.fn(),
      create: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
    },
    threadMute: { findMany: vi.fn(), upsert: vi.fn(), deleteMany: vi.fn() },
    user: { findMany: vi.fn(), findUnique: vi.fn(), findFirst: vi.fn() },
    eventSpeaker: { deleteMany: vi.fn(), createMany: vi.fn() },
    $transaction: vi.fn((fn: any) => fn(prisma)),
  };
  const audit = { log: vi.fn() };
  const push = { send: vi.fn() };
  const mail = { send: vi.fn() };
  const config = { get: vi.fn(() => 'secret'), getOrThrow: vi.fn(() => 'secret') };
  let service: EventsService;

  beforeEach(() => {
    vi.clearAllMocks();
    service = new EventsService(
      prisma,
      audit as any,
      config as any,
      push as any,
      mail as any,
    );
  });

  it('forbids thread post without RSVP/attendance', async () => {
    prisma.event.findFirst.mockResolvedValue({
      id: 'e1',
      title: 'Gala',
      status: 'published',
      deletedAt: null,
      startsAt: new Date(Date.now() + 86400000),
      rsvpCutoffAt: null,
      capacity: null,
      speakers: [],
      thread: { id: 't1' },
      _count: { rsvps: 0, checkins: 0 },
    });
    prisma.eventRsvp.findUnique.mockResolvedValue(null);
    prisma.eventRsvp.count.mockResolvedValue(0);
    prisma.eventCheckin.findUnique.mockResolvedValue(null);
    await expect(
      service.addComment('u1', 'e1', { body: 'hello' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('listForMembers returns items', async () => {
    prisma.event.findMany.mockResolvedValue([{ id: 'e1' }]);
    const res = await service.listForMembers('upcoming');
    expect(res.items).toHaveLength(1);
  });

  it('rsvp respects cut-off', async () => {
    prisma.event.findFirst.mockResolvedValue({
      id: 'e1',
      title: 'Gala',
      status: 'published',
      deletedAt: null,
      startsAt: new Date(Date.now() - 1000),
      rsvpCutoffAt: new Date(Date.now() - 1000),
      capacity: null,
    });
    await expect(
      service.rsvp('u1', 'e1', { status: 'going' as any }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('capacity waitlists when full', async () => {
    prisma.event.findFirst.mockResolvedValue({
      id: 'e1',
      title: 'Gala',
      status: 'published',
      deletedAt: null,
      startsAt: new Date(Date.now() + 86400000),
      rsvpCutoffAt: null,
      capacity: 1,
    });
    prisma.eventRsvp.count.mockResolvedValue(1);
    prisma.eventRsvp.findUnique.mockResolvedValue(null);
    prisma.eventRsvp.upsert.mockResolvedValue({
      id: 'r1',
      status: 'waitlisted',
      paymentStatus: 'unpaid',
    });
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      email: 'a@b.c',
      firstName: 'A',
    });
    const res = await service.rsvp('u1', 'e1', { status: 'going' as any });
    expect(res.status).toBe('waitlisted');
  });
});
