import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RoleName } from '@prisma/client';
import type { Request, Response } from 'express';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UpdateDuesDto } from './dto/update-dues.dto';
import { ModerationActionDto } from './dto/moderation.dto';
import { MembersService } from './members.service';

@ApiTags('members')
@ApiBearerAuth()
@Controller()
export class MembersController {
  constructor(private readonly members: MembersService) {}

  private meta(req: Request) {
    return {
      ip:
        (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
        req.ip,
      ua: req.headers['user-agent'],
    };
  }

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.members.me(user.userId);
  }

  @Get('me/export')
  export(@CurrentUser() user: AuthUser) {
    return this.members.exportMyData(user.userId);
  }

  @Post('me/delete')
  requestDelete(@CurrentUser() user: AuthUser, @Req() req: Request) {
    return this.members.requestDeletion(user.userId, this.meta(req));
  }

  @Post('me/delete/cancel')
  cancelDelete(@CurrentUser() user: AuthUser, @Req() req: Request) {
    return this.members.cancelDeletion(user.userId, this.meta(req));
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/members')
  list() {
    return this.members.listMembers();
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Patch('admin/members/:id/dues')
  updateDues(
    @Param('id') id: string,
    @Body() dto: UpdateDuesDto,
    @CurrentUser() user: AuthUser,
    @Req() req: Request,
  ) {
    return this.members.updateDues(id, dto, user.userId, this.meta(req));
  }

  @Roles(RoleName.admin, RoleName.super_admin, RoleName.moderator)
  @Post('admin/members/:id/moderation')
  moderate(
    @Param('id') id: string,
    @Body() dto: ModerationActionDto,
    @CurrentUser() user: AuthUser,
    @Req() req: Request,
  ) {
    return this.members.moderate(id, dto, user.userId, this.meta(req));
  }

  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/applications/proof/:mediaId')
  async proof(
    @Param('mediaId') mediaId: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const { file, mime, name } = await this.members.getProofFile(mediaId);
    res.set({
      'Content-Type': mime,
      'Content-Disposition': `inline; filename="${name}"`,
    });
    return file;
  }
}
