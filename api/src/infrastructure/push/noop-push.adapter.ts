import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PushPayload, PushPort } from './push.port';

@Injectable()
export class NoopPushAdapter implements PushPort {
  private readonly logger = new Logger(NoopPushAdapter.name);

  constructor(private readonly prisma: PrismaService) {}

  async send(payload: PushPayload): Promise<void> {
    await this.prisma.notification.create({
      data: {
        userId: payload.userId,
        channel: 'in_app',
        title: payload.title,
        body: payload.body,
        dataJson: payload.data ? JSON.stringify(payload.data) : null,
      },
    });
    this.logger.debug(
      `push noop → user=${payload.userId} title=${payload.title}`,
    );
  }
}
