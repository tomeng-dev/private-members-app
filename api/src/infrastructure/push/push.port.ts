export const PUSH_PORT = Symbol('PUSH_PORT');

export type PushPayload = {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

/**
 * Push delivery port. M5 wires hooks only; FCM adapter lands in M8.
 */
export interface PushPort {
  send(payload: PushPayload): Promise<void>;
}
