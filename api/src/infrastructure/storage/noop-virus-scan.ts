import { Injectable } from '@nestjs/common';
import { ScanResult, VirusScanPort } from './virus-scan.port';

@Injectable()
export class NoopVirusScan implements VirusScanPort {
  async scan(buffer: Buffer, filename: string): Promise<ScanResult> {
    void buffer;
    void filename;
    return { clean: true, engine: 'noop-dev', detail: 'Stage 2 placeholder' };
  }
}
