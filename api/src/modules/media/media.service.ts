import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaKind, MediaOwnerType, RoleName } from '@prisma/client';
import { promises as fs } from 'fs';
import { AuditService } from '../audit/audit.service';
import { ImageProcessorService } from '../../infrastructure/storage/image-processor.service';
import { LocalDiskStorage } from '../../infrastructure/storage/local-disk.storage';
import {
  STORAGE_PORT,
  StoragePort,
} from '../../infrastructure/storage/storage.port';
import {
  VIRUS_SCAN_PORT,
  VirusScanPort,
} from '../../infrastructure/storage/virus-scan.port';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

const IMAGE_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);
const VIDEO_MIME = new Set(['video/mp4', 'video/quicktime', 'video/webm']);
const DOC_MIME = new Set(['application/pdf']);
/** Phase 1 assumption: 2 min / 200 MB for videos. */
export const VIDEO_MAX_BYTES = 200 * 1024 * 1024;

@Injectable()
export class MediaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly audit: AuditService,
    private readonly images: ImageProcessorService,
    private readonly local: LocalDiskStorage,
    @Inject(STORAGE_PORT) private readonly storage: StoragePort,
    @Inject(VIRUS_SCAN_PORT) private readonly scanner: VirusScanPort,
  ) {}

  maxImageBytes() {
    return Number(this.config.get('MEDIA_MAX_IMAGE_BYTES') ?? 12 * 1024 * 1024);
  }

  maxUploadBytes(mime: string) {
    if (VIDEO_MIME.has(mime)) {
      return Number(
        this.config.get('MEDIA_MAX_VIDEO_BYTES') ?? VIDEO_MAX_BYTES,
      );
    }
    return this.maxImageBytes();
  }

  async requestUpload(params: {
    userId: string;
    folder: string;
    filename: string;
    mimeType: string;
  }) {
    this.assertAllowedMime(params.mimeType, params.folder);
    return this.storage.createPresignedUpload({
      folder: params.folder,
      originalName: params.filename,
      mimeType: params.mimeType,
      maxBytes: this.maxImageBytes(),
    });
  }

  async finalizeUpload(params: {
    userId: string;
    key: string;
    ownerType: MediaOwnerType;
    ownerId: string;
    vehicleId?: string;
    processImage?: boolean;
  }) {
    if (!(await this.storage.exists(params.key))) {
      throw new BadRequestException('Uploaded object not found');
    }
    let buffer = await this.storage.getObjectBuffer(params.key);
    if (buffer.length > this.maxImageBytes()) {
      await this.storage.delete(params.key);
      throw new BadRequestException('File too large');
    }

    const scan = await this.scanner.scan(buffer, params.key);
    if (!scan.clean) {
      await this.storage.delete(params.key);
      throw new BadRequestException('File failed security scan');
    }

    let mimeType = 'application/octet-stream';
    let width: number | undefined;
    let height: number | undefined;
    let thumbnailKey: string | undefined;
    let exifStripped = false;
    let kind: MediaKind = MediaKind.other;

    const lower = params.key.toLowerCase();
    const looksImage =
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      params.processImage !== false;

    if (looksImage && !lower.endsWith('.pdf')) {
      const processed = await this.images.processMemberImage(buffer);
      buffer = processed.buffer;
      mimeType = processed.mimeType;
      width = processed.width;
      height = processed.height;
      exifStripped = true;
      kind = MediaKind.image;
      // Replace original with stripped version
      await this.storage.delete(params.key);
      const stored = await this.storage.putPrivate({
        folder: params.key.split('/').slice(0, -1).join('/') || 'media',
        originalName: 'image.jpg',
        mimeType,
        buffer,
      });
      params.key = stored.key;
      const thumb = await this.storage.putPrivate({
        folder: 'thumbnails',
        originalName: 'thumb.jpg',
        mimeType: processed.thumbMimeType,
        buffer: processed.thumbnail,
      });
      thumbnailKey = thumb.key;
    } else if (lower.endsWith('.pdf')) {
      mimeType = 'application/pdf';
      kind = MediaKind.document;
    }

    const media = await this.prisma.media.create({
      data: {
        ownerType: params.ownerType,
        ownerId: params.ownerId,
        vehicleId: params.vehicleId,
        kind,
        storageKey: params.key,
        thumbnailKey,
        mimeType,
        sizeBytes: buffer.length,
        width,
        height,
        isPrivate: true,
        exifStripped,
        scanStatus: scan.engine,
      },
    });

    await this.audit.log({
      actorId: params.userId,
      action: 'media.uploaded',
      targetType: 'media',
      targetId: media.id,
      metadata: { ownerType: params.ownerType, ownerId: params.ownerId },
    });

    return this.toDto(media);
  }

  /** Direct multipart upload helper (local + tests). */
  async uploadBuffer(params: {
    userId: string;
    folder: string;
    filename: string;
    mimeType: string;
    buffer: Buffer;
    ownerType: MediaOwnerType;
    ownerId: string;
    vehicleId?: string;
  }) {
    this.assertAllowedMime(params.mimeType, params.folder);
    if (params.buffer.length > this.maxUploadBytes(params.mimeType)) {
      throw new BadRequestException('File too large');
    }
    const stored = await this.storage.putPrivate({
      folder: params.folder,
      originalName: params.filename,
      mimeType: params.mimeType,
      buffer: params.buffer,
    });
    return this.finalizeUpload({
      userId: params.userId,
      key: stored.key,
      ownerType: params.ownerType,
      ownerId: params.ownerId,
      vehicleId: params.vehicleId,
      processImage: IMAGE_MIME.has(params.mimeType),
    });
  }

  async signedUrlForMedia(
    mediaId: string,
    viewer: { userId: string; roles: string[] },
  ) {
    const media = await this.prisma.media.findUnique({
      where: { id: mediaId },
    });
    if (!media || media.deletedAt || media.hiddenAt) {
      throw new NotFoundException('Media not found');
    }
    // Members and staff can view non-verification media; verification stays admin-only
    if (media.ownerType === MediaOwnerType.verification) {
      if (
        !viewer.roles.some(
          (r) => r === RoleName.admin || r === RoleName.super_admin,
        )
      ) {
        throw new ForbiddenException();
      }
    }
    const signed = await this.storage.createSignedReadUrl(
      media.storageKey,
      300,
    );
    const thumb = media.thumbnailKey
      ? await this.storage.createSignedReadUrl(media.thumbnailKey, 300)
      : null;
    return { ...signed, thumbnailUrl: thumb?.url ?? null, mediaId: media.id };
  }

  async handleLocalUpload(params: {
    key: string;
    exp: string;
    sig: string;
    mime: string;
    buffer: Buffer;
  }) {
    const expNum = Number(params.exp);
    if (!expNum || expNum < Math.floor(Date.now() / 1000)) {
      throw new UnauthorizedException('Upload URL expired');
    }
    if (
      !this.local.verifySignature(
        `${params.key}:${params.exp}:${params.mime}`,
        params.sig,
      )
    ) {
      throw new UnauthorizedException('Invalid upload signature');
    }
    if (params.buffer.length > this.maxImageBytes()) {
      throw new BadRequestException('File too large');
    }
    const abs = this.local.getAbsolutePath(params.key);
    await fs.mkdir(pathDir(abs), { recursive: true });
    await fs.writeFile(abs, params.buffer);
    return { ok: true, key: params.key };
  }

  async streamSigned(params: { key: string; exp: string; sig: string }) {
    const expNum = Number(params.exp);
    if (!expNum || expNum < Math.floor(Date.now() / 1000)) {
      throw new UnauthorizedException('URL expired');
    }
    if (
      !this.local.verifySignature(`${params.key}:${params.exp}`, params.sig)
    ) {
      throw new UnauthorizedException('Invalid signature');
    }
    if (!(await this.local.exists(params.key))) {
      throw new NotFoundException();
    }
    return this.local.getAbsolutePath(params.key);
  }

  async hideMedia(mediaId: string, actorId: string, hide: boolean) {
    const media = await this.prisma.media.update({
      where: { id: mediaId },
      data: { hiddenAt: hide ? new Date() : null },
    });
    await this.audit.log({
      actorId,
      action: hide ? 'media.hidden' : 'media.unhidden',
      targetType: 'media',
      targetId: mediaId,
    });
    return media;
  }

  private assertAllowedMime(mime: string, folder: string) {
    if (folder.includes('verification')) {
      if (![...IMAGE_MIME, ...DOC_MIME].includes(mime)) {
        throw new BadRequestException('Invalid verification file type');
      }
      return;
    }
    if (IMAGE_MIME.has(mime) || VIDEO_MIME.has(mime)) return;
    throw new BadRequestException(
      'Only JPEG, PNG, WebP images or MP4/MOV/WebM video allowed',
    );
  }

  private toDto(media: {
    id: string;
    kind: MediaKind;
    mimeType: string;
    sizeBytes: number;
    width: number | null;
    height: number | null;
    storageKey: string;
    thumbnailKey: string | null;
    exifStripped: boolean;
  }) {
    return {
      id: media.id,
      kind: media.kind,
      mimeType: media.mimeType,
      sizeBytes: media.sizeBytes,
      width: media.width,
      height: media.height,
      exifStripped: media.exifStripped,
      hasThumbnail: !!media.thumbnailKey,
    };
  }
}

function pathDir(abs: string) {
  const idx = Math.max(abs.lastIndexOf('/'), abs.lastIndexOf('\\'));
  return idx >= 0 ? abs.slice(0, idx) : abs;
}
