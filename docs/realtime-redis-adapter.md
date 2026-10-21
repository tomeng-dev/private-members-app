# Socket.IO Redis adapter (future)

Stage 4 / M5 runs **single-instance** Socket.IO with the default in-memory adapter (`InMemoryRealtimeAdapter`).

When the API scales horizontally:

1. Install `@socket.io/redis-adapter` and `ioredis` (or `redis`).
2. Implement `RedisRealtimeAdapter` against `RealtimeAdapterPort`:
   - Create pub/sub clients from `REDIS_URL`.
   - Call `io.adapter(createAdapter(pub, sub))` in `apply(io)`.
3. Bind it in `RealtimeModule` when `REALTIME_ADAPTER=redis`.
4. Sticky sessions are **not** required when using the Redis adapter.

Do not put Redis credentials in source; use env only.
