import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
  StreamableFile,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MembershipStatus, UserStatus } from '@prisma/client';
import { MAIL_PORT, MailPort } from '../../infrastructure/mail/mail.port';
import { PUSH_PORT, PushPort } from '../../infrastructure/push/push.port';
import { emailTemplates } from '../../infrastructure/mail/templates/email-layout';
import { ModerationActionDto } from './dto/moderation.dto';
import { createReadStream } from 'fs';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  STORAGE_PORT,
  StoragePort,
} from '../../infrastructure/storage/storage.port';
import { UpdateDuesDto } from './dto/update-dues.dto';

@Injectable()
export class MembersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly config: ConfigService,
    @Inject(STORAGE_PORT) private readonly storage: StoragePort,
    @Inject(PUSH_PORT) private readonly push: PushPort,
    @Inject(MAIL_PORT) private readonly mail: MailPort,
  ) {}

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { roles: { include: { role: true } } },
    });
    if (!user) throw new NotFoundException();
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      company: user.company,
      title: user.title,
      city: user.city,
      state: user.state,
      bio: user.bio,
      foundingMember: user.foundingMember,
      membershipStatus: user.membershipStatus,
      renewalDate: user.renewalDate,
      roles: user.roles.map((r) => r.role.name),
      status: user.status,
    };
  }

  async requestDeletion(userId: string, meta: { ip?: string; ua?: string }) {
    const graceDays = Number(
      this.config.get('ACCOUNT_DELETION_GRACE_DAYS') ?? 14,
    );
    const scheduled = new Date(Date.now() + graceDays * 86400000);
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        deletionRequestedAt: new Date(),
        deletionScheduledAt: scheduled,
        // Keep status active until grace ends so export still works; block login via jwt/strategy
        status: UserStatus.suspended,
      },
    });
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    await this.prisma.device.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    await this.audit.log({
      actorId: userId,
      action: 'account.deletion_requested',
      targetType: 'user',
      targetId: userId,
      metadata: { graceDays, scheduledAt: scheduled.toISOString() },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    return {
      ok: true,
      message: `Account scheduled for deletion in ${graceDays} days`,
      deletionScheduledAt: scheduled,
    };
  }

  async cancelDeletion(userId: string, meta: { ip?: string; ua?: string }) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.deletionRequestedAt)
      throw new BadRequestException('No pending deletion');
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        deletionRequestedAt: null,
        deletionScheduledAt: null,
        status: UserStatus.active,
      },
    });
    await this.audit.log({
      actorId: userId,
      action: 'account.deletion_cancelled',
      targetType: 'user',
      targetId: userId,
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    return { ok: true };
  }

  async exportMyData(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        roles: { include: { role: true } },
        vehicles: true,
        businessPage: true,
        posts: { where: { deletedAt: null }, take: 500 },
        comments: { take: 500 },
        eventRsvps: {
          include: {
            event: { select: { id: true, title: true, startsAt: true } },
          },
        },
        notificationPreference: true,
        duesRecords: true,
        applications: true,
      },
    });
    if (!user) throw new NotFoundException();
    await this.audit.log({
      actorId: userId,
      action: 'account.data_exported',
      targetType: 'user',
      targetId: userId,
    });
    return {
      exportedAt: new Date().toISOString(),
      profile: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        company: user.company,
        title: user.title,
        city: user.city,
        state: user.state,
        bio: user.bio,
        foundingMember: user.foundingMember,
        membershipStatus: user.membershipStatus,
        renewalDate: user.renewalDate,
        roles: user.roles.map((r) => r.role.name),
        createdAt: user.createdAt,
      },
      vehicles: user.vehicles,
      businessPage: user.businessPage,
      posts: user.posts,
      comments: user.comments,
      eventRsvps: user.eventRsvps,
      notificationPreference: user.notificationPreference,
      duesRecords: user.duesRecords,
      applications: user.applications.map((a) => ({
        id: a.id,
        status: a.status,
        createdAt: a.createdAt,
        consentPrivacyVersion: a.consentPrivacyVersion,
        consentTermsVersion: a.consentTermsVersion,
      })),
    };
  }

  /** Called by scheduled job after grace period. */
  async finalizeDeletion(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return;
    const media = await this.prisma.media.findMany({
      where: { ownerId: userId, deletedAt: null },
    });
    for (const m of media) {
      try {
        await this.storage.delete(m.storageKey);
      } catch {
        /* ignore */
      }
      await this.prisma.media.update({
        where: { id: m.id },
        data: { deletedAt: new Date() },
      });
    }
    await this.prisma.post.updateMany({
      where: { authorId: userId },
      data: { body: '[deleted]', deletedAt: new Date() },
    });
    await this.prisma.comment.updateMany({
      where: { authorId: userId },
      data: { body: '[deleted]', deletedAt: new Date() },
    });
    await this.prisma.message.updateMany({
      where: { senderId: userId },
      data: { body: '[deleted]' },
    });
    const anonEmail = `deleted+${userId.slice(0, 8)}@invalid.local`;
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        email: anonEmail,
        passwordHash: null,
        firstName: 'Deleted',
        lastName: 'Member',
        phone: null,
        company: null,
        title: null,
        city: null,
        state: null,
        bio: null,
        avatarKey: null,
        totpSecret: null,
        totpRecoveryHashes: null,
        status: UserStatus.deleted,
        deletedAt: new Date(),
        deletionRequestedAt: user.deletionRequestedAt,
        deletionScheduledAt: user.deletionScheduledAt,
      },
    });
    await this.audit.log({
      action: 'account.deletion_finalized',
      targetType: 'user',
      targetId: userId,
    });
  }

  async listMembers() {
    const users = await this.prisma.user.findMany({
      where: { status: { not: UserStatus.deleted } },
      orderBy: { createdAt: 'desc' },
      include: {
        roles: { include: { role: true } },
        duesRecords: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });
    return users.map((u) => ({
      id: u.id,
      email: u.email,
      firstName: u.firstName,
      lastName: u.lastName,
      foundingMember: u.foundingMember,
      membershipStatus: u.membershipStatus,
      renewalDate: u.renewalDate,
      status: u.status,
      roles: u.roles.map((r) => r.role.name),
      latestDues: u.duesRecords[0] ?? null,
      createdAt: u.createdAt,
    }));
  }

  async updateDues(
    memberId: string,
    dto: UpdateDuesDto,
    actorId: string,
    meta: { ip?: string; ua?: string },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: memberId } });
    if (!user) throw new NotFoundException('Member not found');

    if (dto.foundingMember === true && !user.foundingMember) {
      const cap = Number(this.config.get('FOUNDING_MEMBER_CAP') ?? 20);
      const count = await this.prisma.user.count({
        where: { foundingMember: true, status: { not: UserStatus.deleted } },
      });
      if (count >= cap) {
        throw new BadRequestException(`Founding member cap of ${cap} reached`);
      }
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const u = await tx.user.update({
        where: { id: memberId },
        data: {
          membershipStatus: dto.membershipStatus,
          foundingMember:
            dto.foundingMember === undefined ? undefined : dto.foundingMember,
          renewalDate: (dto as any).renewalDate
            ? new Date((dto as any).renewalDate)
            : dto.membershipStatus === MembershipStatus.active
              ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
              : undefined,
        },
      });
      await tx.duesRecord.create({
        data: {
          userId: memberId,
          status: dto.membershipStatus,
          externalRef: dto.externalRef,
          notes: dto.notes,
          amountUsdCents: (dto as any).amountUsdCents,
          markedPaidAt:
            dto.membershipStatus === MembershipStatus.active
              ? new Date()
              : null,
          markedPaidById: actorId,
        },
      });
      return u;
    });

    await this.audit.log({
      actorId,
      action: 'member.dues_updated',
      targetType: 'user',
      targetId: memberId,
      metadata: { ...dto },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });

    return {
      id: updated.id,
      membershipStatus: updated.membershipStatus,
      foundingMember: updated.foundingMember,
      renewalDate: updated.renewalDate,
    };
  }

  async getProofFile(
    mediaId: string,
  ): Promise<{ file: StreamableFile; mime: string; name: string }> {
    const media = await this.prisma.media.findUnique({
      where: { id: mediaId },
    });
    if (!media || media.deletedAt)
      throw new NotFoundException('File not found');
    if (media.ownerType !== 'verification') {
      throw new BadRequestException('Not a verification document');
    }
    const abs = this.storage.getAbsolutePath(media.storageKey);
    const stream = createReadStream(abs);
    return {
      file: new StreamableFile(stream),
      mime: media.mimeType,
      name: media.storageKey.split('/').pop() ?? 'proof',
    };
  }

  async listAuditLogs(limit = 50) {
    const take = Math.min(Math.max(limit, 1), 200);
    const rows = await this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take,
      include: {
        actor: {
          select: { id: true, email: true, firstName: true, lastName: true },
        },
      },
    });
    return rows.map((r) => ({
      id: r.id,
      action: r.action,
      targetType: r.targetType,
      targetId: r.targetId,
      metadata: r.metadata ? JSON.parse(r.metadata) : null,
      ipAddress: r.ipAddress,
      userAgent: r.userAgent,
      createdAt: r.createdAt,
      actor: r.actor,
    }));
  }

  async moderate(
    memberId: string,
    dto: ModerationActionDto,
    actorId: string,
    meta: { ip?: string; ua?: string },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: memberId } });
    if (!user) throw new NotFoundException('Member not found');
    let status = user.status;
    if (dto.action === 'suspend') status = UserStatus.suspended;
    if (dto.action === 'reinstate') status = UserStatus.active;
    const updated = await this.prisma.user.update({
      where: { id: memberId },
      data: { status },
    });
    if (dto.action === 'suspend') {
      await this.prisma.refreshToken.updateMany({
        where: { userId: memberId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    await this.audit.log({
      actorId,
      action: `member.${dto.action}`,
      targetType: 'user',
      targetId: memberId,
      metadata: { reason: dto.reason },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    void this.push.send({
      userId: memberId,
      title: 'Account notice',
      body: `Your account was ${dto.action}: ${dto.reason}`.slice(0, 180),
      data: { type: 'moderation', action: dto.action },
    });
    void this.mail.send({
      to: user.email,
      subject: 'Account notice',
      text: `Your account was ${dto.action}. Reason: ${dto.reason}`,
      html: emailTemplates.moderation(user.firstName, dto.action, dto.reason),
    });
    return { id: updated.id, status: updated.status, action: dto.action };
  }
}
