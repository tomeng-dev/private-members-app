import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, limit = 50) {
    const take = Math.min(Math.max(limit, 1), 100);
    const items = await this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take,
    });
    return { items };
  }

  async markRead(userId: string, id: string) {
    const n = await this.prisma.notification.findFirst({
      where: { id, userId },
    });
    if (!n) throw new NotFoundException();
    return this.prisma.notification.update({
      where: { id },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { ok: true };
  }

  async getPrefs(userId: string) {
    return this.prisma.notificationPreference.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  async updatePrefs(userId: string, body: Record<string, boolean>) {
    const data: any = {};
    for (const k of [
      'pushMessages',
      'pushEvents',
      'pushThreads',
      'pushDues',
      'pushApplications',
      'emailEvents',
      'emailDues',
      'emailApplications',
    ]) {
      if (typeof body[k] === 'boolean') data[k] = body[k];
    }
    return this.prisma.notificationPreference.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
    });
  }

  async registerDevice(userId: string, fcmToken: string, platform: string) {
    return this.prisma.device.upsert({
      where: { userId_fcmToken: { userId, fcmToken } },
      create: { userId, fcmToken, platform },
      update: { lastSeenAt: new Date(), revokedAt: null, platform },
    });
  }

  async unregisterDevice(userId: string, fcmToken: string) {
    await this.prisma.device.updateMany({
      where: { userId, fcmToken },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }
}
