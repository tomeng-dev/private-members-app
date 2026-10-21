import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ConsoleMailer } from './console.mailer';
import { MAIL_PORT } from './mail.port';
import { SesMailer } from './ses.mailer';
import { SmtpMailer } from './smtp.mailer';

@Global()
@Module({
  providers: [
    ConsoleMailer,
    SesMailer,
    SmtpMailer,
    {
      provide: MAIL_PORT,
      inject: [ConfigService, ConsoleMailer, SesMailer, SmtpMailer],
      useFactory: (
        config: ConfigService,
        consoleMailer: ConsoleMailer,
        ses: SesMailer,
        smtp: SmtpMailer,
      ) => {
        const provider = (
          config.get<string>('MAIL_PROVIDER') ?? 'console'
        ).toLowerCase();
        if (provider === 'ses') return ses;
        if (provider === 'smtp') return smtp;
        return consoleMailer;
      },
    },
  ],
  exports: [MAIL_PORT],
})
export class MailModule {}
