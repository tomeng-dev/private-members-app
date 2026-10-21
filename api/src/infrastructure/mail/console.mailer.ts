import { Injectable, Logger } from '@nestjs/common';
import { MailMessage, MailPort } from './mail.port';

/**
 * Dev mailer: logs email to console (and optionally SMTP later).
 * Swap for SES adapter in M8/M11 without changing use cases.
 */
@Injectable()
export class ConsoleMailer implements MailPort {
  private readonly logger = new Logger(ConsoleMailer.name);

  async send(message: MailMessage): Promise<void> {
    this.logger.log(
      `[MAIL] to=${message.to} subject="${message.subject}"\n${message.text}`,
    );
  }
}
