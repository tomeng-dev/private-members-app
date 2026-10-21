import { describe, expect, it } from 'vitest';
import {
  devDefaultMemberPassword,
  environmentLabel,
  isProductionEnv,
} from './runtime-env';

const cfg = (m: Record<string, string>) => ({ get: (k: string) => m[k] as any });

describe('runtime env guard', () => {
  it('treats NODE_ENV=production as production', () => {
    expect(isProductionEnv(cfg({ NODE_ENV: 'production' }))).toBe(true);
  });
  it('treats APP_ENV=production / staging as production', () => {
    expect(isProductionEnv(cfg({ APP_ENV: 'production' }))).toBe(true);
    expect(isProductionEnv(cfg({ APP_ENV: 'staging' }))).toBe(true);
  });
  it('never returns a dev password in production even if set', () => {
    expect(
      devDefaultMemberPassword(
        cfg({ NODE_ENV: 'production', DEV_DEFAULT_MEMBER_PASSWORD: 'test-only-pw-0001' }),
      ),
    ).toBeNull();
  });
  it('returns dev password in development', () => {
    expect(
      devDefaultMemberPassword(
        cfg({ NODE_ENV: 'development', DEV_DEFAULT_MEMBER_PASSWORD: 'test-only-pw-0001' }),
      ),
    ).toBe('test-only-pw-0001');
  });
  it('ignores too-short dev password', () => {
    expect(devDefaultMemberPassword(cfg({ DEV_DEFAULT_MEMBER_PASSWORD: 'x' }))).toBeNull();
  });
  it('labels environments', () => {
    expect(environmentLabel(cfg({}))).toBe('DEV');
    expect(environmentLabel(cfg({ APP_ENV: 'staging' }))).toBe('STAGING');
    expect(environmentLabel(cfg({ NODE_ENV: 'production' }))).toBe('PROD');
  });
});
