import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Inject } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  REALTIME_ADAPTER_PORT,
  RealtimeAdapterPort,
} from '../../infrastructure/realtime/realtime-adapter.port';
import { JwtPayload } from '../auth/strategies/jwt.strategy';
import { MessagingService } from './messaging.service';
import { SendMessageDto } from './dto/messaging.dto';

type AuthedSocket = Socket & { data: { userId?: string; roles?: string[] } };

@WebSocketGateway({
  namespace: '/realtime',
  cors: { origin: true, credentials: true },
})
export class MessagingGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(MessagingGateway.name);
  private readonly eventBuckets = new Map<string, number[]>();

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly messaging: MessagingService,
    @Inject(REALTIME_ADAPTER_PORT)
    private readonly realtimeAdapter: RealtimeAdapterPort,
  ) {}

  async afterInit(server: Server) {
    await this.realtimeAdapter.apply?.(server);
    this.logger.log(`Socket.IO adapter: ${this.realtimeAdapter.name}`);
  }

  async handleConnection(client: AuthedSocket) {
    try {
      const token =
        (client.handshake.auth?.token as string | undefined) ||
        (client.handshake.headers.authorization?.replace(/^Bearer\s+/i, '') as
          string | undefined);
      if (!token) {
        client.disconnect(true);
        return;
      }
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        include: { roles: { include: { role: true } } },
      });
      if (!user || user.status === 'deleted' || user.status === 'suspended') {
        client.disconnect(true);
        return;
      }
      client.data.userId = user.id;
      client.data.roles = user.roles.map((r) => r.role.name);
      await client.join(this.userRoom(user.id));
      client.emit('ready', { userId: user.id });
      this.logger.debug(`socket connected user=${user.id}`);
    } catch {
      client.disconnect(true);
    }
  }

  handleDisconnect(client: AuthedSocket) {
    if (client.data.userId) {
      this.logger.debug(`socket disconnected user=${client.data.userId}`);
    }
  }

  @SubscribeMessage('auth:refresh')
  async reauth(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { token?: string },
  ) {
    if (!this.allow(client, 'auth:refresh')) return { ok: false };
    try {
      if (!body?.token) return { ok: false, error: 'token required' };
      const payload = await this.jwt.verifyAsync<JwtPayload>(body.token, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
      });
      if (!user || user.status !== 'active') {
        client.disconnect(true);
        return { ok: false };
      }
      if (client.data.userId && client.data.userId !== user.id) {
        await client.leave(this.userRoom(client.data.userId));
      }
      client.data.userId = user.id;
      await client.join(this.userRoom(user.id));
      return { ok: true };
    } catch {
      client.disconnect(true);
      return { ok: false };
    }
  }

  @SubscribeMessage('conversation:join')
  async joinConversation(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { conversationId?: string },
  ) {
    if (!this.allow(client, 'conversation:join')) return { ok: false };
    const userId = client.data.userId!;
    if (!body?.conversationId) return { ok: false, error: 'conversationId' };
    try {
      await this.messaging.getConversation(userId, body.conversationId);
      await client.join(this.conversationRoom(body.conversationId));
      return { ok: true };
    } catch {
      return { ok: false, error: 'forbidden' };
    }
  }

  @SubscribeMessage('conversation:leave')
  async leaveConversation(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { conversationId?: string },
  ) {
    if (!body?.conversationId) return { ok: false };
    await client.leave(this.conversationRoom(body.conversationId));
    return { ok: true };
  }

  @SubscribeMessage('message:send')
  async send(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody()
    body: { conversationId?: string } & SendMessageDto,
  ) {
    if (!this.allow(client, 'message:send', 40)) {
      return { ok: false, error: 'rate_limited' };
    }
    const userId = client.data.userId!;
    if (!body?.conversationId) return { ok: false, error: 'conversationId' };
    try {
      const { conversationId, ...dto } = body;
      const message = await this.messaging.sendMessage(
        userId,
        conversationId!,
        dto,
      );
      this.emitToConversation(conversationId!, 'message:new', message);
      return { ok: true, message };
    } catch (e: any) {
      return { ok: false, error: e?.message ?? 'failed' };
    }
  }

  @SubscribeMessage('conversation:read')
  async read(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { conversationId?: string },
  ) {
    if (!this.allow(client, 'conversation:read')) return { ok: false };
    const userId = client.data.userId!;
    if (!body?.conversationId) return { ok: false };
    await this.messaging.markRead(userId, body.conversationId);
    this.emitToConversation(body.conversationId, 'conversation:read', {
      conversationId: body.conversationId,
      userId,
      readAt: new Date().toISOString(),
    });
    return { ok: true };
  }

  /** Ephemeral typing indicator; only relayed to rooms the client has joined. */
  @SubscribeMessage('typing')
  typing(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { conversationId?: string; isTyping?: boolean },
  ) {
    if (!this.allow(client, 'typing', 60)) return { ok: false };
    if (!body?.conversationId) return { ok: false };
    const room = this.conversationRoom(body.conversationId);
    if (!client.rooms.has(room)) return { ok: false, error: 'not_joined' };
    client.to(room).emit('typing', {
      conversationId: body.conversationId,
      userId: client.data.userId,
      isTyping: body.isTyping !== false,
    });
    return { ok: true };
  }

  @SubscribeMessage('thread:join')
  async joinThread(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { threadId?: string },
  ) {
    if (!this.allow(client, 'thread:join')) return { ok: false };
    if (!body?.threadId) return { ok: false };
    // Any authenticated member may join to receive (THR-02: all can read)
    await client.join(this.threadRoom(body.threadId));
    return { ok: true };
  }

  emitToConversation(conversationId: string, event: string, payload: unknown) {
    this.server?.to(this.conversationRoom(conversationId)).emit(event, payload);
  }

  emitToThread(threadId: string, event: string, payload: unknown) {
    this.server?.to(this.threadRoom(threadId)).emit(event, payload);
  }

  emitToUser(userId: string, event: string, payload: unknown) {
    this.server?.to(this.userRoom(userId)).emit(event, payload);
  }

  private userRoom(userId: string) {
    return `user:${userId}`;
  }
  private conversationRoom(id: string) {
    return `conversation:${id}`;
  }
  private threadRoom(id: string) {
    return `thread:${id}`;
  }

  private allow(client: AuthedSocket, key: string, limit = 60): boolean {
    if (!client.data.userId) return false;
    const bucketKey = `${client.data.userId}:${key}`;
    const now = Date.now();
    const windowMs = 60_000;
    const hits = (this.eventBuckets.get(bucketKey) ?? []).filter(
      (t) => now - t < windowMs,
    );
    if (hits.length >= limit) {
      return false;
    }
    hits.push(now);
    this.eventBuckets.set(bucketKey, hits);
    return true;
  }
}
