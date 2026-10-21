import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';
import * as path from 'path';
import { Readable } from 'stream';
import {
  PresignedUpload,
  SignedReadUrl,
  StoragePort,
  StoredObject,
} from './storage.port';

/**
 * Private S3 adapter. Objects stay private; clients use short-lived signed URLs.
 * CloudFront can sit in front later by swapping createSignedReadUrl implementation.
 */
@Injectable()
export class S3Storage implements StoragePort {
  readonly providerName = 's3';
  private readonly logger = new Logger(S3Storage.name);
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(private readonly config: ConfigService) {
    this.bucket = this.config.getOrThrow<string>('S3_BUCKET');
    this.client = new S3Client({
      region: this.config.get<string>('AWS_REGION') ?? 'us-east-1',
      credentials: this.config.get('AWS_ACCESS_KEY_ID')
        ? {
            accessKeyId: this.config.getOrThrow('AWS_ACCESS_KEY_ID'),
            secretAccessKey: this.config.getOrThrow('AWS_SECRET_ACCESS_KEY'),
          }
        : undefined, // default provider chain / IAM role on EB
    });
  }

  async putPrivate(params: {
    folder: string;
    originalName: string;
    mimeType: string;
    buffer: Buffer;
  }): Promise<StoredObject> {
    const safeFolder = params.folder.replace(/[^a-zA-Z0-9/_-]/g, '');
    const ext = path.extname(params.originalName).slice(0, 16);
    const key = path.posix.join(safeFolder, `${randomUUID()}${ext}`);
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: params.buffer,
        ContentType: params.mimeType,
        ACL: undefined, // bucket owner / private only
      }),
    );
    return { key, sizeBytes: params.buffer.length, mimeType: params.mimeType };
  }

  async createPresignedUpload(params: {
    folder: string;
    originalName: string;
    mimeType: string;
    maxBytes: number;
  }): Promise<PresignedUpload> {
    const safeFolder = params.folder.replace(/[^a-zA-Z0-9/_-]/g, '');
    const ext = path.extname(params.originalName).slice(0, 16);
    const key = path.posix.join(safeFolder, `${randomUUID()}${ext}`);
    const expiresInSeconds = 900;
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: params.mimeType,
    });
    const uploadUrl = await getSignedUrl(this.client, command, {
      expiresIn: expiresInSeconds,
    });
    return {
      uploadUrl,
      key,
      headers: { 'Content-Type': params.mimeType },
      expiresInSeconds,
    };
  }

  async createSignedReadUrl(
    key: string,
    expiresInSeconds = 300,
  ): Promise<SignedReadUrl> {
    const url = await getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { expiresIn: expiresInSeconds },
    );
    return { url, expiresInSeconds };
  }

  getAbsolutePath(key: string): string {
    // Not a local path; callers should use getObjectBuffer / signed URLs.
    return `s3://${this.bucket}/${key}`;
  }

  async getObjectBuffer(key: string): Promise<Buffer> {
    const res = await this.client.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
    );
    const stream = res.Body as Readable;
    const chunks: Buffer[] = [];
    for await (const chunk of stream) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
  }

  async exists(key: string): Promise<boolean> {
    try {
      await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      return true;
    } catch {
      return false;
    }
  }

  async delete(key: string): Promise<void> {
    try {
      await this.client.send(
        new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
      );
    } catch (e) {
      this.logger.warn(`S3 delete failed for ${key}: ${String(e)}`);
    }
  }
}
