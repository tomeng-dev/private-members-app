import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ApplicationStatus,
  EventStatus,
  MembershipStatus,
  Prisma,
  RoleName,
  UserStatus,
} from '@prisma/client';
import { environmentLabel } from '../../common/env/runtime-env';
import { MAIL_PORT, MailPort } from '../../infrastructure/mail/mail.port';
import {
  emailLayout,
  escapeHtml,
} from '../../infrastructure/mail/templates/email-layout';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PUSH_PORT, PushPort } from '../../infrastructure/push/push.port';
import { ApplicationsService } from '../applications/applications.service';
import { AuditService } from '../audit/audit.service';
import { MembersService } from '../members/members.service';
import {
  BroadcastDto,
  BulkApplicationsDto,
  BulkMembersDto,
} from './dto/admin-console.dto';
import {
  bucketByWeek,
  normalizeTableQuery,
  paged,
  TableQueryInput,
  toCsv,
} from './table-query';

type Meta = { ip?: string; ua?: string };

export const MEMBER_SORTS = [
  'createdAt',
  'email',
  'lastName',
  'status',
  'membershipStatus',
  'renewalDate',
] as const;
export const APPLICATION_SORTS = [
  'createdAt',
  'email',
  'lastName',
  'status',
  'vehicleEstimatedValue',
  'vehicleYear',
] as const;

@Injectable()
export class AdminConsoleService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly config: ConfigService,
    private readonly applications: ApplicationsService,
    private readonly members: MembersService,
    @Inject(PUSH_PORT) private readonly push: PushPort,
    @Inject(MAIL_PORT) private readonly mail: MailPort,
  ) {}

  environment() {
    return { environment: environmentLabel(this.config) };
  }

  // ---------- Members table ----------
  private memberWhere(
    q: string | null,
    f: Record<string, string | undefined>,
  ): Prisma.UserWhereInput {
    const where: Prisma.UserWhereInput = {
      status: { not: UserStatus.deleted },
    };
    if (q) {
      where.OR = [
        { email: { contains: q } },
        { firstName: { contains: q } },
        { lastName: { contains: q } },
        { company: { contains: q } },
        { city: { contains: q } },
      ];
    }
    if (f.status && f.status in UserStatus)
      where.status = f.status as UserStatus;
    // membershipStatus / role accept a single value or a comma list (e.g. "dues_due,overdue").
    const list = <T extends string>(
      raw: string | undefined,
      allowed: Record<string, T>,
    ) =>
      (raw ?? '')
        .split(',')
        .map((v) => v.trim())
        .filter((v): v is T => v in allowed);
    const memberships = list(f.membershipStatus, MembershipStatus);
    if (memberships.length) where.membershipStatus = { in: memberships };
    if (f.founding === 'true') where.foundingMember = true;
    const roles = list(f.role, RoleName);
    if (roles.length) where.roles = { some: { role: { name: { in: roles } } } };
    return where;
  }

  async membersTable(
    input: TableQueryInput & Record<string, string | undefined>,
  ) {
    const q = normalizeTableQuery(input, MEMBER_SORTS, 'createdAt');
    const where = this.memberWhere(q.q, input);
    const [total, rows] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        orderBy: { [q.sort]: q.order },
        skip: q.skip,
        take: q.take,
        include: {
          roles: { include: { role: true } },
          vehicles: { where: { deletedAt: null, isPrimary: true }, take: 1 },
          _count: { select: { vehicles: true, eventRsvps: true, posts: true } },
        },
      }),
    ]);
    return paged(
      rows.map((u) => ({
        id: u.id,
        email: u.email,
        firstName: u.firstName,
        lastName: u.lastName,
        company: u.company,
        city: u.city,
        state: u.state,
        status: u.status,
        membershipStatus: u.membershipStatus,
        foundingMember: u.foundingMember,
        renewalDate: u.renewalDate,
        createdAt: u.createdAt,
        roles: u.roles.map((r) => r.role.name),
        primaryVehicle: u.vehicles[0]
          ? `${u.vehicles[0].year} ${u.vehicles[0].make} ${u.vehicles[0].model}`
          : null,
        counts: u._count,
      })),
      total,
      q,
    );
  }

  async membersCsv(
    input: TableQueryInput & Record<string, string | undefined>,
    ids?: string[],
  ) {
    const q = normalizeTableQuery(input, MEMBER_SORTS, 'createdAt');
    const where = ids?.length
      ? { id: { in: ids } }
      : this.memberWhere(q.q, input);
    const rows = await this.prisma.user.findMany({
      where,
      orderBy: { [q.sort]: q.order },
      take: 5000,
    });
    return toCsv(rows as any, [
      'id',
      'email',
      'firstName',
      'lastName',
      'company',
      'city',
      'state',
      'status',
      'membershipStatus',
      'foundingMember',
      'renewalDate',
      'createdAt',
    ]);
  }

  async memberDetail(id: string) {
    const u = await this.prisma.user.findUnique({
      where: { id },
      include: {
        roles: { include: { role: true } },
        vehicles: {
          where: { deletedAt: null },
          orderBy: { isPrimary: 'desc' },
        },
        duesRecords: { orderBy: { createdAt: 'desc' }, take: 20 },
        businessPage: true,
        _count: {
          select: {
            posts: true,
            comments: true,
            eventRsvps: true,
            eventCheckins: true,
          },
        },
      },
    });
    if (!u) throw new NotFoundException('Member not found');
    const [audit, recentPosts, rsvps] = await Promise.all([
      this.prisma.auditLog.findMany({
        where: { OR: [{ targetId: id }, { actorId: id }] },
        orderBy: { createdAt: 'desc' },
        take: 30,
        include: {
          actor: { select: { email: true, firstName: true, lastName: true } },
        },
      }),
      this.prisma.post.findMany({
        where: { authorId: id, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: { id: true, body: true, createdAt: true, hiddenAt: true },
      }),
      this.prisma.eventRsvp.findMany({
        where: { userId: id },
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: {
          event: { select: { id: true, title: true, startsAt: true } },
        },
      }),
    ]);
    // Never expose credential material to the console.
    const safe: Partial<typeof u> = { ...u };
    delete safe.passwordHash;
    delete safe.totpSecret;
    delete safe.totpRecoveryHashes;
    return {
      profile: { ...safe, roles: u.roles.map((r) => r.role.name) },
      vehicles: u.vehicles,
      dues: u.duesRecords,
      business: u.businessPage,
      activity: {
        counts: u._count,
        recentPosts,
        rsvps: rsvps.map((r) => ({
          id: r.id,
          status: r.status,
          paymentStatus: r.paymentStatus,
          event: r.event,
        })),
      },
      audit: audit.map((a) => ({
        ...a,
        metadata: a.metadata ? safeJson(a.metadata) : null,
      })),
    };
  }

  // ---------- Applications table ----------
  private applicationWhere(
    q: string | null,
    f: Record<string, string | undefined>,
  ): Prisma.MemberApplicationWhereInput {
    const where: Prisma.MemberApplicationWhereInput = {};
    if (q) {
      where.OR = [
        { email: { contains: q } },
        { firstName: { contains: q } },
        { lastName: { contains: q } },
        { vehicleMake: { contains: q } },
        { vehicleModel: { contains: q } },
        { company: { contains: q } },
      ];
    }
    if (f.status) {
      const statuses = f.status
        .split(',')
        .filter((s) => s in ApplicationStatus) as ApplicationStatus[];
      if (statuses.length) where.status = { in: statuses };
    }
    if (f.minValue && Number(f.minValue) > 0)
      where.vehicleEstimatedValue = { gte: Number(f.minValue) };
    return where;
  }

  async applicationsTable(
    input: TableQueryInput & Record<string, string | undefined>,
  ) {
    const q = normalizeTableQuery(input, APPLICATION_SORTS, 'createdAt');
    const where = this.applicationWhere(q.q, input);
    const [total, rows, byStatus] = await Promise.all([
      this.prisma.memberApplication.count({ where }),
      this.prisma.memberApplication.findMany({
        where,
        orderBy: { [q.sort]: q.order },
        skip: q.skip,
        take: q.take,
        include: {
          proofMedia: {
            where: { deletedAt: null },
            select: { id: true, kind: true, mimeType: true },
          },
          invite: { select: { code: true } },
        },
      }),
      this.prisma.memberApplication.groupBy({
        by: ['status'],
        _count: { _all: true },
      }),
    ]);
    return {
      ...paged(rows, total, q),
      facets: Object.fromEntries(
        byStatus.map((b) => [b.status, b._count._all]),
      ),
    };
  }

  async applicationsCsv(
    input: TableQueryInput & Record<string, string | undefined>,
    ids?: string[],
  ) {
    const q = normalizeTableQuery(input, APPLICATION_SORTS, 'createdAt');
    const where = ids?.length
      ? { id: { in: ids } }
      : this.applicationWhere(q.q, input);
    const rows = await this.prisma.memberApplication.findMany({
      where,
      orderBy: { [q.sort]: q.order },
      take: 5000,
    });
    return toCsv(rows as any, [
      'id',
      'email',
      'firstName',
      'lastName',
      'company',
      'city',
      'state',
      'vehicleYear',
      'vehicleMake',
      'vehicleModel',
      'vehicleEstimatedValue',
      'status',
      'createdAt',
    ]);
  }

  // ---------- Bulk actions ----------
  async bulkApplications(
    dto: BulkApplicationsDto,
    actorId: string,
    meta: Meta,
  ) {
    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const id of dto.ids) {
      try {
        await this.applications.review(
          id,
          dto.action === 'approve'
            ? { decision: 'approve', internalNote: dto.reason }
            : { decision: 'decline', declineReason: dto.reason },
          actorId,
          meta,
        );
        results.push({ id, ok: true });
      } catch (e: any) {
        results.push({ id, ok: false, error: e?.message ?? 'failed' });
      }
    }
    await this.audit.log({
      actorId,
      action: `application.bulk_${dto.action}`,
      targetType: 'member_application',
      metadata: { ids: dto.ids, succeeded: results.filter((r) => r.ok).length },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    return { action: dto.action, results };
  }

  async bulkMembers(dto: BulkMembersDto, actorId: string, meta: Meta) {
    if (dto.ids.includes(actorId))
      throw new BadRequestException('You cannot change your own status');
    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const id of dto.ids) {
      try {
        const staff = await this.prisma.userRole.count({
          where: { userId: id, role: { name: RoleName.super_admin } },
        });
        if (staff && dto.action === 'suspend')
          throw new BadRequestException('Cannot suspend a super admin');
        await this.members.moderate(
          id,
          { action: dto.action, reason: dto.reason },
          actorId,
          meta,
        );
        results.push({ id, ok: true });
      } catch (e: any) {
        results.push({ id, ok: false, error: e?.message ?? 'failed' });
      }
    }
    await this.audit.log({
      actorId,
      action: `member.bulk_${dto.action}`,
      targetType: 'user',
      metadata: {
        ids: dto.ids,
        reason: dto.reason,
        succeeded: results.filter((r) => r.ok).length,
      },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    return { action: dto.action, results };
  }

  // ---------- Stats for charts ----------
  async stats() {
    const now = new Date();
    const since = new Date(now.getTime() - 8 * 7 * 86400000);
    const [
      apps,
      statusGroups,
      membershipGroups,
      upcoming,
      recentEvents,
      activity,
      pending,
    ] = await Promise.all([
      this.prisma.memberApplication.findMany({
        where: { createdAt: { gte: since } },
        select: { createdAt: true },
      }),
      this.prisma.user.groupBy({
        by: ['status'],
        where: { status: { not: UserStatus.deleted } },
        _count: { _all: true },
      }),
      this.prisma.user.groupBy({
        by: ['membershipStatus'],
        where: { status: { not: UserStatus.deleted } },
        _count: { _all: true },
      }),
      this.prisma.event.findMany({
        where: {
          startsAt: { gte: now },
          status: EventStatus.published,
          deletedAt: null,
        },
        orderBy: { startsAt: 'asc' },
        take: 6,
        select: {
          id: true,
          title: true,
          startsAt: true,
          capacity: true,
          _count: { select: { rsvps: { where: { status: 'going' } } } },
        },
      }),
      this.prisma.event.findMany({
        where: { startsAt: { lt: now }, deletedAt: null },
        orderBy: { startsAt: 'desc' },
        take: 6,
        select: {
          id: true,
          title: true,
          startsAt: true,
          _count: {
            select: { checkins: true, rsvps: { where: { status: 'going' } } },
          },
        },
      }),
      this.prisma.auditLog.findMany({
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: {
          actor: { select: { firstName: true, lastName: true, email: true } },
        },
      }),
      Promise.all([
        this.prisma.memberApplication.count({
          where: {
            status: {
              in: [ApplicationStatus.submitted, ApplicationStatus.under_review],
            },
          },
        }),
        this.prisma.vehicle.count({
          where: { verificationStatus: 'submitted', deletedAt: null },
        }),
        this.prisma.report.count({
          where: { status: { in: ['open', 'reviewing'] } },
        }),
        this.prisma.user.count({
          where: {
            membershipStatus: MembershipStatus.overdue,
            status: { not: UserStatus.deleted },
          },
        }),
      ]),
    ]);
    return {
      applicationsPerWeek: bucketByWeek(
        apps.map((a) => a.createdAt),
        8,
        now,
      ),
      membersByStatus: statusGroups.map((g) => ({
        status: g.status,
        count: g._count._all,
      })),
      membersByMembership: membershipGroups.map((g) => ({
        status: g.membershipStatus,
        count: g._count._all,
      })),
      rsvpsPerUpcomingEvent: upcoming.map((e) => ({
        id: e.id,
        title: e.title,
        startsAt: e.startsAt,
        capacity: e.capacity,
        going: e._count.rsvps,
      })),
      checkinsPerEvent: recentEvents.reverse().map((e) => ({
        id: e.id,
        title: e.title,
        startsAt: e.startsAt,
        checkins: e._count.checkins,
        going: e._count.rsvps,
      })),
      recentActivity: activity.map((a) => ({
        id: a.id,
        action: a.action,
        targetType: a.targetType,
        targetId: a.targetId,
        createdAt: a.createdAt,
        actor: a.actor,
      })),
      pendingTasks: [
        {
          key: 'applications',
          label: 'Applications to review',
          count: pending[0],
          route: '/applications',
        },
        {
          key: 'vehicles',
          label: 'Vehicles to verify',
          count: pending[1],
          route: '/vehicles',
        },
        {
          key: 'reports',
          label: 'Open reports',
          count: pending[2],
          route: '/reports',
        },
        {
          key: 'dues',
          label: 'Overdue dues',
          count: pending[3],
          route: '/dues',
        },
      ],
    };
  }

  // ---------- Global search ----------
  async search(qRaw: string) {
    const q = (qRaw ?? '').trim().slice(0, 100);
    if (q.length < 2) return { members: [], applications: [], events: [] };
    const [members, applications, events] = await Promise.all([
      this.prisma.user.findMany({
        where: {
          status: { not: UserStatus.deleted },
          OR: [
            { email: { contains: q } },
            { firstName: { contains: q } },
            { lastName: { contains: q } },
            { company: { contains: q } },
          ],
        },
        take: 6,
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          status: true,
          foundingMember: true,
        },
      }),
      this.prisma.memberApplication.findMany({
        where: {
          OR: [
            { email: { contains: q } },
            { firstName: { contains: q } },
            { lastName: { contains: q } },
          ],
        },
        take: 6,
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          status: true,
        },
      }),
      this.prisma.event.findMany({
        where: { deletedAt: null, title: { contains: q } },
        take: 6,
        select: { id: true, title: true, startsAt: true, status: true },
      }),
    ]);
    return { members, applications, events };
  }

  // ---------- Broadcast ----------
  private async segmentRecipients(dto: BroadcastDto) {
    const base: Prisma.UserWhereInput = {
      status: UserStatus.active,
      deletedAt: null,
    };
    switch (dto.segment) {
      case 'founding':
        return this.prisma.user.findMany({
          where: { ...base, foundingMember: true },
          select: { id: true, email: true, firstName: true },
        });
      case 'dues_due':
        return this.prisma.user.findMany({
          where: { ...base, membershipStatus: MembershipStatus.dues_due },
          select: { id: true, email: true, firstName: true },
        });
      case 'overdue':
        return this.prisma.user.findMany({
          where: { ...base, membershipStatus: MembershipStatus.overdue },
          select: { id: true, email: true, firstName: true },
        });
      case 'event_rsvps':
        if (!dto.eventId)
          throw new BadRequestException(
            'eventId is required for event_rsvps segment',
          );
        return this.prisma.user.findMany({
          where: {
            ...base,
            eventRsvps: { some: { eventId: dto.eventId, status: 'going' } },
          },
          select: { id: true, email: true, firstName: true },
        });
      default:
        return this.prisma.user.findMany({
          where: {
            ...base,
            roles: { some: { role: { name: RoleName.member } } },
          },
          select: { id: true, email: true, firstName: true },
        });
    }
  }

  async broadcast(dto: BroadcastDto, actorId: string, meta: Meta) {
    const recipients = await this.segmentRecipients(dto);
    if (dto.dryRun) return { dryRun: true, recipients: recipients.length };
    const channels = new Set(dto.channels);
    if (channels.has('in_app') || channels.has('push')) {
      await this.prisma.notification.createMany({
        data: recipients.map((r) => ({
          userId: r.id,
          title: dto.title,
          body: dto.body,
          channel: 'in_app' as const,
          dataJson: JSON.stringify({ type: 'broadcast' }),
        })),
      });
    }
    for (const r of recipients) {
      if (channels.has('push'))
        void this.push.send({
          userId: r.id,
          title: dto.title,
          body: dto.body.slice(0, 180),
          data: { type: 'broadcast' },
        });
      if (channels.has('email'))
        void this.mail.send({
          to: r.email,
          subject: dto.title,
          text: dto.body,
          html: emailLayout({
            title: dto.title,
            bodyHtml: `<p>Dear ${escapeHtml(r.firstName)},</p><p>${escapeHtml(dto.body).replace(/\n/g, '<br/>')}</p>`,
          }),
        });
    }
    await this.audit.log({
      actorId,
      action: 'notification.broadcast',
      targetType: 'segment',
      metadata: {
        segment: dto.segment,
        eventId: dto.eventId,
        channels: dto.channels,
        recipients: recipients.length,
        title: dto.title,
      },
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    return { dryRun: false, recipients: recipients.length };
  }
}

function safeJson(s: string) {
  try {
    return JSON.parse(s);
  } catch {
    return s;
  }
}
