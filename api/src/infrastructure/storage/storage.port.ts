export const STORAGE_PORT = Symbol('STORAGE_PORT');

export interface StoredObject {
  key: string;
  sizeBytes: number;
  mimeType: string;
}

export interface PresignedUpload {
  uploadUrl: string;
  key: string;
  headers?: Record<string, string>;
  expiresInSeconds: number;
}

export interface SignedReadUrl {
  url: string;
  expiresInSeconds: number;
}

export interface StoragePort {
  putPrivate(params: {
    folder: string;
    originalName: string;
    mimeType: string;
    buffer: Buffer;
  }): Promise<StoredObject>;

  /** Create a short-lived PUT URL (S3) or a local upload token URL. */
  createPresignedUpload(params: {
    folder: string;
    originalName: string;
    mimeType: string;
    maxBytes: number;
  }): Promise<PresignedUpload>;

  /** Short-lived GET URL for private objects (S3 signed / CloudFront-ready). */
  createSignedReadUrl(
    key: string,
    expiresInSeconds?: number,
  ): Promise<SignedReadUrl>;

  getAbsolutePath(key: string): string;

  getObjectBuffer(key: string): Promise<Buffer>;

  exists(key: string): Promise<boolean>;

  delete(key: string): Promise<void>;

  /** Adapter name for diagnostics: local | s3 */
  readonly providerName: string;
}
