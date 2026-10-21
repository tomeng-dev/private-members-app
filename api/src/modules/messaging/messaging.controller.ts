import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import {
  BlockMemberDto,
  ReportMessageDto,
  SendMessageDto,
  SharePostDmDto,
  StartConversationDto,
} from './dto/messaging.dto';
import { MessagingGateway } from './messaging.gateway';
import { MessagingService } from './messaging.service';

@ApiTags('messaging')
@ApiBearerAuth()
@Controller()
export class MessagingController {
  constructor(
    private readonly messaging: MessagingService,
    private readonly gateway: MessagingGateway,
  ) {}

  @Post('conversations')
  start(@CurrentUser() user: AuthUser, @Body() dto: StartConversationDto) {
    return this.messaging.startDirect(user.userId, dto.memberId);
  }

  @Get('conversations')
  list(@CurrentUser() user: AuthUser) {
    return this.messaging.listConversations(user.userId);
  }

  @Get('conversations/:id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messaging.getConversation(user.userId, id);
  }

  @Get('conversations/:id/messages')
  messages(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.messaging.listMessages(
      user.userId,
      id,
      cursor,
      limit ? Number(limit) : 30,
    );
  }

  @Throttle({ default: { limit: 60, ttl: 60000 } })
  @Post('conversations/:id/messages')
  async send(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ) {
    const message = await this.messaging.sendMessage(user.userId, id, dto);
    this.gateway.emitToConversation(id, 'message:new', message);
    return message;
  }

  @Post('conversations/:id/read')
  async read(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const result = await this.messaging.markRead(user.userId, id);
    this.gateway.emitToConversation(id, 'conversation:read', {
      conversationId: id,
      userId: user.userId,
      readAt: new Date().toISOString(),
    });
    return result;
  }

  @Delete('messages/:id')
  async deleteMessage(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const result = await this.messaging.deleteOwnMessage(user.userId, id);
    this.gateway.emitToConversation(result.conversationId, 'message:deleted', {
      messageId: id,
    });
    return { ok: true };
  }

  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @Post('messages/share-post')
  async sharePost(@CurrentUser() user: AuthUser, @Body() dto: SharePostDmDto) {
    const message = await this.messaging.sharePostViaDm(user.userId, dto);
    this.gateway.emitToConversation(
      message.conversationId,
      'message:new',
      message,
    );
    return message;
  }

  @Post('blocks')
  block(@CurrentUser() user: AuthUser, @Body() dto: BlockMemberDto) {
    return this.messaging.blockMember(user.userId, dto.memberId);
  }

  @Delete('blocks/:memberId')
  unblock(@CurrentUser() user: AuthUser, @Param('memberId') memberId: string) {
    return this.messaging.unblockMember(user.userId, memberId);
  }

  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @Post('messages/report')
  report(@CurrentUser() user: AuthUser, @Body() dto: ReportMessageDto) {
    return this.messaging.reportMessage(user.userId, dto);
  }
}
