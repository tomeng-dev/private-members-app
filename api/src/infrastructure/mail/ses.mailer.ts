import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import { MailMessage, MailPort } from './mail.port';

@Injectable()
export class SesMailer implements MailPort {
  private readonly logger = new Logger(SesMailer.name);
  private client: SESClient | null = null;

  constructor(private readonly config: ConfigService) {
    const region = config.get<string>('AWS_REGION') ?? 'us-east-1';
    if (config.get('MAIL_PROVIDER') === 'ses') {
      this.client = new SESClient({ region });
    }
  }

  async send(message: MailMessage): Promise<void> {
    if (!this.client) {
      this.logger.warn('SES not configured; dropping mail');
      return;
    }
    const from = this.config.getOrThrow<string>('MAIL_FROM');
    await this.client.send(
      new SendEmailCommand({
        Source: from,
        Destination: { ToAddresses: [message.to] },
        Message: {
          Subject: { Data: message.subject },
          Body: {
            Text: { Data: message.text },
            ...(message.html ? { Html: { Data: message.html } } : {}),
          },
        },
      }),
    );
  }
}
