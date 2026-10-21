import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RoleName } from '@prisma/client';
import type { Request } from 'express';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminConsoleService } from './admin-console.service';
import {
  BroadcastDto,
  BulkApplicationsDto,
  BulkMembersDto,
} from './dto/admin-console.dto';

const meta = (req: Request) => ({ ip: req.ip, ua: req.headers['user-agent'] });
const ids = (s?: string) =>
  s ? s.split(',').filter(Boolean).slice(0, 500) : undefined;

@ApiTags('admin-console')
@ApiBearerAuth()
@Controller('admin/console')
export class AdminConsoleController {
  constructor(private readonly svc: AdminConsoleService) {}

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('env')
  env() {
    return this.svc.environment();
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('stats')
  stats() {
    return this.svc.stats();
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('search')
  search(@Query('q') q: string) {
    return this.svc.search(q);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('members')
  members(@Query() q: Record<string, string>) {
    return this.svc.membersTable(q);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('members.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="members.csv"')
  membersCsv(@Query() q: Record<string, string>) {
    return this.svc.membersCsv(q, ids(q.ids));
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('members/:id')
  memberDetail(@Param('id') id: string) {
    return this.svc.memberDetail(id);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('members/bulk')
  bulkMembers(
    @CurrentUser() u: AuthUser,
    @Body() dto: BulkMembersDto,
    @Req() req: Request,
  ) {
    return this.svc.bulkMembers(dto, u.userId, meta(req));
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('applications')
  applications(@Query() q: Record<string, string>) {
    return this.svc.applicationsTable(q);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('applications.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="applications.csv"')
  applicationsCsv(@Query() q: Record<string, string>) {
    return this.svc.applicationsCsv(q, ids(q.ids));
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('applications/bulk')
  bulkApplications(
    @CurrentUser() u: AuthUser,
    @Body() dto: BulkApplicationsDto,
    @Req() req: Request,
  ) {
    return this.svc.bulkApplications(dto, u.userId, meta(req));
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('broadcast')
  broadcast(
    @CurrentUser() u: AuthUser,
    @Body() dto: BroadcastDto,
    @Req() req: Request,
  ) {
    return this.svc.broadcast(dto, u.userId, meta(req));
  }
}
