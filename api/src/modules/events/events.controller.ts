import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { EventStatus, RoleName } from '@prisma/client';
import type { Response } from 'express';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { MessagingGateway } from '../messaging/messaging.gateway';
import {
  CreateThreadCommentDto,
  ManualCheckinDto,
  MarkRsvpPaymentDto,
  MuteThreadDto,
  RsvpDto,
  ScanQrDto,
  UpsertEventDto,
} from './dto/events.dto';
import { EventsService } from './events.service';

@ApiTags('events')
@ApiBearerAuth()
@Controller()
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly gateway: MessagingGateway,
  ) {}

  // ── Member ──────────────────────────────────────────────

  @Get('events')
  list(@Query('filter') filter?: 'upcoming' | 'past' | 'all') {
    return this.events.listForMembers(filter ?? 'upcoming');
  }

  @Get('events/calendar')
  calendar(@Query('year') year: string, @Query('month') month: string) {
    const y = Number(year) || new Date().getFullYear();
    const m = Number(month) || new Date().getMonth() + 1;
    return this.events.calendarMonth(y, m);
  }

  @Get('events/:id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.events.getEvent(id, user.userId);
  }

  @Get('events/:id/archive')
  archive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.events.getArchive(id, user.userId);
  }

  @Get('events/:id/attendees')
  attendees(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.events.listAttendees(id, user.userId);
  }

  @Get('events/:id/ics')
  @Header('Content-Type', 'text/calendar; charset=utf-8')
  async ics(@Param('id') id: string, @Res() res: Response) {
    const body = await this.events.ics(id);
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="event-${id}.ics"`,
    );
    res.send(body);
  }

  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @Post('events/:id/rsvp')
  rsvp(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: RsvpDto,
  ) {
    return this.events.rsvp(user.userId, id, dto);
  }

  /** Compat with Stage 4 */
  @Post('events/:id/rsvp-going')
  rsvpGoing(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.events.rsvpGoing(user.userId, id);
  }

  @Get('events/:id/ticket')
  ticket(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.events.myTicket(user.userId, id);
  }

  @Get('events/:id/thread')
  thread(
    @Param('id') id: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.events.listComments(id, cursor, limit ? Number(limit) : 40);
  }

  @Throttle({ default: { limit: 40, ttl: 60000 } })
  @Post('events/:id/thread/comments')
  async comment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateThreadCommentDto,
  ) {
    const result = await this.events.addComment(user.userId, id, dto);
    this.gateway.emitToThread(result.threadId, 'thread:comment', {
      eventId: id,
      comment: result.comment,
    });
    return result.comment;
  }

  @Post('events/:id/thread/mute')
  mute(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MuteThreadDto,
  ) {
    return this.events.setMute(user.userId, id, dto.mute !== false);
  }

  // ── Admin events ────────────────────────────────────────

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('admin/events')
  adminList(@Query('status') status?: EventStatus) {
    return this.events.adminList(status);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('admin/events/:id')
  adminGet(@Param('id') id: string) {
    return this.events.adminGet(id);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('admin/events')
  adminCreate(@CurrentUser() user: AuthUser, @Body() dto: UpsertEventDto) {
    return this.events.adminUpsert(user.userId, dto);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Put('admin/events/:id')
  adminUpdate(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpsertEventDto,
  ) {
    return this.events.adminUpsert(user.userId, dto, id);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Patch('admin/events/:eventId/rsvps/:rsvpId/payment')
  markPayment(
    @CurrentUser() user: AuthUser,
    @Param('eventId') eventId: string,
    @Param('rsvpId') rsvpId: string,
    @Body() dto: MarkRsvpPaymentDto,
  ) {
    return this.events.markRsvpPayment(user.userId, eventId, rsvpId, dto);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('admin/events/:id/reminders')
  reminders(@Param('id') id: string, @Body() body: { kind?: '1w' | '1d' }) {
    return this.events.sendReminders(id, body.kind ?? '1d');
  }

  // ── Check-in ────────────────────────────────────────────

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('admin/events/:id/attendance')
  attendance(@Param('id') id: string) {
    return this.events.liveAttendance(id);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('admin/events/:id/attendance.csv')
  async attendanceCsv(@Param('id') id: string, @Res() res: Response) {
    const csv = await this.events.exportAttendanceCsv(id);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="attendance-${id}.csv"`,
    );
    res.send(csv);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('admin/events/:id/checkin/search')
  search(@Param('id') id: string, @Query('q') q: string) {
    return this.events.searchMembersForCheckin(id, q ?? '');
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Throttle({ default: { limit: 120, ttl: 60000 } })
  @Post('admin/events/:id/checkin/preview')
  preview(
    @CurrentUser() user: AuthUser,
    @Param('id') _id: string,
    @Body() dto: ScanQrDto,
  ) {
    return this.events.previewQr(user.userId, dto.token);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Throttle({ default: { limit: 120, ttl: 60000 } })
  @Post('admin/events/:id/checkin/confirm')
  confirm(
    @CurrentUser() user: AuthUser,
    @Param('id') _id: string,
    @Body() dto: ScanQrDto,
  ) {
    return this.events.confirmQrCheckin(user.userId, dto.token);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Post('admin/events/:id/checkin/manual')
  manual(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ManualCheckinDto,
  ) {
    return this.events.manualCheckin(user.userId, id, dto);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Post('admin/thread-comments/:id/hide')
  hide(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: { hide?: boolean },
  ) {
    return this.events.hideComment(user.userId, id, body.hide !== false);
  }
}
