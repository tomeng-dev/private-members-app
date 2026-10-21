import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ApplicationStatus,
  MediaKind,
  MediaOwnerType,
  MembershipStatus,
  RoleName,
  UserStatus,
} from '@prisma/client';
import { AuthService } from '../auth/auth.service';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { MAIL_PORT, MailPort } from '../../infrastructure/mail/mail.port';
import { devDefaultMemberPassword } from '../../common/env/runtime-env';
import { PasswordService } from '../../infrastructure/crypto/password.service';
import { emailTemplates } from '../../infrastructure/mail/templates/email-layout';
import {
  STORAGE_PORT,
  StoragePort,
} from '../../infrastructure/storage/storage.port';
import { CreateApplicationDto } from './dto/create-application.dto';
import { ReviewApplicationDto } from './dto/review-application.dto';
import { canGrantFoundingMember } from './domain/founding.policy';

@Injectable()
export class ApplicationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly audit: AuditService,
    private readonly auth: AuthService,
    private readonly passwords: PasswordService,
    @Inject(MAIL_PORT) private readonly mail: MailPort,
    @Inject(STORAGE_PORT) private readonly storage: StoragePort,
  ) {}

  async apply(dto: CreateApplicationDto, meta: { ip?: string; ua?: string }) {
    if (!dto.consentPrivacy || !dto.consentTerms) {
      throw new BadRequestException(
        'Privacy Notice and Terms consent are required',
      );
    }
    const email = dto.email.toLowerCase();

    const existingUser = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existingUser && existingUser.status !== UserStatus.deleted) {
      throw new ConflictException('An account with this email already exists');
    }

    const open = await this.prisma.memberApplication.findFirst({
      where: {
        email,
        status: {
          in: [
            ApplicationStatus.submitted,
            ApplicationStatus.under_review,
            ApplicationStatus.more_info_needed,
          ],
        },
      },
    });
    if (open) {
      throw new ConflictException('You already have an open application');
    }

    let inviteId: string | undefined;
    if (dto.inviteCode) {
      const invite = await this.prisma.invite.findUnique({
        where: { code: dto.inviteCode.trim() },
      });
      if (!invite || invite.status !== 'active') {
        throw new BadRequestException('Invalid invite code');
      }
      if (invite.expiresAt && invite.expiresAt < new Date()) {
        throw new BadRequestException('Invite code expired');
      }
      if (invite.useCount >= invite.maxUses) {
        throw new BadRequestException('Invite code already used');
      }
      inviteId = invite.id;
    }

    const privacyVersion = this.config.get('PRIVACY_VERSION') ?? '1.0';
    const termsVersion = this.config.get('TERMS_VERSION') ?? '1.0';
    const now = new Date();

    const application = await this.prisma.$transaction(async (tx) => {
      const app = await tx.memberApplication.create({
        data: {
          email,
          firstName: dto.firstName.trim(),
          lastName: dto.lastName.trim(),
          phone: dto.phone,
          company: dto.company,
          title: dto.title,
          city: dto.city,
          state: dto.state,
          vehicleMake: dto.vehicleMake.trim(),
          vehicleModel: dto.vehicleModel.trim(),
          vehicleYear: dto.vehicleYear,
          vehicleEstimatedValue: dto.vehicleEstimatedValue,
          inviteId,
          consentPrivacyAt: now,
          consentPrivacyVersion: privacyVersion,
          consentTermsAt: now,
          consentTermsVersion: termsVersion,
          status: ApplicationStatus.submitted,
        },
      });
      if (inviteId) {
        await tx.invite.update({
          where: { id: inviteId },
          data: {
            useCount: { increment: 1 },
          },
        });
      }
      return app;
    });

    await this.audit.log({
      action: 'application.submitted',
      targetType: 'member_application',
      targetId: application.id,
      metadata: { email },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });

    return this.toPublic(application);
  }

  async uploadProof(
    applicationId: string,
    email: string,
    file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('File required');
    const allowed = [
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
    ];
    if (!allowed.includes(file.mimetype)) {
      throw new BadRequestException('Only JPEG, PNG, WebP, or PDF allowed');
    }
    const max = 15 * 1024 * 1024;
    if (file.size > max) {
      throw new BadRequestException('File too large (max 15MB)');
    }

    const app = await this.prisma.memberApplication.findUnique({
      where: { id: applicationId },
    });
    if (!app || app.email.toLowerCase() !== email.toLowerCase()) {
      throw new NotFoundException('Application not found');
    }
    if (
      ![
        ApplicationStatus.submitted,
        ApplicationStatus.under_review,
        ApplicationStatus.more_info_needed,
      ].includes(app.status as any)
    ) {
      throw new BadRequestException('Application is closed for uploads');
    }

    const stored = await this.storage.putPrivate({
      folder: 'verification',
      originalName: file.originalname,
      mimeType: file.mimetype,
      buffer: file.buffer,
    });

    const media = await this.prisma.media.create({
      data: {
        ownerType: MediaOwnerType.verification,
        ownerId: applicationId,
        applicationId,
        kind:
          file.mimetype === 'application/pdf'
            ? MediaKind.document
            : MediaKind.image,
        storageKey: stored.key,
        mimeType: stored.mimeType,
        sizeBytes: stored.sizeBytes,
        isPrivate: true,
      },
    });

    return {
      id: media.id,
      mimeType: media.mimeType,
      sizeBytes: media.sizeBytes,
      kind: media.kind,
    };
  }

  async getStatusByEmail(email: string) {
    const app = await this.prisma.memberApplication.findFirst({
      where: { email: email.toLowerCase() },
      orderBy: { createdAt: 'desc' },
      include: {
        proofMedia: {
          where: { deletedAt: null },
          select: {
            id: true,
            kind: true,
            mimeType: true,
            sizeBytes: true,
            createdAt: true,
          },
        },
      },
    });
    if (!app) throw new NotFoundException('No application found');
    return this.toPublic(app);
  }

  async getById(id: string) {
    const app = await this.prisma.memberApplication.findUnique({
      where: { id },
      include: {
        proofMedia: { where: { deletedAt: null } },
        invite: true,
      },
    });
    if (!app) throw new NotFoundException('Application not found');
    return app;
  }

  async listForAdmin(status?: ApplicationStatus) {
    return this.prisma.memberApplication.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'asc' },
      include: {
        proofMedia: {
          where: { deletedAt: null },
          select: { id: true, kind: true, mimeType: true, sizeBytes: true },
        },
      },
    });
  }

  async review(
    id: string,
    dto: ReviewApplicationDto,
    reviewerId: string,
    meta: { ip?: string; ua?: string },
  ) {
    const app = await this.prisma.memberApplication.findUnique({
      where: { id },
    });
    if (!app) throw new NotFoundException('Application not found');
    if (
      ![
        ApplicationStatus.submitted,
        ApplicationStatus.under_review,
        ApplicationStatus.more_info_needed,
      ].includes(app.status as any)
    ) {
      throw new BadRequestException('Application already decided');
    }

    if (dto.decision === 'more_info') {
      const updated = await this.prisma.memberApplication.update({
        where: { id },
        data: {
          status: ApplicationStatus.more_info_needed,
          moreInfoMessage: dto.moreInfoMessage,
          internalNote: dto.internalNote,
          reviewedById: reviewerId,
          reviewedAt: new Date(),
        },
      });
      await this.mail.send({
        to: app.email,
        subject: 'More information needed for your application',
        text:
          dto.moreInfoMessage ??
          'Please provide additional information for your membership application.',
      });
      await this.audit.log({
        actorId: reviewerId,
        action: 'application.more_info',
        targetType: 'member_application',
        targetId: id,
        metadata: { note: dto.internalNote },
        ipAddress: meta.ip,
        userAgent: meta.ua,
      });
      return this.toPublic(updated);
    }

    if (dto.decision === 'decline') {
      const updated = await this.prisma.memberApplication.update({
        where: { id },
        data: {
          status: ApplicationStatus.declined,
          declineReason: dto.declineReason,
          internalNote: dto.internalNote,
          reviewedById: reviewerId,
          reviewedAt: new Date(),
        },
      });
      await this.mail.send({
        to: app.email,
        subject: 'Update on your membership application',
        text:
          dto.declineReason ??
          'Your membership application was not approved at this time.',
      });
      await this.audit.log({
        actorId: reviewerId,
        action: 'application.declined',
        targetType: 'member_application',
        targetId: id,
        metadata: { reason: dto.declineReason },
        ipAddress: meta.ip,
        userAgent: meta.ua,
      });
      return this.toPublic(updated);
    }

    // approve
    const memberRole = await this.prisma.role.findUnique({
      where: { name: RoleName.member },
    });
    if (!memberRole)
      throw new BadRequestException('member role missing — run seed');

    const cap = Number(this.config.get('FOUNDING_MEMBER_CAP') ?? 20);
    const foundingCount = await this.prisma.user.count({
      where: { foundingMember: true, status: { not: UserStatus.deleted } },
    });
    if (dto.grantFoundingMember === true && foundingCount >= cap) {
      throw new BadRequestException(
        `Founding member cap of ${cap} already reached`,
      );
    }
    const founding = canGrantFoundingMember(
      foundingCount,
      cap,
      dto.grantFoundingMember,
    );

    // Development only: approved members get the documented dev password so
    // they can sign in immediately. Production always uses the set-password email.
    const devPw = devDefaultMemberPassword(this.config);
    const devHash = devPw ? await this.passwords.hash(devPw) : null;

    const result = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email: app.email,
          firstName: app.firstName,
          lastName: app.lastName,
          phone: app.phone,
          company: app.company,
          title: app.title,
          city: app.city,
          state: app.state,
          status: devHash ? UserStatus.active : UserStatus.pending_password,
          passwordHash: devHash,
          foundingMember: founding,
          membershipStatus: MembershipStatus.dues_due,
          roles: { create: [{ roleId: memberRole.id }] },
          vehicles: {
            create: {
              make: app.vehicleMake,
              model: app.vehicleModel,
              year: app.vehicleYear,
              estimatedValueUsd: app.vehicleEstimatedValue,
              verificationStatus: 'approved',
              isPrimary: true,
            },
          },
          duesRecords: {
            create: {
              status: MembershipStatus.dues_due,
              amountUsdCents: founding ? 2000000 : 1000000,
              notes: founding ? 'Founding membership' : 'Annual membership',
            },
          },
        },
      });

      const updated = await tx.memberApplication.update({
        where: { id },
        data: {
          status: ApplicationStatus.approved,
          userId: user.id,
          internalNote: dto.internalNote,
          reviewedById: reviewerId,
          reviewedAt: new Date(),
        },
      });

      return { user, updated, founding };
    });

    const setToken = await this.auth.createSetPasswordToken(result.user.id);
    const base = this.config.get('APP_PUBLIC_URL') ?? 'http://localhost:8080';
    const link = `${base}/set-password?token=${setToken}`;
    await this.mail.send({
      to: app.email,
      subject: 'Welcome — set your password',
      text: `Your membership was approved${result.founding ? ' (Founding Member)' : ''}.\nSet your password:\n${link}\nThis link expires in 7 days.`,
      html: emailTemplates.approved(app.firstName ?? 'Member', link),
    });
    if (devPw) {
      console.log(
        JSON.stringify({
          level: 'info',
          msg: 'dev_approval',
          note: 'DEV: member can log in with DEV_DEFAULT_MEMBER_PASSWORD; set-password link still issued',
          setPasswordLink: link,
        }),
      );
    }

    await this.audit.log({
      actorId: reviewerId,
      action: 'application.approved',
      targetType: 'member_application',
      targetId: id,
      metadata: {
        userId: result.user.id,
        foundingMember: result.founding,
      },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });

    return this.toPublic(result.updated);
  }

  private toPublic(app: {
    id: string;
    email: string;
    firstName: string;
    lastName: string;
    status: ApplicationStatus;
    vehicleMake: string;
    vehicleModel: string;
    vehicleYear: number;
    vehicleEstimatedValue: number;
    moreInfoMessage?: string | null;
    declineReason?: string | null;
    createdAt: Date;
    updatedAt: Date;
    proofMedia?: unknown;
  }) {
    return {
      id: app.id,
      email: app.email,
      firstName: app.firstName,
      lastName: app.lastName,
      status: app.status,
      vehicle: {
        make: app.vehicleMake,
        model: app.vehicleModel,
        year: app.vehicleYear,
        estimatedValue: app.vehicleEstimatedValue,
      },
      moreInfoMessage: app.moreInfoMessage ?? undefined,
      declineReason:
        app.status === ApplicationStatus.declined
          ? (app.declineReason ?? undefined)
          : undefined,
      proofMedia: app.proofMedia,
      createdAt: app.createdAt,
      updatedAt: app.updatedAt,
    };
  }
}
