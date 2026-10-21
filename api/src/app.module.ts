import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { GlobalHttpExceptionFilter } from './common/filters/http-exception.filter';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AccessLogInterceptor } from './common/interceptors/access-log.interceptor';
import { RequestIdInterceptor } from './common/interceptors/request-id.interceptor';
import { CryptoModule } from './infrastructure/crypto/crypto.module';
import { MailModule } from './infrastructure/mail/mail.module';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { StorageModule } from './infrastructure/storage/storage.module';
import { ApplicationsModule } from './modules/applications/applications.module';
import { AuditModule } from './modules/audit/audit.module';
import { AuthModule } from './modules/auth/auth.module';
import { HealthModule } from './modules/health/health.module';
import { MembersModule } from './modules/members/members.module';
import { MediaModule } from './modules/media/media.module';
import { ProfilesModule } from './modules/profiles/profiles.module';
import { FeedModule } from './modules/feed/feed.module';
import { MessagingModule } from './modules/messaging/messaging.module';
import { EventsModule } from './modules/events/events.module';
import { PushModule } from './infrastructure/push/push.module';
import { RealtimeModule } from './infrastructure/realtime/realtime.module';
import { AdminModule } from './modules/admin/admin.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { JobsModule } from './modules/jobs/jobs.module';
import { DevModule } from './modules/dev/dev.module';
import { AdminConsoleModule } from './modules/admin-console/admin-console.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => [
        {
          ttl: Number(config.get('THROTTLE_TTL_MS') ?? 60000),
          limit: Number(config.get('THROTTLE_LIMIT') ?? 120),
        },
      ],
    }),
    PrismaModule,
    CryptoModule,
    StorageModule,
    MailModule,
    AuditModule,
    HealthModule,
    AuthModule,
    ApplicationsModule,
    MembersModule,
    MediaModule,
    ProfilesModule,
    FeedModule,
    PushModule,
    RealtimeModule,
    MessagingModule,
    EventsModule,
    AdminModule,
    NotificationsModule,
    JobsModule,
    DevModule,
    AdminConsoleModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_FILTER, useClass: GlobalHttpExceptionFilter },
    { provide: APP_INTERCEPTOR, useClass: RequestIdInterceptor },
    { provide: APP_INTERCEPTOR, useClass: AccessLogInterceptor },
  ],
})
export class AppModule {}
