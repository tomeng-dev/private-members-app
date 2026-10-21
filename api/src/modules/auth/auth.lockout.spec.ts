import { beforeEach, describe, expect, it, vi } from 'vitest';
import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';

describe('AuthService lockout', () => {
  const prisma: any = {
    user: {
      findUnique: vi.fn(),
      update: vi.fn(),
    },
    refreshToken: { create: vi.fn(), updateMany: vi.fn(), update: vi.fn() },
  };
  const passwords = { verify: vi.fn(), hash: vi.fn() };
  const tokens = { hash: vi.fn(), generateOpaque: vi.fn(() => 'x') };
  const jwt = { signAsync: vi.fn(async () => 'jwt') };
  const config = {
    get: vi.fn((k: string) => {
      if (k === 'LOGIN_MAX_FAILURES') return '3';
      if (k === 'LOGIN_LOCKOUT_MINUTES') return '15';
      if (k === 'JWT_ACCESS_TTL') return '15m';
      if (k === 'JWT_KID') return 'v1';
      return undefined;
    }),
    getOrThrow: vi.fn((k: string) => {
      if (k === 'JWT_ACCESS_SECRET') return 'secret';
      throw new Error(k);
    }),
  };
  const audit = { log: vi.fn() };
  const totp = {};
  const hibp = { isBreached: vi.fn(async () => false) };
  const mail = { send: vi.fn() };
  let svc: AuthService;

  beforeEach(() => {
    vi.clearAllMocks();
    svc = new AuthService(
      prisma,
      passwords as any,
      tokens as any,
      jwt as any,
      config as any,
      audit as any,
      totp as any,
      hibp as any,
      mail as any,
    );
  });

  it('rejects when locked', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      passwordHash: 'h',
      status: 'active',
      lockedUntil: new Date(Date.now() + 60_000),
      roles: [],
    });
    await expect(svc.login('a@b.c', 'x', {})).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('increments failures on bad password', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      passwordHash: 'h',
      status: 'active',
      lockedUntil: null,
      failedLoginCount: 2,
      roles: [],
    });
    passwords.verify.mockResolvedValue(false);
    await expect(svc.login('a@b.c', 'bad', {})).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(prisma.user.update).toHaveBeenCalled();
  });
});
