import { Injectable } from '@nestjs/common';
import { RealtimeAdapterPort } from './realtime-adapter.port';

@Injectable()
export class InMemoryRealtimeAdapter implements RealtimeAdapterPort {
  readonly name = 'in-memory';

  apply(): void {
    // Default Socket.IO single-process adapter — nothing to wire.
  }
}
