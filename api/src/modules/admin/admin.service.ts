import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ApplicationStatus,
  EventStatus,
  MembershipStatus,
  ReportStatus,
  RoleName,
  RsvpStatus,
  UserStatus,
  VehicleVerificationStatus,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  STORAGE_PORT,
  StoragePort,
} from '../../infrastructure/storage/storage.port';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    @Inject(STORAGE_PORT) private readonly storage: StoragePort,
  ) {}

  async overview() {
    const now = new Date();
    const [
      members,
      pendingApplications,
      duesOverdue,
      upcomingEvents,
      openReports,
      rsvpsGoing,
      pendingVehicles,
    ] = await Promise.all([
      this.prisma.user.count({
        where: { status: UserStatus.active, deletedAt: null },
      }),
      this.prisma.memberApplication.count({
        where: {
          status: {
            in: [ApplicationStatus.submitted, ApplicationStatus.under_review],
          },
        },
      }),
      this.prisma.user.count({
        where: {
          membershipStatus: {
            in: [MembershipStatus.dues_due, MembershipStatus.overdue],
          },
          status: { not: UserStatus.deleted },
        },
      }),
      this.prisma.event.count({
        where: {
          status: EventStatus.published,
          deletedAt: null,
          startsAt: { gte: now },
        },
      }),
      this.prisma.report.count({ where: { status: ReportStatus.open } }),
      this.prisma.eventRsvp.count({
        where: {
          status: RsvpStatus.going,
          event: { status: EventStatus.published, startsAt: { gte: now } },
        },
      }),
      this.prisma.vehicle.count({
        where: {
          verificationStatus: VehicleVerificationStatus.submitted,
          deletedAt: null,
        },
      }),
    ]);
    return {
      members,
      pendingApplications,
      duesOverdue,
      upcomingEvents,
      openReports,
      rsvpsGoing,
      pendingVehicles,
    };
  }

  async listVehicleVerifications() {
    return this.prisma.vehicle.findMany({
      where: {
        verificationStatus: {
          in: [
            VehicleVerificationStatus.submitted,
            VehicleVerificationStatus.draft,
          ],
        },
        deletedAt: null,
      },
      orderBy: { updatedAt: 'desc' },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
          },
        },
        media: { where: { deletedAt: null } },
      },
    });
  }

  async reviewVehicle(
    actorId: string,
    vehicleId: string,
    decision: 'approved' | 'rejected',
    note?: string,
  ) {
    const vehicle = await this.prisma.vehicle.findFirst({
      where: { id: vehicleId, deletedAt: null },
    });
    if (!vehicle) throw new NotFoundException();
    const updated = await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: {
        verificationStatus:
          decision === 'approved'
            ? VehicleVerificationStatus.approved
            : VehicleVerificationStatus.rejected,
        description: note
          ? `${vehicle.description ?? ''}\n[verification] ${note}`.trim()
          : vehicle.description,
      },
    });
    await this.audit.log({
      actorId,
      action: `vehicle.${decision}`,
      targetType: 'vehicle',
      targetId: vehicleId,
      metadata: { note },
    });
    return updated;
  }

  async assignRoles(actorId: string, userId: string, roles: RoleName[]) {
    if (!roles.includes(RoleName.member) && roles.length === 0) {
      throw new BadRequestException('At least one role required');
    }
    const target = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { roles: { include: { role: true } } },
    });
    if (!target) throw new NotFoundException();

    const currentlySuper = target.roles.some(
      (r) => r.role.name === RoleName.super_admin,
    );
    const willBeSuper = roles.includes(RoleName.super_admin);
    if (currentlySuper && !willBeSuper) {
      const superCount = await this.prisma.userRole.count({
        where: { role: { name: RoleName.super_admin } },
      });
      if (superCount <= 1) {
        throw new ForbiddenException('Cannot demote the last super_admin');
      }
    }

    const roleRows = await this.prisma.role.findMany({
      where: { name: { in: roles } },
    });
    await this.prisma.$transaction(async (tx) => {
      await tx.userRole.deleteMany({ where: { userId } });
      await tx.userRole.createMany({
        data: roleRows.map((r) => ({ userId, roleId: r.id })),
      });
    });
    await this.audit.log({
      actorId,
      action: 'member.roles_updated',
      targetType: 'user',
      targetId: userId,
      metadata: { roles },
    });
    return { ok: true, roles };
  }

  async listInvites() {
    return this.prisma.invite.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async createInvite(
    actorId: string,
    data: {
      code?: string;
      maxUses?: number;
      emailHint?: string;
      expiresAt?: string;
    },
  ) {
    const code =
      data.code?.trim() ||
      `INV-${randomBytes(4).toString('hex').toUpperCase()}`;
    const invite = await this.prisma.invite.create({
      data: {
        code,
        createdById: actorId,
        maxUses: data.maxUses ?? 1,
        emailHint: data.emailHint,
        expiresAt: data.expiresAt ? new Date(data.expiresAt) : null,
        status: 'active',
      },
    });
    await this.audit.log({
      actorId,
      action: 'invite.created',
      targetType: 'invite',
      targetId: invite.id,
      metadata: { code },
    });
    return invite;
  }

  async revokeInvite(actorId: string, id: string) {
    const invite = await this.prisma.invite.update({
      where: { id },
      data: { status: 'revoked' },
    });
    await this.audit.log({
      actorId,
      action: 'invite.revoked',
      targetType: 'invite',
      targetId: id,
    });
    return invite;
  }

  async auditFiltered(opts: {
    action?: string;
    actorId?: string;
    from?: string;
    to?: string;
    limit?: number;
  }) {
    const take = Math.min(Math.max(opts.limit ?? 100, 1), 500);
    const rows = await this.prisma.auditLog.findMany({
      where: {
        ...(opts.action ? { action: { contains: opts.action } } : {}),
        ...(opts.actorId ? { actorId: opts.actorId } : {}),
        ...(opts.from || opts.to
          ? {
              createdAt: {
                ...(opts.from ? { gte: new Date(opts.from) } : {}),
                ...(opts.to ? { lte: new Date(opts.to) } : {}),
              },
            }
          : {}),
      },
      orderBy: { createdAt: 'desc' },
      take,
      include: {
        actor: {
          select: { id: true, email: true, firstName: true, lastName: true },
        },
      },
    });
    return rows;
  }

  async auditCsv(opts: {
    action?: string;
    actorId?: string;
    from?: string;
    to?: string;
  }) {
    const rows = await this.auditFiltered({ ...opts, limit: 500 });
    const lines = [
      'createdAt,action,actorEmail,targetType,targetId,ipAddress',
      ...rows.map((r) =>
        [
          r.createdAt.toISOString(),
          csv(r.action),
          csv(r.actor?.email ?? ''),
          csv(r.targetType ?? ''),
          csv(r.targetId ?? ''),
          csv(r.ipAddress ?? ''),
        ].join(','),
      ),
    ];
    return lines.join('\n');
  }

  async getVehicleProofUrl(mediaId: string) {
    const media = await this.prisma.media.findUnique({
      where: { id: mediaId },
    });
    if (!media || media.deletedAt)
      throw new NotFoundException('File not found');
    if (media.ownerType !== 'verification') {
      throw new BadRequestException('Not a verification document');
    }
    const signed = await this.storage.createSignedReadUrl(
      media.storageKey,
      300,
    );
    return {
      url: signed.url,
      expiresIn: signed.expiresInSeconds,
      mediaId: media.id,
      mimeType: media.mimeType,
    };
  }
}

function csv(s: string) {
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}
