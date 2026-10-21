import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer, { type Transporter } from 'nodemailer';
import { MailMessage, MailPort } from './mail.port';

/** Dev SMTP (Mailpit) or generic SMTP. */
@Injectable()
export class SmtpMailer implements MailPort {
  private readonly logger = new Logger(SmtpMailer.name);
  private transporter: Transporter;

  constructor(config: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: config.get('MAIL_HOST') ?? 'localhost',
      port: Number(config.get('MAIL_PORT') ?? 1025),
      secure: false,
      auth:
        config.get('MAIL_USER') && config.get('MAIL_PASS')
          ? {
              user: config.get<string>('MAIL_USER'),
              pass: config.get<string>('MAIL_PASS'),
            }
          : undefined,
    });
  }

  async send(message: MailMessage): Promise<void> {
    const from = process.env.MAIL_FROM ?? 'noreply@example.com';
    await this.transporter.sendMail({
      from,
      to: message.to,
      subject: message.subject,
      text: message.text,
      html: message.html,
    });
    this.logger.debug(`SMTP mail → ${message.to} "${message.subject}"`);
  }
}
