import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import {
  EventStatus,
  MediaOwnerType,
  MembershipStatus,
  RsvpStatus,
} from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { MAIL_PORT, MailPort } from '../../infrastructure/mail/mail.port';
import { PUSH_PORT, PushPort } from '../../infrastructure/push/push.port';
import { emailTemplates } from '../../infrastructure/mail/templates/email-layout';
import {
  STORAGE_PORT,
  StoragePort,
} from '../../infrastructure/storage/storage.port';
import { JobLockService } from './job-lock.service';
import { MembersService } from '../members/members.service';

@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly locks: JobLockService,
    private readonly config: ConfigService,
    private readonly members: MembersService,
    @Inject(PUSH_PORT) private readonly push: PushPort,
    @Inject(MAIL_PORT) private readonly mail: MailPort,
    @Inject(STORAGE_PORT) private readonly storage: StoragePort,
  ) {}

  private enabled() {
    return (
      (this.config.get('SCHEDULE_ENABLED') ?? 'true').toLowerCase() !== 'false'
    );
  }

  @Cron('15 9 * * *') // 09:15 daily
  async eventReminders1d() {
    if (!this.enabled()) return;
    await this.locks.withLock('event-reminders-1d', 10 * 60_000, async () => {
      const start = new Date();
      start.setHours(0, 0, 0, 0);
      start.setDate(start.getDate() + 1);
      const end = new Date(start);
      end.setDate(end.getDate() + 1);
      const events = await this.prisma.event.findMany({
        where: {
          status: EventStatus.published,
          deletedAt: null,
          startsAt: { gte: start, lt: end },
        },
      });
      let n = 0;
      for (const event of events) {
        const rsvps = await this.prisma.eventRsvp.findMany({
          where: { eventId: event.id, status: RsvpStatus.going },
          include: { user: true },
        });
        for (const r of rsvps) {
          const prefs = await this.prisma.notificationPreference.findUnique({
            where: { userId: r.userId },
          });
          if (prefs && prefs.pushEvents === false) continue;
          void this.push.send({
            userId: r.userId,
            title: event.title,
            body: 'Reminder: your event is tomorrow',
            data: { type: 'event_reminder', eventId: event.id, kind: '1d' },
          });
          if (!prefs || prefs.emailEvents !== false) {
            void this.mail.send({
              to: r.user.email,
              subject: `Reminder: ${event.title}`,
              text: `Hi ${r.user.firstName}, ${event.title} is tomorrow.`,
              html: emailTemplates.eventReminder(
                r.user.firstName,
                event.title,
                'tomorrow',
              ),
            });
          }
          n++;
        }
      }
      this.logger.log(`event-reminders-1d queued=${n}`);
      return n;
    });
  }

  @Cron('30 9 * * *')
  async duesReminders() {
    if (!this.enabled()) return;
    await this.locks.withLock('dues-reminders', 10 * 60_000, async () => {
      const in14 = new Date();
      in14.setDate(in14.getDate() + 14);
      const users = await this.prisma.user.findMany({
        where: {
          deletedAt: null,
          OR: [
            { membershipStatus: MembershipStatus.overdue },
            {
              membershipStatus: MembershipStatus.dues_due,
            },
            {
              renewalDate: {
                lte: in14,
                gte: new Date(),
              },
            },
          ],
        },
        take: 500,
      });
      let n = 0;
      for (const u of users) {
        const prefs = await this.prisma.notificationPreference.findUnique({
          where: { userId: u.id },
        });
        if (prefs && prefs.pushDues === false) continue;
        void this.push.send({
          userId: u.id,
          title: 'Membership dues',
          body: 'A dues reminder for your membership',
          data: { type: 'dues_reminder' },
        });
        if (!prefs || prefs.emailDues !== false) {
          void this.mail.send({
            to: u.email,
            subject: 'Membership dues reminder',
            text: `Hi ${u.firstName}, dues reminder.`,
            html: emailTemplates.duesReminder(
              u.firstName,
              u.renewalDate?.toISOString().slice(0, 10) ?? 'soon',
            ),
          });
        }
        n++;
      }
      this.logger.log(`dues-reminders queued=${n}`);
      return n;
    });
  }

  /** Delete verification docs older than retention after decision (default 30 days). */
  @Cron('0 3 * * *')
  async verificationDocCleanup() {
    if (!this.enabled()) return;
    await this.locks.withLock(
      'verification-doc-cleanup',
      30 * 60_000,
      async () => {
        const days = Number(
          this.config.get('VERIFICATION_DOC_RETENTION_DAYS') ?? 30,
        );
        const cutoff = new Date(Date.now() - days * 86400000);
        // Vehicles decided (approved/rejected) before cutoff — purge their verification media
        const vehicles = await this.prisma.vehicle.findMany({
          where: {
            verificationStatus: { in: ['approved', 'rejected'] },
            updatedAt: { lt: cutoff },
            deletedAt: null,
          },
          select: { id: true },
        });
        const ids = vehicles.map((v) => v.id);
        if (!ids.length) return 0;
        const media = await this.prisma.media.findMany({
          where: {
            ownerType: MediaOwnerType.verification,
            ownerId: { in: ids },
            deletedAt: null,
          },
        });
        for (const m of media) {
          try {
            await this.storage.delete(m.storageKey);
          } catch {
            /* ignore missing */
          }
          await this.prisma.media.update({
            where: { id: m.id },
            data: { deletedAt: new Date() },
          });
        }
        this.logger.log(`verification-doc-cleanup deleted=${media.length}`);
        return media.length;
      },
    );
  }

  @Cron('45 3 * * *')
  async accountDeletionFinalize() {
    if (!this.enabled()) return;
    await this.locks.withLock(
      'account-deletion-finalize',
      30 * 60_000,
      async () => {
        const due = await this.prisma.user.findMany({
          where: {
            deletionScheduledAt: { lte: new Date() },
            deletedAt: null,
            NOT: { deletionRequestedAt: null },
          },
          take: 100,
          select: { id: true },
        });
        for (const u of due) {
          await this.members.finalizeDeletion(u.id);
        }
        this.logger.log(`account-deletion-finalize count=${due.length}`);
        return due.length;
      },
    );
  }

  /** Test helper */
  async runVerificationCleanupNow() {
    return this.verificationDocCleanup();
  }
}
