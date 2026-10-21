import { beforeEach, describe, expect, it, vi } from 'vitest';
import { NoopPushAdapter } from './noop-push.adapter';

describe('Push adapters', () => {
  it('noop records notification', async () => {
    const prisma: any = {
      notification: { create: vi.fn().mockResolvedValue({}) },
      device: { findMany: vi.fn() },
    };
    const adapter = new NoopPushAdapter(prisma);
    await adapter.send({
      userId: 'u1',
      title: 'Hi',
      body: 'There',
      data: { type: 'test' },
    });
    expect(prisma.notification.create).toHaveBeenCalled();
  });
});
