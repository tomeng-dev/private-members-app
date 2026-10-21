import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomUUID } from 'crypto';
import { promises as fs } from 'fs';
import * as path from 'path';
import {
  PresignedUpload,
  SignedReadUrl,
  StoragePort,
  StoredObject,
} from './storage.port';

@Injectable()
export class LocalDiskStorage implements StoragePort {
  readonly providerName = 'local';
  private readonly root: string;
  private readonly publicBase: string;
  private readonly signingSecret: string;

  constructor(private readonly config: ConfigService) {
    this.root =
      this.config.get<string>('STORAGE_ROOT') ??
      path.join(process.cwd(), 'uploads');
    this.publicBase =
      this.config.get<string>('STORAGE_PUBLIC_BASE_URL') ??
      'http://localhost:3000/uploads';
    this.signingSecret =
      this.config.get<string>('STORAGE_SIGNING_SECRET') ??
      this.config.get<string>('JWT_ACCESS_SECRET') ??
      'dev-storage-secret';
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
    const abs = path.join(this.root, key);
    await fs.mkdir(path.dirname(abs), { recursive: true });
    await fs.writeFile(abs, params.buffer);
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
    const exp = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const sig = this.sign(`${key}:${exp}:${params.mimeType}`);
    const uploadUrl = `${this.apiBase()}/api/media/local-upload?key=${encodeURIComponent(key)}&exp=${exp}&sig=${sig}&mime=${encodeURIComponent(params.mimeType)}`;
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
    const exp = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const sig = this.sign(`${key}:${exp}`);
    const url = `${this.apiBase()}/api/media/signed?key=${encodeURIComponent(key)}&exp=${exp}&sig=${sig}`;
    return { url, expiresInSeconds };
  }

  getAbsolutePath(key: string): string {
    const normalized = path.normalize(key).replace(/^(\.\.(\/|\\|$))+/, '');
    return path.join(this.root, normalized);
  }

  async getObjectBuffer(key: string): Promise<Buffer> {
    return fs.readFile(this.getAbsolutePath(key));
  }

  async exists(key: string): Promise<boolean> {
    try {
      await fs.access(this.getAbsolutePath(key));
      return true;
    } catch {
      return false;
    }
  }

  async delete(key: string): Promise<void> {
    try {
      await fs.unlink(this.getAbsolutePath(key));
    } catch {
      /* ignore */
    }
  }

  verifySignature(payload: string, sig: string): boolean {
    return this.sign(payload) === sig;
  }

  private sign(payload: string): string {
    return createHmac('sha256', this.signingSecret)
      .update(payload)
      .digest('hex');
  }

  private apiBase(): string {
    return (
      this.config.get<string>('API_PUBLIC_URL') ?? 'http://localhost:3000'
    ).replace(/\/$/, '');
  }
}
