/**
 * Single source of truth for "is this a production runtime?".
 * Production if NODE_ENV or APP_ENV is "production" (case-insensitive).
 * Dev shortcuts (default member password, quick-login account list) are only
 * allowed when this returns false AND DEV_DEFAULT_MEMBER_PASSWORD is set.
 */
export type EnvReader = { get<T = string>(key: string): T | undefined };

export function isProductionEnv(config: EnvReader): boolean {
  const node = (config.get<string>('NODE_ENV') ?? '').toLowerCase();
  const app = (config.get<string>('APP_ENV') ?? '').toLowerCase();
  return node === 'production' || app === 'production' || app === 'staging';
}

export function devDefaultMemberPassword(config: EnvReader): string | null {
  if (isProductionEnv(config)) return null;
  const pw = config.get<string>('DEV_DEFAULT_MEMBER_PASSWORD');
  return pw && pw.length >= 10 ? pw : null;
}

export function environmentLabel(
  config: EnvReader,
): 'DEV' | 'STAGING' | 'PROD' {
  const node = (config.get<string>('NODE_ENV') ?? '').toLowerCase();
  const app = (config.get<string>('APP_ENV') ?? '').toLowerCase();
  if (app === 'staging') return 'STAGING';
  if (node === 'production' || app === 'production') return 'PROD';
  return 'DEV';
}
