import { Injectable, Logger } from '@nestjs/common';
import sharp from 'sharp';

export type ProcessedImage = {
  buffer: Buffer;
  mimeType: string;
  width: number;
  height: number;
  thumbnail: Buffer;
  thumbMimeType: string;
  exifStripped: true;
};

/**
 * Dev/server-side image pipeline: strip EXIF/GPS and create a thumbnail.
 * Production may move resizing to Lambda; keep this interface stable.
 */
@Injectable()
export class ImageProcessorService {
  private readonly logger = new Logger(ImageProcessorService.name);

  async processMemberImage(input: Buffer): Promise<ProcessedImage> {
    const image = sharp(input, { failOn: 'none' }).rotate(); // honor orientation, drop other metadata on re-encode
    const meta = await image.metadata();
    const pipeline = sharp(input, { failOn: 'none' }).rotate().withMetadata({
      // Explicitly omit exif/gps
      exif: {},
    });

    const normalized = await pipeline
      .jpeg({ quality: 85, mozjpeg: true })
      .toBuffer({ resolveWithObject: true });

    const thumb = await sharp(normalized.data)
      .resize(400, 400, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 75 })
      .toBuffer();

    this.logger.debug(
      `Processed image ${meta.width}x${meta.height} -> ${normalized.info.width}x${normalized.info.height}`,
    );

    return {
      buffer: normalized.data,
      mimeType: 'image/jpeg',
      width: normalized.info.width ?? meta.width ?? 0,
      height: normalized.info.height ?? meta.height ?? 0,
      thumbnail: thumb,
      thumbMimeType: 'image/jpeg',
      exifStripped: true,
    };
  }
}
