import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MediaOwnerType, ReportTargetType } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PUSH_PORT, PushPort } from '../../infrastructure/push/push.port';
import {
  ReportMessageDto,
  SendMessageDto,
  SharePostDmDto,
} from './dto/messaging.dto';

@Injectable()
export class MessagingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    @Inject(PUSH_PORT) private readonly push: PushPort,
  ) {}

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    const row = await this.prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: a, blockedId: b },
          { blockerId: b, blockedId: a },
        ],
      },
    });
    return !!row;
  }

  async startDirect(userId: string, memberId: string) {
    if (userId === memberId) {
      throw new BadRequestException('Cannot message yourself');
    }
    const other = await this.prisma.user.findFirst({
      where: { id: memberId, deletedAt: null, status: 'active' },
    });
    if (!other) throw new NotFoundException('Member not found');
    if (await this.isBlockedEitherWay(userId, memberId)) {
      throw new ForbiddenException('Messaging blocked');
    }

    const existing = await this.prisma.conversation.findFirst({
      where: {
        type: 'direct',
        AND: [
          { participants: { some: { userId } } },
          { participants: { some: { userId: memberId } } },
        ],
      },
      include: { participants: true },
    });
    if (existing && existing.participants.length === 2) {
      return this.getConversation(userId, existing.id);
    }

    const conversation = await this.prisma.conversation.create({
      data: {
        type: 'direct',
        participants: {
          create: [{ userId }, { userId: memberId }],
        },
      },
    });
    await this.audit.log({
      actorId: userId,
      action: 'conversation.started',
      targetType: 'conversation',
      targetId: conversation.id,
      metadata: { memberId },
    });
    return this.getConversation(userId, conversation.id);
  }

  async listConversations(userId: string) {
    const parts = await this.prisma.conversationParticipant.findMany({
      where: { userId },
      include: {
        conversation: {
          include: {
            participants: {
              include: {
                user: {
                  select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                    foundingMember: true,
                    avatarKey: true,
                  },
                },
              },
            },
            messages: {
              where: { deletedAt: null },
              orderBy: { createdAt: 'desc' },
              take: 1,
            },
          },
        },
      },
      orderBy: { conversation: { updatedAt: 'desc' } },
    });

    const items = await Promise.all(
      parts.map(async (p) => {
        const others = p.conversation.participants
          .filter((x) => x.userId !== userId)
          .map((x) => x.user);
        const last = p.conversation.messages[0] ?? null;
        const unread = await this.prisma.message.count({
          where: {
            conversationId: p.conversationId,
            deletedAt: null,
            senderId: { not: userId },
            createdAt: p.lastReadAt ? { gt: p.lastReadAt } : undefined,
          },
        });
        return {
          id: p.conversationId,
          type: p.conversation.type,
          updatedAt: p.conversation.updatedAt,
          participants: others,
          lastMessage: last
            ? {
                id: last.id,
                body: last.body,
                senderId: last.senderId,
                createdAt: last.createdAt,
                sharedPostId: last.sharedPostId,
              }
            : null,
          unreadCount: unread,
        };
      }),
    );
    return { items };
  }

  async getConversation(userId: string, conversationId: string) {
    await this.assertParticipant(userId, conversationId);
    const conversation = await this.prisma.conversation.findUniqueOrThrow({
      where: { id: conversationId },
      include: {
        participants: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                foundingMember: true,
                avatarKey: true,
              },
            },
          },
        },
      },
    });
    return {
      id: conversation.id,
      type: conversation.type,
      participants: conversation.participants.map((p) => p.user),
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
  }

  async listMessages(
    userId: string,
    conversationId: string,
    cursor?: string,
    limit = 30,
  ) {
    await this.assertParticipant(userId, conversationId);
    const take = Math.min(Math.max(limit, 1), 50);
    const cursorMsg = cursor
      ? await this.prisma.message.findUnique({ where: { id: cursor } })
      : null;

    const rows = await this.prisma.message.findMany({
      where: {
        conversationId,
        deletedAt: null,
        ...(cursorMsg ? { createdAt: { lt: cursorMsg.createdAt } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      include: {
        sender: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            foundingMember: true,
          },
        },
        sharedPost: {
          select: {
            id: true,
            body: true,
            author: {
              select: { id: true, firstName: true, lastName: true },
            },
          },
        },
      },
    });
    const hasMore = rows.length > take;
    const slice = hasMore ? rows.slice(0, take) : rows;
    const mediaByOwner = await this.prisma.media.findMany({
      where: {
        ownerType: MediaOwnerType.message,
        ownerId: { in: slice.map((m) => m.id) },
        deletedAt: null,
        hiddenAt: null,
      },
    });
    const mediaMap = new Map<string, typeof mediaByOwner>();
    for (const m of mediaByOwner) {
      const list = mediaMap.get(m.ownerId) ?? [];
      list.push(m);
      mediaMap.set(m.ownerId, list);
    }
    const items = slice.map((m) =>
      this.toMessageDto(m, mediaMap.get(m.id) ?? []),
    );
    return {
      items,
      nextCursor: hasMore ? slice[slice.length - 1]?.id : null,
    };
  }

  async sendMessage(
    userId: string,
    conversationId: string,
    dto: SendMessageDto,
  ) {
    await this.assertParticipant(userId, conversationId);
    const otherIds = await this.otherParticipantIds(conversationId, userId);
    for (const oid of otherIds) {
      if (await this.isBlockedEitherWay(userId, oid)) {
        throw new ForbiddenException('Messaging blocked');
      }
    }
    if (
      !dto.body?.trim() &&
      !dto.linkUrl &&
      !dto.mediaIds?.length &&
      !dto.sharedPostId
    ) {
      throw new BadRequestException(
        'Message must include text, link, media, or shared post',
      );
    }

    if (dto.sharedPostId) {
      const post = await this.prisma.post.findFirst({
        where: { id: dto.sharedPostId, deletedAt: null, hiddenAt: null },
      });
      if (!post) throw new NotFoundException('Post not found');
    }

    const message = await this.prisma.$transaction(async (tx) => {
      const created = await tx.message.create({
        data: {
          conversationId,
          senderId: userId,
          body: dto.body?.trim() || null,
          linkUrl: dto.linkUrl || null,
          sharedPostId: dto.sharedPostId || null,
        },
      });
      if (dto.mediaIds?.length) {
        const media = await tx.media.findMany({
          where: {
            id: { in: dto.mediaIds },
            deletedAt: null,
            hiddenAt: null,
          },
        });
        if (media.length !== dto.mediaIds.length) {
          throw new BadRequestException('One or more media IDs are invalid');
        }
        await tx.media.updateMany({
          where: { id: { in: dto.mediaIds } },
          data: {
            ownerType: MediaOwnerType.message,
            ownerId: created.id,
          },
        });
      }
      await tx.conversation.update({
        where: { id: conversationId },
        data: { updatedAt: new Date() },
      });
      return created;
    });

    const full = await this.getMessageDto(message.id);

    for (const oid of otherIds) {
      void this.push.send({
        userId: oid,
        title: 'New message',
        body: (dto.body?.trim() || 'Sent you a message').slice(0, 120),
        data: {
          type: 'dm',
          conversationId,
          messageId: message.id,
        },
      });
    }

    return full;
  }

  async sharePostViaDm(userId: string, dto: SharePostDmDto) {
    const conversation = await this.startDirect(userId, dto.memberId);
    return this.sendMessage(userId, conversation.id, {
      body: dto.note,
      sharedPostId: dto.postId,
    });
  }

  async markRead(userId: string, conversationId: string) {
    await this.assertParticipant(userId, conversationId);
    await this.prisma.conversationParticipant.update({
      where: {
        conversationId_userId: { conversationId, userId },
      },
      data: { lastReadAt: new Date() },
    });
    return { ok: true };
  }

  async deleteOwnMessage(userId: string, messageId: string) {
    const msg = await this.prisma.message.findUnique({
      where: { id: messageId },
    });
    if (!msg || msg.deletedAt) throw new NotFoundException();
    if (msg.senderId !== userId) {
      throw new ForbiddenException('Can only delete your own messages');
    }
    await this.prisma.message.update({
      where: { id: messageId },
      data: { deletedAt: new Date() },
    });
    await this.audit.log({
      actorId: userId,
      action: 'message.deleted',
      targetType: 'message',
      targetId: messageId,
    });
    return { ok: true, conversationId: msg.conversationId };
  }

  async blockMember(blockerId: string, memberId: string) {
    if (blockerId === memberId) {
      throw new BadRequestException('Cannot block yourself');
    }
    await this.prisma.userBlock.upsert({
      where: {
        blockerId_blockedId: { blockerId, blockedId: memberId },
      },
      create: { blockerId, blockedId: memberId },
      update: {},
    });
    await this.audit.log({
      actorId: blockerId,
      action: 'user.blocked',
      targetType: 'user',
      targetId: memberId,
    });
    return { ok: true };
  }

  async unblockMember(blockerId: string, memberId: string) {
    await this.prisma.userBlock.deleteMany({
      where: { blockerId, blockedId: memberId },
    });
    await this.audit.log({
      actorId: blockerId,
      action: 'user.unblocked',
      targetType: 'user',
      targetId: memberId,
    });
    return { ok: true };
  }

  async reportMessage(reporterId: string, dto: ReportMessageDto) {
    const msg = await this.prisma.message.findFirst({
      where: { id: dto.messageId, deletedAt: null },
    });
    if (!msg) throw new NotFoundException('Message not found');
    await this.assertParticipant(reporterId, msg.conversationId);
    const report = await this.prisma.report.create({
      data: {
        reporterId,
        targetType: ReportTargetType.message,
        targetId: msg.id,
        reason: dto.reason.trim(),
      },
    });
    await this.audit.log({
      actorId: reporterId,
      action: 'report.created',
      targetType: 'message',
      targetId: msg.id,
      metadata: { reportId: report.id },
    });
    return report;
  }

  /**
   * Moderators never list DMs. Only the reported message snapshot is exposed
   * via the reports queue (see FeedService.listReports enrichment).
   */
  async getReportedMessageSnapshot(messageId: string) {
    const msg = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: {
        sender: {
          select: { id: true, firstName: true, lastName: true, email: true },
        },
      },
    });
    if (!msg) return null;
    return {
      id: msg.id,
      body: msg.body,
      linkUrl: msg.linkUrl,
      sharedPostId: msg.sharedPostId,
      sender: msg.sender,
      createdAt: msg.createdAt,
      deletedAt: msg.deletedAt,
    };
  }

  private async assertParticipant(userId: string, conversationId: string) {
    const p = await this.prisma.conversationParticipant.findUnique({
      where: {
        conversationId_userId: { conversationId, userId },
      },
    });
    if (!p) {
      throw new ForbiddenException('Not a participant');
    }
  }

  private async otherParticipantIds(
    conversationId: string,
    userId: string,
  ): Promise<string[]> {
    const parts = await this.prisma.conversationParticipant.findMany({
      where: { conversationId, userId: { not: userId } },
      select: { userId: true },
    });
    return parts.map((p) => p.userId);
  }

  private async getMessageDto(id: string) {
    const m = await this.prisma.message.findUniqueOrThrow({
      where: { id },
      include: {
        sender: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            foundingMember: true,
          },
        },
        sharedPost: {
          select: {
            id: true,
            body: true,
            author: {
              select: { id: true, firstName: true, lastName: true },
            },
          },
        },
      },
    });
    const media = await this.prisma.media.findMany({
      where: {
        ownerType: MediaOwnerType.message,
        ownerId: id,
        deletedAt: null,
        hiddenAt: null,
      },
    });
    return this.toMessageDto(m, media);
  }

  private toMessageDto(m: any, media: unknown[]) {
    return {
      id: m.id,
      conversationId: m.conversationId,
      body: m.body,
      linkUrl: m.linkUrl,
      sharedPostId: m.sharedPostId,
      sharedPost: m.sharedPost ?? null,
      sender: m.sender,
      media,
      createdAt: m.createdAt,
    };
  }
}
