import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ForbiddenException, BadRequestException } from '@nestjs/common';
import { MessagingService } from './messaging.service';

describe('MessagingService', () => {
  let service: MessagingService;
  const prisma: any = {
    user: { findFirst: vi.fn() },
    userBlock: { findFirst: vi.fn(), upsert: vi.fn(), deleteMany: vi.fn() },
    conversation: { findFirst: vi.fn(), create: vi.fn(), update: vi.fn() },
    conversationParticipant: {
      findUnique: vi.fn(),
      findMany: vi.fn(),
      update: vi.fn(),
    },
    message: {
      create: vi.fn(),
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      update: vi.fn(),
      findUniqueOrThrow: vi.fn(),
    },
    media: { findMany: vi.fn(), updateMany: vi.fn() },
    post: { findFirst: vi.fn() },
    report: { create: vi.fn() },
    $transaction: vi.fn((fn: any) => fn(prisma)),
  };
  const audit = { log: vi.fn() };
  const push = { send: vi.fn() };

  beforeEach(() => {
    vi.clearAllMocks();
    service = new MessagingService(prisma as any, audit as any, push as any);
  });

  it('blocks self-message start', async () => {
    await expect(service.startDirect('u1', 'u1')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('isBlockedEitherWay true when block exists', async () => {
    prisma.userBlock.findFirst.mockResolvedValue({ blockerId: 'a', blockedId: 'b' });
    await expect(service.isBlockedEitherWay('a', 'b')).resolves.toBe(true);
  });

  it('rejects send when blocked', async () => {
    prisma.conversationParticipant.findUnique.mockResolvedValue({
      conversationId: 'c1',
      userId: 'u1',
    });
    prisma.conversationParticipant.findMany.mockResolvedValue([
      { userId: 'u2' },
    ]);
    prisma.userBlock.findFirst.mockResolvedValue({ blockerId: 'u2', blockedId: 'u1' });
    await expect(
      service.sendMessage('u1', 'c1', { body: 'hi' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('deleteOwnMessage forbids other sender', async () => {
    prisma.message.findUnique.mockResolvedValue({
      id: 'm1',
      senderId: 'other',
      deletedAt: null,
      conversationId: 'c1',
    });
    await expect(service.deleteOwnMessage('u1', 'm1')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
});
