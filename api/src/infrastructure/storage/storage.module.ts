import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ImageProcessorService } from './image-processor.service';
import { LocalDiskStorage } from './local-disk.storage';
import { NoopVirusScan } from './noop-virus-scan';
import { S3Storage } from './s3.storage';
import { STORAGE_PORT } from './storage.port';
import { VIRUS_SCAN_PORT } from './virus-scan.port';

@Global()
@Module({
  providers: [
    LocalDiskStorage,
    ImageProcessorService,
    { provide: VIRUS_SCAN_PORT, useClass: NoopVirusScan },
    {
      provide: STORAGE_PORT,
      inject: [ConfigService, LocalDiskStorage],
      useFactory: (config: ConfigService, local: LocalDiskStorage) => {
        const provider = (
          config.get<string>('STORAGE_PROVIDER') ?? 'local'
        ).toLowerCase();
        if (provider === 's3') {
          return new S3Storage(config);
        }
        return local;
      },
    },
  ],
  exports: [
    STORAGE_PORT,
    VIRUS_SCAN_PORT,
    ImageProcessorService,
    LocalDiskStorage,
  ],
})
export class StorageModule {}
