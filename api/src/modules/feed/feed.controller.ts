import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { ReportStatus, RoleName } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  CreateCommentDto,
  CreatePostDto,
  ReportDto,
  ResolveReportDto,
  UpdatePostDto,
} from './dto/create-post.dto';
import { FeedService } from './feed.service';

@ApiTags('feed')
@ApiBearerAuth()
@Controller()
export class FeedController {
  constructor(private readonly feed: FeedService) {}

  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @Post('posts')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePostDto) {
    return this.feed.createPost(user.userId, dto);
  }

  @Get('feed')
  list(
    @CurrentUser() user: AuthUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.feed.feed(user.userId, cursor, limit ? Number(limit) : 20);
  }

  @Get('posts/:id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.feed.getPost(id, user.userId);
  }

  @Patch('posts/:id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdatePostDto,
  ) {
    return this.feed.updatePost(user.userId, id, dto);
  }

  @Delete('posts/:id')
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.feed.deletePost(user, id);
  }

  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @Post('posts/:id/like')
  like(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.feed.toggleLike(user.userId, id);
  }

  @Throttle({ default: { limit: 40, ttl: 60000 } })
  @Post('posts/:id/comments')
  comment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateCommentDto,
  ) {
    return this.feed.addComment(user.userId, id, dto);
  }

  @Get('posts/:id/comments')
  comments(@Param('id') id: string) {
    return this.feed.listComments(id);
  }

  @Delete('comments/:id')
  deleteComment(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.feed.deleteComment(user, id);
  }

  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @Post('reports')
  report(@CurrentUser() user: AuthUser, @Body() dto: ReportDto) {
    return this.feed.report(user.userId, dto);
  }

  @Roles(RoleName.moderator, RoleName.admin, RoleName.super_admin)
  @Get('admin/reports')
  listReports(@Query('status') status?: ReportStatus) {
    return this.feed.listReports(status);
  }

  @Roles(RoleName.moderator, RoleName.admin, RoleName.super_admin)
  @Post('admin/reports/:id/resolve')
  resolve(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ResolveReportDto,
  ) {
    return this.feed.resolveReport(user.userId, id, dto);
  }

  @Roles(RoleName.moderator, RoleName.admin, RoleName.super_admin)
  @Post('admin/posts/:id/hide')
  hide(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: { hide?: boolean },
  ) {
    return this.feed.hidePost(user.userId, id, body.hide !== false);
  }
}
