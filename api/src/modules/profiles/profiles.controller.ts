import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RoleName } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UpsertBusinessPageDto } from './dto/business-page.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { CreateVehicleDto, UpdateVehicleDto } from './dto/vehicle.dto';
import { ProfilesService } from './profiles.service';

@ApiTags('profiles')
@ApiBearerAuth()
@Controller()
export class ProfilesController {
  constructor(private readonly profiles: ProfilesService) {}

  @Get('me/profile')
  me(@CurrentUser() user: AuthUser) {
    return this.profiles.getMe(user.userId);
  }

  @Patch('me/profile')
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.profiles.updateMe(user.userId, dto);
  }

  @Get('members')
  list(@Query('q') q?: string, @Query('eventId') eventId?: string) {
    return this.profiles.listMembers(q, eventId);
  }

  @Get('members/:id')
  getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.profiles.getPublicProfile(user.userId, id);
  }

  @Post('me/vehicles')
  createVehicle(@CurrentUser() user: AuthUser, @Body() dto: CreateVehicleDto) {
    return this.profiles.createVehicle(user.userId, dto);
  }

  @Patch('me/vehicles/:id')
  updateVehicle(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateVehicleDto,
  ) {
    return this.profiles.updateVehicle(user.userId, id, dto);
  }

  @Delete('me/vehicles/:id')
  deleteVehicle(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.profiles.deleteVehicle(user.userId, id);
  }

  @Put('me/business-page')
  upsertBiz(@CurrentUser() user: AuthUser, @Body() dto: UpsertBusinessPageDto) {
    return this.profiles.upsertBusinessPage(user.userId, dto);
  }

  @Delete('me/business-page')
  deleteBiz(@CurrentUser() user: AuthUser) {
    return this.profiles.deleteBusinessPage(user.userId);
  }

  @Roles(RoleName.moderator, RoleName.admin, RoleName.super_admin)
  @Get('admin/members/:id/profile')
  adminProfile(@Param('id') id: string) {
    return this.profiles.adminGetMember(id);
  }

  @Roles(RoleName.moderator, RoleName.admin, RoleName.super_admin)
  @Post('admin/moderation/hide')
  hide(
    @CurrentUser() user: AuthUser,
    @Body()
    body: {
      type: 'user' | 'vehicle' | 'business_page';
      id: string;
      hide?: boolean;
    },
  ) {
    return this.profiles.adminHide(
      user.userId,
      { type: body.type, id: body.id },
      body.hide !== false,
    );
  }
}
