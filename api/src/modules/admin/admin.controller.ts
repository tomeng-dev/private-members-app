import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RoleName } from '@prisma/client';
import type { Response } from 'express';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AssignRolesDto } from '../members/dto/moderation.dto';
import { AdminService } from './admin.service';

@ApiTags('admin')
@ApiBearerAuth()
@Controller()
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('admin/overview')
  overview() {
    return this.admin.overview();
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/vehicles/verifications')
  vehicleQueue() {
    return this.admin.listVehicleVerifications();
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('admin/vehicles/:id/review')
  reviewVehicle(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: { decision: 'approved' | 'rejected'; note?: string },
  ) {
    return this.admin.reviewVehicle(user.userId, id, body.decision, body.note);
  }

  @Roles(RoleName.super_admin)
  @Patch('admin/members/:id/roles')
  roles(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AssignRolesDto,
  ) {
    return this.admin.assignRoles(user.userId, id, dto.roles);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/invites')
  invites() {
    return this.admin.listInvites();
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('admin/invites')
  createInvite(
    @CurrentUser() user: AuthUser,
    @Body()
    body: {
      code?: string;
      maxUses?: number;
      emailHint?: string;
      expiresAt?: string;
    },
  ) {
    return this.admin.createInvite(user.userId, body);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('admin/invites/:id/revoke')
  revoke(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.admin.revokeInvite(user.userId, id);
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Get('admin/audit-logs')
  audit(
    @Query('action') action?: string,
    @Query('actorId') actorId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('limit') limit?: string,
  ) {
    return this.admin.auditFiltered({
      action,
      actorId,
      from,
      to,
      limit: limit ? Number(limit) : 100,
    });
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/vehicles/proof/:mediaId')
  vehicleProof(@Param('mediaId') mediaId: string) {
    return this.admin.getVehicleProofUrl(mediaId);
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/audit-logs.csv')
  async auditCsv(
    @Query('action') action: string | undefined,
    @Query('actorId') actorId: string | undefined,
    @Query('from') from: string | undefined,
    @Query('to') to: string | undefined,
    @Res() res: Response,
  ) {
    const csv = await this.admin.auditCsv({ action, actorId, from, to });
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      'attachment; filename="audit-logs.csv"',
    );
    res.send(csv);
  }
}
