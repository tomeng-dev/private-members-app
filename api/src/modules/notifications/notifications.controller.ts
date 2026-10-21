import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller()
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('notifications')
  list(@CurrentUser() user: AuthUser, @Query('limit') limit?: string) {
    return this.notifications.list(user.userId, limit ? Number(limit) : 50);
  }

  @Patch('notifications/:id/read')
  read(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.notifications.markRead(user.userId, id);
  }

  @Post('notifications/read-all')
  readAll(@CurrentUser() user: AuthUser) {
    return this.notifications.markAllRead(user.userId);
  }

  @Get('me/notification-preferences')
  prefs(@CurrentUser() user: AuthUser) {
    return this.notifications.getPrefs(user.userId);
  }

  @Patch('me/notification-preferences')
  updatePrefs(
    @CurrentUser() user: AuthUser,
    @Body() body: Record<string, boolean>,
  ) {
    return this.notifications.updatePrefs(user.userId, body);
  }

  @Post('devices')
  register(
    @CurrentUser() user: AuthUser,
    @Body() body: { fcmToken: string; platform: string },
  ) {
    return this.notifications.registerDevice(
      user.userId,
      body.fcmToken,
      body.platform || 'unknown',
    );
  }

  @Post('devices/unregister')
  unregister(
    @CurrentUser() user: AuthUser,
    @Body() body: { fcmToken: string },
  ) {
    return this.notifications.unregisterDevice(user.userId, body.fcmToken);
  }
}
