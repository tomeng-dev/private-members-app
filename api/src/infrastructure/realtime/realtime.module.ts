import { Global, Module } from '@nestjs/common';
import { InMemoryRealtimeAdapter } from './in-memory-realtime.adapter';
import { REALTIME_ADAPTER_PORT } from './realtime-adapter.port';

@Global()
@Module({
  providers: [
    { provide: REALTIME_ADAPTER_PORT, useClass: InMemoryRealtimeAdapter },
  ],
  exports: [REALTIME_ADAPTER_PORT],
})
export class RealtimeModule {}
