import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { FcmPushAdapter } from './fcm-push.adapter';
import { NoopPushAdapter } from './noop-push.adapter';
import { PUSH_PORT } from './push.port';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [
    NoopPushAdapter,
    FcmPushAdapter,
    {
      provide: PUSH_PORT,
      inject: [ConfigService, NoopPushAdapter, FcmPushAdapter],
      useFactory: (
        config: ConfigService,
        noop: NoopPushAdapter,
        fcm: FcmPushAdapter,
      ) => {
        const provider = (
          config.get<string>('PUSH_PROVIDER') ?? 'noop'
        ).toLowerCase();
        return provider === 'fcm' ? fcm : noop;
      },
    },
  ],
  exports: [PUSH_PORT],
})
export class PushModule {}
