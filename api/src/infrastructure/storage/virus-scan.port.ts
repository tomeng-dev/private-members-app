export const VIRUS_SCAN_PORT = Symbol('VIRUS_SCAN_PORT');

export type ScanResult = { clean: boolean; engine: string; detail?: string };

/** Placeholder for ClamAV / macOS XProtect / AWS S3 malware protection. */
export interface VirusScanPort {
  scan(buffer: Buffer, filename: string): Promise<ScanResult>;
}
