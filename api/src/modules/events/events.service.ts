import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventStatus, RsvpPaymentStatus, RsvpStatus } from '@prisma/client';
import { randomBytes } from 'crypto';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PUSH_PORT, PushPort } from '../../infrastructure/push/push.port';
import { MAIL_PORT, MailPort } from '../../infrastructure/mail/mail.port';
import { emailTemplates } from '../../infrastructure/mail/templates/email-layout';
import {
  CreateThreadCommentDto,
  ManualCheckinDto,
  MarkRsvpPaymentDto,
  RsvpDto,
  UpsertEventDto,
} from './dto/events.dto';
import { qrExpiryUnix, signQrToken, verifyQrToken } from './domain/qr-token';

@Injectable()
export class EventsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly config: ConfigService,
    @Inject(PUSH_PORT) private readonly push: PushPort,
    @Inject(MAIL_PORT) private readonly mail: MailPort,
  ) {}

  private qrSecret() {
    return (
      this.config.get<string>('QR_HMAC_SECRET') ??
      this.config.getOrThrow<string>('JWT_ACCESS_SECRET')
    );
  }

  // ─── Member list / detail / archive ─────────────────────

  async listForMembers(filter?: 'upcoming' | 'past' | 'all') {
    const now = new Date();
    const where: any = {
      deletedAt: null,
      status: { in: [EventStatus.published, EventStatus.completed] },
    };
    if (filter === 'upcoming') {
      where.startsAt = { gte: now };
      where.status = EventStatus.published;
    } else if (filter === 'past') {
      where.OR = [{ startsAt: { lt: now } }, { status: EventStatus.completed }];
    }
    const items = await this.prisma.event.findMany({
      where,
      orderBy: { startsAt: filter === 'past' ? 'desc' : 'asc' },
      include: {
        speakers: { orderBy: { sortOrder: 'asc' } },
        thread: { select: { id: true } },
        _count: {
          select: {
            rsvps: { where: { status: RsvpStatus.going } },
            checkins: true,
          },
        },
      },
    });
    return { items };
  }

  async calendarMonth(year: number, month: number) {
    const start = new Date(Date.UTC(year, month - 1, 1));
    const end = new Date(Date.UTC(year, month, 1));
    const items = await this.prisma.event.findMany({
      where: {
        deletedAt: null,
        status: { in: [EventStatus.published, EventStatus.completed] },
        startsAt: { gte: start, lt: end },
      },
      orderBy: { startsAt: 'asc' },
      select: {
        id: true,
        title: true,
        startsAt: true,
        endsAt: true,
        timezone: true,
        status: true,
        venueName: true,
      },
    });
    return { year, month, items };
  }

  async getEvent(eventId: string, userId?: string) {
    const event = await this.prisma.event.findFirst({
      where: {
        id: eventId,
        deletedAt: null,
        status: {
          in: [
            EventStatus.published,
            EventStatus.completed,
            EventStatus.cancelled,
          ],
        },
      },
      include: {
        speakers: { orderBy: { sortOrder: 'asc' } },
        thread: { select: { id: true } },
        _count: {
          select: {
            rsvps: {
              where: {
                status: { in: [RsvpStatus.going, RsvpStatus.waitlisted] },
              },
            },
            checkins: true,
          },
        },
      },
    });
    if (!event) throw new NotFoundException('Event not found');

    const goingCount = await this.prisma.eventRsvp.count({
      where: { eventId, status: RsvpStatus.going },
    });
    const waitlistCount = await this.prisma.eventRsvp.count({
      where: { eventId, status: RsvpStatus.waitlisted },
    });

    let myRsvp: any = null;
    let canPost = false;
    let checkedIn = false;
    if (userId) {
      myRsvp = await this.prisma.eventRsvp.findUnique({
        where: { eventId_userId: { eventId, userId } },
      });
      const checkin = await this.prisma.eventCheckin.findUnique({
        where: { eventId_userId: { eventId, userId } },
      });
      checkedIn = !!checkin;
      canPost =
        myRsvp?.status === RsvpStatus.going ||
        myRsvp?.status === RsvpStatus.maybe ||
        myRsvp?.status === RsvpStatus.waitlisted ||
        checkedIn;
    }

    return {
      ...event,
      goingCount,
      waitlistCount,
      myRsvp: myRsvp
        ? {
            status: myRsvp.status,
            paymentStatus: myRsvp.paymentStatus,
            id: myRsvp.id,
          }
        : null,
      canPost,
      checkedIn,
      rsvpOpen: this.isRsvpOpen(event),
      spotsLeft:
        event.capacity != null
          ? Math.max(0, event.capacity - goingCount)
          : null,
    };
  }

  async getArchive(eventId: string, viewerId: string) {
    const event = await this.getEvent(eventId, viewerId);
    if (event.status !== EventStatus.completed && event.startsAt > new Date()) {
      // upcoming published events still allow thread; archive view is for past/completed
    }
    const attendees = await this.listAttendees(eventId, viewerId);
    const thread = await this.listComments(eventId);
    return { event, attendees, thread };
  }

  // ─── RSVP ───────────────────────────────────────────────

  async rsvp(userId: string, eventId: string, dto: RsvpDto) {
    const event = await this.prisma.event.findFirst({
      where: { id: eventId, deletedAt: null, status: EventStatus.published },
    });
    if (!event) throw new NotFoundException('Event not found');
    if (!this.isRsvpOpen(event)) {
      throw new ForbiddenException('RSVP cut-off has passed');
    }
    if (
      dto.status !== RsvpStatus.going &&
      dto.status !== RsvpStatus.not_going &&
      dto.status !== RsvpStatus.maybe &&
      dto.status !== RsvpStatus.waitlisted
    ) {
      throw new BadRequestException('Invalid RSVP status');
    }

    let status = dto.status;
    if (status === RsvpStatus.going && event.capacity != null) {
      const going = await this.prisma.eventRsvp.count({
        where: {
          eventId,
          status: RsvpStatus.going,
          userId: { not: userId },
        },
      });
      if (going >= event.capacity) {
        status = RsvpStatus.waitlisted;
      }
    }

    const existing = await this.prisma.eventRsvp.findUnique({
      where: { eventId_userId: { eventId, userId } },
    });

    // Promote waitlist when someone leaves going
    const wasGoing = existing?.status === RsvpStatus.going;

    const rsvp = await this.prisma.eventRsvp.upsert({
      where: { eventId_userId: { eventId, userId } },
      create: {
        eventId,
        userId,
        status,
        qrNonce: randomBytes(24).toString('base64url'),
      },
      update: { status },
    });

    if (wasGoing && status !== RsvpStatus.going) {
      await this.promoteWaitlist(eventId);
    }

    await this.audit.log({
      actorId: userId,
      action: 'event.rsvp',
      targetType: 'event',
      targetId: eventId,
      metadata: { status: rsvp.status },
    });

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user) {
      void this.push.send({
        userId,
        title: event.title,
        body:
          rsvp.status === RsvpStatus.waitlisted
            ? 'You are on the waitlist'
            : `RSVP: ${rsvp.status}`,
        data: { type: 'event_rsvp', eventId },
      });
      void this.mail.send({
        to: user.email,
        subject: `RSVP update — ${event.title}`,
        text: `Your RSVP is now: ${rsvp.status}`,
        html: emailTemplates.rsvpConfirmation(
          user.firstName ?? 'Member',
          event.title,
          String(rsvp.status),
        ),
      });
    }

    return {
      id: rsvp.id,
      status: rsvp.status,
      paymentStatus: rsvp.paymentStatus,
    };
  }

  /** Backward-compat helper used by Stage 4 e2e */
  async rsvpGoing(userId: string, eventId: string) {
    return this.rsvp(userId, eventId, { status: RsvpStatus.going });
  }

  async myTicket(userId: string, eventId: string) {
    const event = await this.prisma.event.findFirst({
      where: { id: eventId, deletedAt: null },
    });
    if (!event) throw new NotFoundException();
    const rsvp = await this.prisma.eventRsvp.findUnique({
      where: { eventId_userId: { eventId, userId } },
    });
    if (!rsvp || rsvp.status === RsvpStatus.not_going) {
      throw new ForbiddenException('No attending RSVP for this event');
    }
    if (
      rsvp.status !== RsvpStatus.going &&
      rsvp.status !== RsvpStatus.waitlisted &&
      rsvp.status !== RsvpStatus.maybe
    ) {
      throw new ForbiddenException('No ticket for this RSVP');
    }
    // Tickets for going only (waitlist/maybe get no entry QR)
    if (rsvp.status !== RsvpStatus.going) {
      throw new ForbiddenException('QR ticket is for confirmed Attending only');
    }
    const exp = qrExpiryUnix(event.startsAt, event.endsAt);
    const token = signQrToken(rsvp.id, this.qrSecret(), exp);
    return {
      eventId,
      eventTitle: event.title,
      token,
      expiresAt: new Date(exp * 1000).toISOString(),
      hint: 'Increase screen brightness for scanning',
    };
  }

  async ics(eventId: string) {
    const event = await this.prisma.event.findFirst({
      where: {
        id: eventId,
        deletedAt: null,
        status: { in: [EventStatus.published, EventStatus.completed] },
      },
    });
    if (!event) throw new NotFoundException();
    const fmt = (d: Date) =>
      d
        .toISOString()
        .replace(/[-:]/g, '')
        .replace(/\.\d{3}/, '');
    const end =
      event.endsAt ?? new Date(event.startsAt.getTime() + 3 * 3600_000);
    const body = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-Private Members App-',
      'BEGIN:VEVENT',
      `UID:${event.id}@privatemembers`,
      `DTSTAMP:${fmt(new Date())}`,
      `DTSTART:${fmt(event.startsAt)}`,
      `DTEND:${fmt(end)}`,
      `SUMMARY:${escapeIcs(event.title)}`,
      event.description ? `DESCRIPTION:${escapeIcs(event.description)}` : '',
      event.venueName || event.venueAddress
        ? `LOCATION:${escapeIcs([event.venueName, event.venueAddress].filter(Boolean).join(', '))}`
        : '',
      'END:VEVENT',
      'END:VCALENDAR',
    ]
      .filter(Boolean)
      .join('\r\n');
    return body;
  }

  // ─── Attendance / privacy ───────────────────────────────

  async listAttendees(eventId: string, viewerId: string) {
    const event = await this.prisma.event.findFirst({
      where: { id: eventId, deletedAt: null },
    });
    if (!event) throw new NotFoundException();
    const checkins = await this.prisma.eventCheckin.findMany({
      where: { eventId },
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            company: true,
            title: true,
            avatarKey: true,
            showEventsAttended: true,
            hiddenAt: true,
            deletedAt: true,
          },
        },
      },
      orderBy: { checkedInAt: 'asc' },
    });
    const items = checkins
      .filter(
        (c) =>
          !c.user.deletedAt &&
          !c.user.hiddenAt &&
          (c.user.showEventsAttended || c.userId === viewerId),
      )
      .map((c) => ({
        userId: c.user.id,
        firstName: c.user.firstName,
        lastName: c.user.lastName,
        company: c.user.company,
        title: c.user.title,
        avatarKey: c.user.avatarKey,
        checkedInAt: c.checkedInAt,
        walkIn: c.walkIn,
      }));
    return { items, count: items.length };
  }

  // ─── Check-in ───────────────────────────────────────────

  async previewQr(staffId: string, token: string) {
    const parsed = verifyQrToken(token, this.qrSecret());
    if (!parsed.ok) {
      throw new BadRequestException(`Invalid QR: ${parsed.reason}`);
    }
    const rsvp = await this.prisma.eventRsvp.findUnique({
      where: { id: parsed.rsvpId },
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            company: true,
            title: true,
            avatarKey: true,
            email: true,
          },
        },
        event: { select: { id: true, title: true, status: true } },
      },
    });
    if (!rsvp) throw new NotFoundException('RSVP not found');
    if (rsvp.status !== RsvpStatus.going) {
      throw new BadRequestException('Member is not Attending');
    }
    const existing = await this.prisma.eventCheckin.findUnique({
      where: {
        eventId_userId: { eventId: rsvp.eventId, userId: rsvp.userId },
      },
    });
    return {
      rsvpId: rsvp.id,
      event: rsvp.event,
      member: rsvp.user,
      paymentStatus: rsvp.paymentStatus,
      alreadyCheckedIn: !!existing,
      checkedInAt: existing?.checkedInAt ?? null,
    };
  }

  async confirmQrCheckin(staffId: string, token: string) {
    const preview = await this.previewQr(staffId, token);
    if (preview.alreadyCheckedIn) {
      throw new ConflictException('Already checked in');
    }
    const checkin = await this.prisma.eventCheckin.create({
      data: {
        eventId: preview.event.id,
        userId: preview.member.id,
        checkedInBy: staffId,
        walkIn: false,
      },
    });
    await this.audit.log({
      actorId: staffId,
      action: 'event.checkin',
      targetType: 'event',
      targetId: preview.event.id,
      metadata: { userId: preview.member.id, via: 'qr' },
    });
    void this.push.send({
      userId: preview.member.id,
      title: preview.event.title,
      body: 'Welcome — you are checked in',
      data: { type: 'event_checkin', eventId: preview.event.id },
    });
    return { checkin, member: preview.member, event: preview.event };
  }

  async manualCheckin(staffId: string, eventId: string, dto: ManualCheckinDto) {
    const event = await this.prisma.event.findFirst({
      where: { id: eventId, deletedAt: null },
    });
    if (!event) throw new NotFoundException('Event not found');
    const user = await this.prisma.user.findFirst({
      where: { id: dto.userId, deletedAt: null, status: 'active' },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        company: true,
        avatarKey: true,
      },
    });
    if (!user) throw new NotFoundException('Member not found');

    const existing = await this.prisma.eventCheckin.findUnique({
      where: { eventId_userId: { eventId, userId: dto.userId } },
    });
    if (existing) throw new ConflictException('Already checked in');

    if (dto.walkIn) {
      await this.prisma.eventRsvp.upsert({
        where: { eventId_userId: { eventId, userId: dto.userId } },
        create: {
          eventId,
          userId: dto.userId,
          status: RsvpStatus.going,
          paymentStatus: RsvpPaymentStatus.waived,
          qrNonce: randomBytes(24).toString('base64url'),
        },
        update: { status: RsvpStatus.going },
      });
    }

    const checkin = await this.prisma.eventCheckin.create({
      data: {
        eventId,
        userId: dto.userId,
        checkedInBy: staffId,
        walkIn: !!dto.walkIn,
      },
    });
    await this.audit.log({
      actorId: staffId,
      action: 'event.checkin',
      targetType: 'event',
      targetId: eventId,
      metadata: { userId: dto.userId, via: 'manual', walkIn: !!dto.walkIn },
    });
    return { checkin, member: user };
  }

  async liveAttendance(eventId: string) {
    const [going, checkedIn, waitlisted] = await Promise.all([
      this.prisma.eventRsvp.count({
        where: { eventId, status: RsvpStatus.going },
      }),
      this.prisma.eventCheckin.count({ where: { eventId } }),
      this.prisma.eventRsvp.count({
        where: { eventId, status: RsvpStatus.waitlisted },
      }),
    ]);
    return { going, checkedIn, waitlisted };
  }

  async exportAttendanceCsv(eventId: string) {
    const rows = await this.prisma.eventCheckin.findMany({
      where: { eventId },
      include: {
        user: {
          select: {
            firstName: true,
            lastName: true,
            email: true,
            company: true,
          },
        },
      },
      orderBy: { checkedInAt: 'asc' },
    });
    const lines = [
      'firstName,lastName,email,company,checkedInAt,walkIn',
      ...rows.map((r) =>
        [
          csv(r.user.firstName),
          csv(r.user.lastName),
          csv(r.user.email),
          csv(r.user.company ?? ''),
          r.checkedInAt.toISOString(),
          r.walkIn ? 'yes' : 'no',
        ].join(','),
      ),
    ];
    return lines.join('\n');
  }

  async searchMembersForCheckin(eventId: string, q: string) {
    const users = await this.prisma.user.findMany({
      where: {
        status: 'active',
        deletedAt: null,
        OR: [
          { firstName: { contains: q } },
          { lastName: { contains: q } },
          { email: { contains: q } },
          { company: { contains: q } },
        ],
      },
      take: 20,
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
        company: true,
        avatarKey: true,
      },
    });
    const withState = await Promise.all(
      users.map(async (u) => {
        const checkin = await this.prisma.eventCheckin.findUnique({
          where: { eventId_userId: { eventId, userId: u.id } },
        });
        const rsvp = await this.prisma.eventRsvp.findUnique({
          where: { eventId_userId: { eventId, userId: u.id } },
        });
        return {
          ...u,
          checkedIn: !!checkin,
          rsvpStatus: rsvp?.status ?? null,
        };
      }),
    );
    return { items: withState };
  }

  // ─── Admin CRUD ─────────────────────────────────────────

  async adminList(status?: EventStatus) {
    return this.prisma.event.findMany({
      where: {
        deletedAt: null,
        ...(status ? { status } : {}),
      },
      orderBy: { startsAt: 'desc' },
      include: {
        speakers: { orderBy: { sortOrder: 'asc' } },
        _count: { select: { rsvps: true, checkins: true } },
      },
    });
  }

  async adminGet(eventId: string) {
    const event = await this.prisma.event.findFirst({
      where: { id: eventId, deletedAt: null },
      include: {
        speakers: { orderBy: { sortOrder: 'asc' } },
        thread: true,
        rsvps: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
                company: true,
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
        _count: { select: { checkins: true } },
      },
    });
    if (!event) throw new NotFoundException();
    return event;
  }

  async adminUpsert(actorId: string, dto: UpsertEventDto, eventId?: string) {
    const data = {
      title: dto.title.trim(),
      description: dto.description,
      venueName: dto.venueName,
      venueAddress: dto.venueAddress,
      startsAt: new Date(dto.startsAt),
      endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
      timezone: dto.timezone ?? 'America/New_York',
      status: dto.status ?? EventStatus.draft,
      coverImageKey: dto.coverImageKey,
      capacity: dto.capacity ?? null,
      rsvpCutoffAt: dto.rsvpCutoffAt ? new Date(dto.rsvpCutoffAt) : null,
      feeUsdCents: dto.feeUsdCents ?? 100_000,
      paymentLinkUrl: dto.paymentLinkUrl,
    };

    const event = await this.prisma.$transaction(async (tx) => {
      let saved;
      if (eventId) {
        saved = await tx.event.update({
          where: { id: eventId },
          data,
        });
        if (dto.speakers) {
          await tx.eventSpeaker.deleteMany({ where: { eventId } });
        }
      } else {
        saved = await tx.event.create({
          data: {
            ...data,
            thread: { create: {} },
          },
        });
      }
      if (dto.speakers?.length) {
        await tx.eventSpeaker.createMany({
          data: dto.speakers.map((s, i) => ({
            eventId: saved.id,
            name: s.name,
            role: s.role,
            bio: s.bio,
            topic: s.topic,
            hostName: s.hostName,
            menuNotes: s.menuNotes,
            sortOrder: s.sortOrder ?? i,
          })),
        });
      }
      return saved;
    });

    await this.audit.log({
      actorId,
      action: eventId ? 'event.updated' : 'event.created',
      targetType: 'event',
      targetId: event.id,
      metadata: { status: event.status },
    });

    if (!eventId && event.status === EventStatus.published) {
      await this.notifyNewEvent(event.id, event.title);
    }
    return this.adminGet(event.id);
  }

  /** Stage 4 compat */
  async adminCreateMinimal(
    actorId: string,
    data: {
      title: string;
      startsAt: string;
      description?: string;
      venueName?: string;
    },
  ) {
    return this.adminUpsert(actorId, {
      title: data.title,
      startsAt: data.startsAt,
      description: data.description,
      venueName: data.venueName,
      status: EventStatus.published,
    });
  }

  async markRsvpPayment(
    actorId: string,
    eventId: string,
    rsvpId: string,
    dto: MarkRsvpPaymentDto,
  ) {
    const rsvp = await this.prisma.eventRsvp.findFirst({
      where: { id: rsvpId, eventId },
    });
    if (!rsvp) throw new NotFoundException();
    const updated = await this.prisma.eventRsvp.update({
      where: { id: rsvpId },
      data: { paymentStatus: dto.paymentStatus },
    });
    await this.audit.log({
      actorId,
      action: 'event.rsvp_payment',
      targetType: 'event_rsvp',
      targetId: rsvpId,
      metadata: { paymentStatus: dto.paymentStatus },
    });
    return updated;
  }

  /** Reminder hooks (M8 sends for real). */
  async sendReminders(eventId: string, kind: '1w' | '1d') {
    const event = await this.prisma.event.findFirst({
      where: { id: eventId, deletedAt: null },
    });
    if (!event) throw new NotFoundException();
    const rsvps = await this.prisma.eventRsvp.findMany({
      where: { eventId, status: RsvpStatus.going },
      include: { user: { select: { id: true, email: true, firstName: true } } },
    });
    const label = kind === '1w' ? 'in one week' : 'tomorrow';
    for (const r of rsvps) {
      void this.push.send({
        userId: r.user.id,
        title: event.title,
        body: `Reminder: event is ${label}`,
        data: { type: 'event_reminder', eventId, kind },
      });
      void this.mail.send({
        to: r.user.email,
        subject: `Reminder: ${event.title}`,
        text: `Hi ${r.user.firstName}, your event is ${label}.`,
        html: emailTemplates.eventReminder(
          r.user.firstName ?? 'Member',
          event.title,
          label,
        ),
      });
    }
    await this.audit.log({
      action: 'event.reminders_queued',
      targetType: 'event',
      targetId: eventId,
      metadata: { kind, count: rsvps.length },
    });
    return { queued: rsvps.length };
  }

  // ─── Threads (from M5) ──────────────────────────────────

  async ensureThread(eventId: string) {
    const event = await this.prisma.event.findFirst({
      where: {
        id: eventId,
        deletedAt: null,
        status: {
          in: [EventStatus.published, EventStatus.completed],
        },
      },
    });
    if (!event) throw new NotFoundException('Event not found');
    return this.prisma.eventThread.upsert({
      where: { eventId },
      create: { eventId },
      update: {},
    });
  }

  async listComments(eventId: string, cursor?: string, limit = 40) {
    const thread = await this.ensureThread(eventId);
    const take = Math.min(Math.max(limit, 1), 50);
    const cursorRow = cursor
      ? await this.prisma.threadComment.findUnique({ where: { id: cursor } })
      : null;
    const rows = await this.prisma.threadComment.findMany({
      where: {
        threadId: thread.id,
        deletedAt: null,
        hiddenAt: null,
        ...(cursorRow ? { createdAt: { lt: cursorRow.createdAt } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      include: {
        author: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            foundingMember: true,
          },
        },
      },
    });
    const hasMore = rows.length > take;
    const slice = hasMore ? rows.slice(0, take) : rows;
    return {
      threadId: thread.id,
      items: slice.reverse(),
      nextCursor: hasMore ? slice[slice.length - 1]?.id : null,
    };
  }

  async addComment(
    userId: string,
    eventId: string,
    dto: CreateThreadCommentDto,
  ) {
    const event = await this.getEvent(eventId, userId);
    if (!event.canPost) {
      throw new ForbiddenException(
        'Only RSVP’d or attending members can post in the thread',
      );
    }
    const thread = await this.ensureThread(eventId);
    const comment = await this.prisma.threadComment.create({
      data: {
        threadId: thread.id,
        authorId: userId,
        body: dto.body.trim(),
      },
      include: {
        author: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            foundingMember: true,
          },
        },
      },
    });
    const rsvps = await this.prisma.eventRsvp.findMany({
      where: {
        eventId,
        userId: { not: userId },
        status: { in: [RsvpStatus.going, RsvpStatus.maybe] },
      },
      select: { userId: true },
    });
    const mutes = await this.prisma.threadMute.findMany({
      where: { threadId: thread.id },
      select: { userId: true },
    });
    const muted = new Set(mutes.map((m) => m.userId));
    for (const r of rsvps) {
      if (muted.has(r.userId)) continue;
      void this.push.send({
        userId: r.userId,
        title: event.title,
        body: 'New activity in the event thread',
        data: { type: 'thread', eventId, threadId: thread.id },
      });
    }
    await this.audit.log({
      actorId: userId,
      action: 'thread.comment_created',
      targetType: 'thread_comment',
      targetId: comment.id,
      metadata: { eventId },
    });
    return { threadId: thread.id, comment };
  }

  async hideComment(actorId: string, commentId: string, hide = true) {
    const comment = await this.prisma.threadComment.findUnique({
      where: { id: commentId },
    });
    if (!comment) throw new NotFoundException();
    await this.prisma.threadComment.update({
      where: { id: commentId },
      data: { hiddenAt: hide ? new Date() : null },
    });
    await this.audit.log({
      actorId,
      action: hide ? 'thread.comment_hidden' : 'thread.comment_unhidden',
      targetType: 'thread_comment',
      targetId: commentId,
    });
    return { ok: true };
  }

  async setMute(userId: string, eventId: string, mute: boolean) {
    const thread = await this.ensureThread(eventId);
    if (mute) {
      await this.prisma.threadMute.upsert({
        where: { threadId_userId: { threadId: thread.id, userId } },
        create: { threadId: thread.id, userId },
        update: {},
      });
    } else {
      await this.prisma.threadMute.deleteMany({
        where: { threadId: thread.id, userId },
      });
    }
    return { ok: true, muted: mute, threadId: thread.id };
  }

  // ─── helpers ────────────────────────────────────────────

  private isRsvpOpen(event: {
    rsvpCutoffAt: Date | null;
    startsAt: Date;
    status: EventStatus;
  }) {
    if (event.status !== EventStatus.published) return false;
    const cutoff = event.rsvpCutoffAt ?? event.startsAt;
    return new Date() < cutoff;
  }

  private async promoteWaitlist(eventId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });
    if (!event?.capacity) return;
    const going = await this.prisma.eventRsvp.count({
      where: { eventId, status: RsvpStatus.going },
    });
    if (going >= event.capacity) return;
    const next = await this.prisma.eventRsvp.findFirst({
      where: { eventId, status: RsvpStatus.waitlisted },
      orderBy: { createdAt: 'asc' },
    });
    if (!next) return;
    await this.prisma.eventRsvp.update({
      where: { id: next.id },
      data: { status: RsvpStatus.going },
    });
    void this.push.send({
      userId: next.userId,
      title: event.title,
      body: 'A spot opened — you are now Attending',
      data: { type: 'event_waitlist_promoted', eventId },
    });
  }

  private async notifyNewEvent(eventId: string, title: string) {
    const members = await this.prisma.user.findMany({
      where: { status: 'active', deletedAt: null },
      select: { id: true },
      take: 500,
    });
    for (const m of members) {
      void this.push.send({
        userId: m.id,
        title: 'New event',
        body: title,
        data: { type: 'event_new', eventId },
      });
    }
  }
}

function escapeIcs(s: string) {
  return s
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\n/g, '\\n');
}
function csv(s: string) {
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}
