import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MediaOwnerType, ReportStatus, ReportTargetType } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { fetchLinkPreview } from './domain/link-preview';
import {
  CreateCommentDto,
  CreatePostDto,
  ReportDto,
  ResolveReportDto,
  UpdatePostDto,
} from './dto/create-post.dto';

@Injectable()
export class FeedService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async createPost(authorId: string, dto: CreatePostDto) {
    if (
      !dto.body?.trim() &&
      !dto.linkUrl &&
      !dto.mediaIds?.length &&
      !dto.sharedFromPostId
    ) {
      throw new BadRequestException(
        'Post must include text, link, media, or a shared post',
      );
    }

    let sharedFromPostId: string | undefined;
    if (dto.sharedFromPostId) {
      const original = await this.prisma.post.findFirst({
        where: { id: dto.sharedFromPostId, deletedAt: null, hiddenAt: null },
      });
      if (!original) throw new NotFoundException('Shared post not found');
      sharedFromPostId = original.id;
    }

    let linkMeta: Awaited<ReturnType<typeof fetchLinkPreview>> | undefined;
    if (dto.linkUrl) {
      linkMeta = await fetchLinkPreview(dto.linkUrl);
    }

    const post = await this.prisma.$transaction(async (tx) => {
      const created = await tx.post.create({
        data: {
          authorId,
          body: dto.body?.trim() || null,
          linkUrl: linkMeta?.url ?? dto.linkUrl,
          linkTitle: linkMeta?.title,
          linkDescription: linkMeta?.description,
          linkImageUrl: linkMeta?.imageUrl,
          sharedFromPostId,
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
        // Video limit assumption: 200MB already enforced on upload; duration optional
        await tx.media.updateMany({
          where: { id: { in: dto.mediaIds } },
          data: {
            ownerType: MediaOwnerType.post,
            ownerId: created.id,
            postId: created.id,
          },
        });
      }
      return created;
    });

    await this.audit.log({
      actorId: authorId,
      action: sharedFromPostId ? 'post.shared' : 'post.created',
      targetType: 'post',
      targetId: post.id,
    });
    return this.getPost(post.id, authorId);
  }

  async updatePost(authorId: string, postId: string, dto: UpdatePostDto) {
    const post = await this.prisma.post.findFirst({
      where: { id: postId, deletedAt: null },
    });
    if (!post) throw new NotFoundException();
    if (post.authorId !== authorId) throw new ForbiddenException();
    await this.prisma.post.update({
      where: { id: postId },
      data: { body: dto.body?.trim() },
    });
    await this.audit.log({
      actorId: authorId,
      action: 'post.updated',
      targetType: 'post',
      targetId: postId,
    });
    return this.getPost(postId, authorId);
  }

  async deletePost(actor: { userId: string; roles: string[] }, postId: string) {
    const post = await this.prisma.post.findFirst({
      where: { id: postId, deletedAt: null },
    });
    if (!post) throw new NotFoundException();
    const isStaff = actor.roles.some((r) =>
      ['moderator', 'admin', 'super_admin'].includes(r),
    );
    if (post.authorId !== actor.userId && !isStaff) {
      throw new ForbiddenException();
    }
    await this.prisma.post.update({
      where: { id: postId },
      data: { deletedAt: new Date() },
    });
    await this.audit.log({
      actorId: actor.userId,
      action: 'post.deleted',
      targetType: 'post',
      targetId: postId,
    });
    return { ok: true };
  }

  async hidePost(actorId: string, postId: string, hide: boolean) {
    await this.prisma.post.update({
      where: { id: postId },
      data: { hiddenAt: hide ? new Date() : null },
    });
    await this.audit.log({
      actorId,
      action: hide ? 'post.hidden' : 'post.unhidden',
      targetType: 'post',
      targetId: postId,
    });
    return { ok: true };
  }

  async feed(viewerId: string, cursor?: string, limit = 20) {
    const take = Math.min(Math.max(limit, 1), 50);
    const posts = await this.prisma.post.findMany({
      where: {
        deletedAt: null,
        hiddenAt: null,
        ...(cursor ? { createdAt: { lt: new Date(cursor) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      include: this.postInclude(viewerId),
    });
    const hasMore = posts.length > take;
    const page = hasMore ? posts.slice(0, take) : posts;
    return {
      items: page.map((p) => this.toPostDto(p, viewerId)),
      nextCursor: hasMore
        ? page[page.length - 1].createdAt.toISOString()
        : null,
    };
  }

  async getPost(postId: string, viewerId: string) {
    const post = await this.prisma.post.findFirst({
      where: { id: postId, deletedAt: null, hiddenAt: null },
      include: this.postInclude(viewerId),
    });
    if (!post) throw new NotFoundException();
    return this.toPostDto(post, viewerId);
  }

  async toggleLike(userId: string, postId: string) {
    const post = await this.prisma.post.findFirst({
      where: { id: postId, deletedAt: null, hiddenAt: null },
    });
    if (!post) throw new NotFoundException();
    const existing = await this.prisma.like.findUnique({
      where: { userId_postId: { userId, postId } },
    });
    if (existing) {
      await this.prisma.like.delete({
        where: { userId_postId: { userId, postId } },
      });
      return { liked: false };
    }
    await this.prisma.like.create({ data: { userId, postId } });
    return { liked: true };
  }

  async addComment(userId: string, postId: string, dto: CreateCommentDto) {
    const post = await this.prisma.post.findFirst({
      where: { id: postId, deletedAt: null, hiddenAt: null },
    });
    if (!post) throw new NotFoundException();
    const comment = await this.prisma.comment.create({
      data: { postId, authorId: userId, body: dto.body.trim() },
      include: {
        author: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            foundingMember: true,
          },
        },
      },
    });
    return comment;
  }

  async deleteComment(
    actor: { userId: string; roles: string[] },
    commentId: string,
  ) {
    const comment = await this.prisma.comment.findFirst({
      where: { id: commentId, deletedAt: null },
    });
    if (!comment) throw new NotFoundException();
    const isStaff = actor.roles.some((r) =>
      ['moderator', 'admin', 'super_admin'].includes(r),
    );
    if (comment.authorId !== actor.userId && !isStaff) {
      throw new ForbiddenException();
    }
    await this.prisma.comment.update({
      where: { id: commentId },
      data: { deletedAt: new Date() },
    });
    await this.audit.log({
      actorId: actor.userId,
      action: 'comment.deleted',
      targetType: 'comment',
      targetId: commentId,
    });
    return { ok: true };
  }

  async listComments(postId: string) {
    return this.prisma.comment.findMany({
      where: { postId, deletedAt: null, hiddenAt: null },
      orderBy: { createdAt: 'asc' },
      include: {
        author: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            foundingMember: true,
          },
        },
      },
    });
  }

  async report(reporterId: string, dto: ReportDto) {
    const map: Record<string, ReportTargetType> = {
      post: ReportTargetType.post,
      comment: ReportTargetType.comment,
      message: ReportTargetType.message,
      user: ReportTargetType.user,
      thread_comment: ReportTargetType.thread_comment,
    };
    const targetType = map[dto.targetType] ?? ReportTargetType.user;
    const report = await this.prisma.report.create({
      data: {
        reporterId,
        targetType,
        targetId: dto.targetId,
        reason: dto.reason.trim(),
      },
    });
    await this.audit.log({
      actorId: reporterId,
      action: 'report.created',
      targetType: dto.targetType,
      targetId: dto.targetId,
      metadata: { reportId: report.id },
    });
    return report;
  }

  async listReports(status?: ReportStatus) {
    const reports = await this.prisma.report.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'asc' },
      include: {
        reporter: {
          select: { id: true, email: true, firstName: true, lastName: true },
        },
      },
    });
    // Moderators cannot browse DMs; only the reported message snapshot is attached.
    return Promise.all(
      reports.map(async (r) => {
        // Lightweight previews so moderators can triage without opening each item.
        const person = {
          select: { id: true, firstName: true, lastName: true, email: true },
        } as const;
        if (r.targetType === ReportTargetType.post) {
          const post = await this.prisma.post.findUnique({
            where: { id: r.targetId },
            select: {
              id: true,
              body: true,
              hiddenAt: true,
              createdAt: true,
              author: person,
            },
          });
          return { ...r, reportedPost: post };
        }
        if (r.targetType === ReportTargetType.comment) {
          const comment = await this.prisma.comment.findUnique({
            where: { id: r.targetId },
            select: {
              id: true,
              body: true,
              hiddenAt: true,
              createdAt: true,
              author: person,
            },
          });
          return { ...r, reportedComment: comment };
        }
        if (r.targetType === ReportTargetType.user) {
          const user = await this.prisma.user.findUnique({
            where: { id: r.targetId },
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              status: true,
            },
          });
          return { ...r, reportedUser: user };
        }
        if (r.targetType !== ReportTargetType.message) return r;
        const message = await this.prisma.message.findUnique({
          where: { id: r.targetId },
          select: {
            id: true,
            body: true,
            linkUrl: true,
            sharedPostId: true,
            createdAt: true,
            deletedAt: true,
            sender: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
              },
            },
          },
        });
        return { ...r, reportedMessage: message };
      }),
    );
  }

  async resolveReport(
    actorId: string,
    reportId: string,
    dto: ResolveReportDto,
  ) {
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
    });
    if (!report) throw new NotFoundException();
    if (dto.hideContent) {
      if (report.targetType === ReportTargetType.post) {
        await this.prisma.post.update({
          where: { id: report.targetId },
          data: { hiddenAt: new Date() },
        });
      } else if (report.targetType === ReportTargetType.comment) {
        await this.prisma.comment.update({
          where: { id: report.targetId },
          data: { hiddenAt: new Date() },
        });
      } else if (report.targetType === ReportTargetType.message) {
        await this.prisma.message.update({
          where: { id: report.targetId },
          data: { deletedAt: new Date() },
        });
      } else if (report.targetType === ReportTargetType.thread_comment) {
        await this.prisma.threadComment.update({
          where: { id: report.targetId },
          data: { hiddenAt: new Date() },
        });
      }
    }
    const updated = await this.prisma.report.update({
      where: { id: reportId },
      data: {
        status:
          dto.decision === 'resolved'
            ? ReportStatus.resolved
            : ReportStatus.dismissed,
        resolution: dto.resolution,
        resolvedById: actorId,
      },
    });
    await this.audit.log({
      actorId,
      action: `report.${dto.decision}`,
      targetType: 'report',
      targetId: reportId,
      metadata: { hideContent: !!dto.hideContent },
    });
    return updated;
  }

  private postInclude(viewerId: string) {
    return {
      author: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          foundingMember: true,
          company: true,
          title: true,
        },
      },
      media: { where: { deletedAt: null, hiddenAt: null } },
      likes: { where: { userId: viewerId }, select: { userId: true } },
      _count: {
        select: {
          likes: true,
          comments: { where: { deletedAt: null, hiddenAt: null } },
        },
      },
      sharedFrom: {
        include: {
          author: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              foundingMember: true,
            },
          },
        },
      },
    } as const;
  }

  private toPostDto(post: any, viewerId: string) {
    return {
      id: post.id,
      body: post.body,
      linkUrl: post.linkUrl,
      linkTitle: post.linkTitle,
      linkDescription: post.linkDescription,
      linkImageUrl: post.linkImageUrl,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      author: post.author,
      media: post.media,
      likeCount: post._count?.likes ?? 0,
      commentCount: post._count?.comments ?? 0,
      likedByMe: (post.likes?.length ?? 0) > 0,
      sharedFrom: post.sharedFrom
        ? {
            id: post.sharedFrom.id,
            body: post.sharedFrom.body,
            author: post.sharedFrom.author,
          }
        : null,
      isOwner: post.authorId === viewerId,
    };
  }
}
