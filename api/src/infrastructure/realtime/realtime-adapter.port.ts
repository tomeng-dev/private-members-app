/**
 * Abstraction for Socket.IO multi-instance scale-out.
 * Current: InMemoryRealtimeAdapter (single process).
 * Later: RedisRealtimeAdapter using @socket.io/redis-adapter.
 * See docs/realtime-redis-adapter.md.
 */
export const REALTIME_ADAPTER_PORT = Symbol('REALTIME_ADAPTER_PORT');

export interface RealtimeAdapterPort {
  /** Name for logs / readiness */
  readonly name: string;
  /** Optional factory applied when creating the Socket.IO server */
  apply?(io: unknown): Promise<void> | void;
}
