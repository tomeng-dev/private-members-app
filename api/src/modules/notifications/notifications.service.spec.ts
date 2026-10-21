import { beforeEach, describe, expect, it, vi } from 'vitest';
import { NotificationsService } from './notifications.service';

describe('NotificationsService prefs', () => {
  const prisma: any = {
    notification: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
      create: vi.fn(),
    },
    notificationPreference: { upsert: vi.fn() },
    device: { upsert: vi.fn(), updateMany: vi.fn() },
  };
  let svc: NotificationsService;

  beforeEach(() => {
    vi.clearAllMocks();
    svc = new NotificationsService(prisma);
  });

  it('updates only known preference keys', async () => {
    prisma.notificationPreference.upsert.mockResolvedValue({
      userId: 'u1',
      pushEvents: false,
    });
    await svc.updatePrefs('u1', {
      pushEvents: false,
      evil: true,
    } as any);
    expect(prisma.notificationPreference.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        update: { pushEvents: false },
      }),
    );
  });

  it('registers device token', async () => {
    prisma.device.upsert.mockResolvedValue({ id: 'd1' });
    await svc.registerDevice('u1', 'tok', 'android');
    expect(prisma.device.upsert).toHaveBeenCalled();
  });
});
