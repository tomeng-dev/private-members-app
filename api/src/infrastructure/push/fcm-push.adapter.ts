import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { PushPayload, PushPort } from './push.port';

/**
 * Firebase Cloud Messaging adapter. Loads credentials from FIREBASE_SERVICE_ACCOUNT_JSON
 * or FIREBASE_SERVICE_ACCOUNT_PATH. If unset, sends are no-ops (local/dev safe).
 */
@Injectable()
export class FcmPushAdapter implements PushPort, OnModuleInit {
  private readonly logger = new Logger(FcmPushAdapter.name);
  private messaging: { send: (msg: unknown) => Promise<string> } | null = null;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async onModuleInit() {
    try {
      const json = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
      const path = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH');
      if (!json && !path) {
        this.logger.warn('FCM not configured — push deliveries are no-ops');
        return;
      }
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const admin = require('firebase-admin') as any;
      if (!admin.apps.length) {
        const cred = json
          ? admin.credential.cert(JSON.parse(json))
          : admin.credential.cert(path);
        admin.initializeApp({ credential: cred });
      }
      this.messaging = admin.messaging();
      this.logger.log('FCM initialized');
    } catch (e) {
      this.logger.warn(`FCM init failed: ${String(e)}`);
      this.messaging = null;
    }
  }

  async send(payload: PushPayload): Promise<void> {
    const devices = await this.prisma.device.findMany({
      where: { userId: payload.userId, revokedAt: null },
    });
    await this.prisma.notification.create({
      data: {
        userId: payload.userId,
        channel: 'push',
        title: payload.title,
        body: payload.body,
        dataJson: payload.data ? JSON.stringify(payload.data) : null,
      },
    });
    if (!devices.length || !this.messaging) {
      this.logger.debug(`FCM noop → ${payload.userId} ${payload.title}`);
      return;
    }
    for (const d of devices) {
      try {
        await this.messaging.send({
          token: d.fcmToken,
          notification: { title: payload.title, body: payload.body },
          data: payload.data,
        });
      } catch (e) {
        this.logger.warn(`FCM send failed token=${d.id}: ${String(e)}`);
      }
    }
  }
}
