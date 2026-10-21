import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserStatus } from '@prisma/client';
import { PasswordService } from '../../infrastructure/crypto/password.service';
import { TokenService } from '../../infrastructure/crypto/token.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { MAIL_PORT, MailPort } from '../../infrastructure/mail/mail.port';
import { emailTemplates } from '../../infrastructure/mail/templates/email-layout';
import { Inject } from '@nestjs/common';
import { AuditService } from '../audit/audit.service';
import { TotpService } from './totp.service';
import { RoleName } from '@prisma/client';
import { HibpService } from '../../infrastructure/security/hibp.service';
import { assertPasswordPolicy } from '../../infrastructure/security/password-policy';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly audit: AuditService,
    private readonly totp: TotpService,
    private readonly hibp: HibpService,
    @Inject(MAIL_PORT) private readonly mail: MailPort,
  ) {}

  async login(
    email: string,
    password: string,
    meta: { ip?: string; ua?: string },
  ) {
    const user = await this.prisma.user.findUnique({
      where: { email: email.toLowerCase() },
      include: { roles: { include: { role: true } } },
    });
    if (!user?.passwordHash) {
      throw new UnauthorizedException('Invalid email or password');
    }
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      throw new UnauthorizedException(
        'Account temporarily locked. Try again later.',
      );
    }
    if (
      user.status === UserStatus.suspended ||
      user.status === UserStatus.deleted
    ) {
      throw new UnauthorizedException('Account is not active');
    }
    if (user.deletionRequestedAt) {
      throw new UnauthorizedException('Account is pending deletion');
    }
    if (user.status === UserStatus.pending_password) {
      throw new UnauthorizedException(
        'Please set your password using the link from your approval email',
      );
    }
    const ok = await this.passwords.verify(user.passwordHash, password);
    if (!ok) {
      const max = Number(this.config.get('LOGIN_MAX_FAILURES') ?? 8);
      const lockMin = Number(this.config.get('LOGIN_LOCKOUT_MINUTES') ?? 15);
      const fails = (user.failedLoginCount ?? 0) + 1;
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          failedLoginCount: fails,
          lockedUntil:
            fails >= max ? new Date(Date.now() + lockMin * 60_000) : null,
        },
      });
      await this.audit.log({
        action: 'auth.login_failed',
        targetType: 'user',
        targetId: user.id,
        ipAddress: meta.ip,
        userAgent: meta.ua,
        metadata: { fails },
      });
      throw new UnauthorizedException('Invalid email or password');
    }
    await this.prisma.user.update({
      where: { id: user.id },
      data: { failedLoginCount: 0, lockedUntil: null },
    });

    const roles = user.roles.map((r) => r.role.name);
    const staffRoles = new Set<string>([
      RoleName.admin,
      RoleName.moderator,
      RoleName.super_admin,
    ]);
    const isStaff = roles.some((r) => staffRoles.has(r));
    const enforce2fa =
      (this.config.get('STAFF_2FA_REQUIRED') ?? 'false').toLowerCase() ===
      'true';

    if (isStaff && enforce2fa) {
      const preAuth = await this.jwt.signAsync(
        { sub: user.id, email: user.email, purpose: 'totp' },
        {
          expiresIn: '10m',
          secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
        },
      );
      if (!user.totpEnabledAt || !user.totpSecret) {
        return {
          requiresTotp: true,
          setupRequired: true,
          preAuthToken: preAuth,
          user: { id: user.id, email: user.email, roles },
        };
      }
      return {
        requiresTotp: true,
        setupRequired: false,
        preAuthToken: preAuth,
        user: { id: user.id, email: user.email, roles },
      };
    }

    return this.finishLogin(user, roles, meta);
  }

  async finishLogin(
    user: {
      id: string;
      email: string;
      firstName: string;
      lastName: string;
      foundingMember: boolean;
      membershipStatus: any;
    },
    roles: string[],
    meta: { ip?: string; ua?: string },
  ) {
    const tokens = await this.issueTokens(user.id, user.email, roles, meta);
    await this.audit.log({
      actorId: user.id,
      action: 'auth.login',
      targetType: 'user',
      targetId: user.id,
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: this.config.get('JWT_ACCESS_TTL') ?? '15m',
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        roles,
        foundingMember: user.foundingMember,
        membershipStatus: user.membershipStatus,
      },
    };
  }

  async refresh(refreshToken: string, meta: { ip?: string; ua?: string }) {
    const hash = this.tokens.hash(refreshToken);
    const stored = await this.prisma.refreshToken.findFirst({
      where: { tokenHash: hash },
      include: {
        user: { include: { roles: { include: { role: true } } } },
      },
    });
    if (!stored) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    if (stored.revokedAt) {
      // Reuse detection: revoke entire family
      await this.prisma.refreshToken.updateMany({
        where: { familyId: stored.familyId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      await this.audit.log({
        actorId: stored.userId,
        action: 'auth.refresh_reuse_detected',
        targetType: 'refresh_family',
        targetId: stored.familyId,
        ipAddress: meta.ip,
        userAgent: meta.ua,
      });
      throw new UnauthorizedException('Refresh token reuse detected');
    }
    if (stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    const roles = stored.user.roles.map((r) => r.role.name);
    const issued = await this.issueTokens(
      stored.userId,
      stored.user.email,
      roles,
      meta,
      stored.familyId,
    );
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { replacedById: issued.refreshTokenId },
    });

    return {
      accessToken: issued.accessToken,
      refreshToken: issued.refreshToken,
      expiresIn: this.config.get('JWT_ACCESS_TTL') ?? '15m',
    };
  }

  async logout(
    refreshToken: string | undefined,
    userId: string,
    meta: { ip?: string; ua?: string },
  ) {
    if (refreshToken) {
      const hash = this.tokens.hash(refreshToken);
      await this.prisma.refreshToken.updateMany({
        where: { tokenHash: hash, userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    await this.audit.log({
      actorId: userId,
      action: 'auth.logout',
      targetType: 'user',
      targetId: userId,
      ipAddress: meta.ip,
      userAgent: meta.ua,
    });
    return { ok: true };
  }

  async forgotPassword(email: string) {
    const user = await this.prisma.user.findUnique({
      where: { email: email.toLowerCase() },
    });
    // Always return ok to avoid email enumeration
    if (!user || user.status === UserStatus.deleted) {
      return { ok: true };
    }
    const raw = this.tokens.generateOpaque();
    const days = 1;
    await this.prisma.passwordReset.create({
      data: {
        userId: user.id,
        tokenHash: this.tokens.hash(raw),
        expiresAt: new Date(Date.now() + days * 24 * 60 * 60 * 1000),
      },
    });
    const base = this.config.get('APP_PUBLIC_URL') ?? 'http://localhost:8080';
    const link = `${base}/reset-password?token=${raw}`;
    await this.mail.send({
      to: user.email,
      subject: 'Reset your password',
      text: `Use this link to reset your password (expires in 24h):\n${link}`,
      html: emailTemplates.resetPassword(user.firstName ?? 'Member', link),
    });
    return { ok: true };
  }

  async resetOrSetPassword(
    token: string,
    password: string,
    action: 'reset' | 'set',
  ) {
    const hash = this.tokens.hash(token);
    const row = await this.prisma.passwordReset.findFirst({
      where: { tokenHash: hash, usedAt: null },
    });
    if (!row || row.expiresAt < new Date()) {
      throw new BadRequestException('Invalid or expired token');
    }
    assertPasswordPolicy(password);
    if (await this.hibp.isBreached(password)) {
      throw new BadRequestException(
        'Choose a password that has not appeared in a data breach',
      );
    }
    const passwordHash = await this.passwords.hash(password);
    await this.prisma.$transaction([
      this.prisma.passwordReset.update({
        where: { id: row.id },
        data: { usedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: row.userId },
        data: {
          passwordHash,
          status: UserStatus.active,
        },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId: row.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    await this.audit.log({
      actorId: row.userId,
      action: action === 'set' ? 'auth.password_set' : 'auth.password_reset',
      targetType: 'user',
      targetId: row.userId,
    });
    return { ok: true };
  }

  /** Create a set-password token for a newly approved member (used by applications service). */
  async createSetPasswordToken(userId: string): Promise<string> {
    const raw = this.tokens.generateOpaque();
    await this.prisma.passwordReset.create({
      data: {
        userId,
        tokenHash: this.tokens.hash(raw),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });
    return raw;
  }

  private async issueTokens(
    userId: string,
    email: string,
    roles: string[],
    meta: { ip?: string; ua?: string },
    familyId?: string,
  ) {
    const kid = this.config.get<string>('JWT_KID') ?? 'v1';
    const accessToken = await this.jwt.signAsync(
      { sub: userId, email, roles },
      {
        secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
        expiresIn: this.config.get('JWT_ACCESS_TTL') ?? '15m',
        header: { alg: 'HS256', typ: 'JWT', kid },
      },
    );
    const refreshRaw = this.tokens.generateOpaque();
    const ttlDays = Number(this.config.get('JWT_REFRESH_TTL_DAYS') ?? 30);
    const family = familyId ?? this.tokens.generateOpaque(16);
    const row = await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: this.tokens.hash(refreshRaw),
        familyId: family,
        expiresAt: new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000),
        ipAddress: meta.ip,
        userAgent: meta.ua?.slice(0, 500),
      },
    });
    return {
      accessToken,
      refreshToken: refreshRaw,
      refreshTokenId: row.id,
    };
  }

  async listSessions(userId: string) {
    const rows = await this.prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: {
        id: true,
        createdAt: true,
        expiresAt: true,
        ipAddress: true,
        userAgent: true,
      },
    });
    return { items: rows };
  }

  async revokeSession(userId: string, sessionId: string) {
    const n = await this.prisma.refreshToken.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (!n.count) throw new BadRequestException('Session not found');
    await this.audit.log({
      actorId: userId,
      action: 'auth.session_revoked',
      targetType: 'refresh_token',
      targetId: sessionId,
    });
    return { ok: true };
  }

  async revokeAllSessions(userId: string) {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    await this.audit.log({
      actorId: userId,
      action: 'auth.sessions_revoked_all',
      targetType: 'user',
      targetId: userId,
    });
    return { ok: true };
  }

  async beginTotpSetup(preAuthToken: string) {
    const payload = await this.verifyPreAuth(preAuthToken);
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: payload.sub },
    });
    const secret = this.totp.generateSecret();
    await this.prisma.user.update({
      where: { id: user.id },
      data: { totpSecret: secret, totpEnabledAt: null },
    });
    return {
      secret,
      otpauthUrl: this.totp.keyuri(user.email, secret),
    };
  }

  async confirmTotpSetup(preAuthToken: string, code: string) {
    const payload = await this.verifyPreAuth(preAuthToken);
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: payload.sub },
      include: { roles: { include: { role: true } } },
    });
    if (!user.totpSecret) throw new BadRequestException('Start setup first');
    if (!this.totp.verify(code, user.totpSecret)) {
      throw new UnauthorizedException('Invalid authenticator code');
    }
    const recovery = this.totp.generateRecoveryCodes();
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        totpEnabledAt: new Date(),
        totpRecoveryHashes: JSON.stringify(
          recovery.map((c) => this.totp.hashRecovery(c)),
        ),
      },
    });
    await this.audit.log({
      actorId: user.id,
      action: 'auth.totp_enabled',
      targetType: 'user',
      targetId: user.id,
    });
    const roles = user.roles.map((r) => r.role.name);
    const session = await this.finishLogin(user, roles, {});
    return { ...session, recoveryCodes: recovery };
  }

  async verifyTotpLogin(
    preAuthToken: string,
    code: string,
    meta: { ip?: string; ua?: string },
  ) {
    const payload = await this.verifyPreAuth(preAuthToken);
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: payload.sub },
      include: { roles: { include: { role: true } } },
    });
    if (!user.totpSecret || !user.totpEnabledAt) {
      throw new UnauthorizedException('2FA not enabled');
    }
    let ok = this.totp.verify(code, user.totpSecret);
    if (!ok && user.totpRecoveryHashes) {
      const hashes: string[] = JSON.parse(user.totpRecoveryHashes);
      const h = this.totp.hashRecovery(code);
      const idx = hashes.indexOf(h);
      if (idx >= 0) {
        ok = true;
        hashes.splice(idx, 1);
        await this.prisma.user.update({
          where: { id: user.id },
          data: { totpRecoveryHashes: JSON.stringify(hashes) },
        });
      }
    }
    if (!ok) throw new UnauthorizedException('Invalid 2FA code');
    const roles = user.roles.map((r) => r.role.name);
    return this.finishLogin(user, roles, meta);
  }

  private async verifyPreAuth(token: string) {
    try {
      const payload = await this.jwt.verifyAsync<{
        sub: string;
        email: string;
        purpose?: string;
      }>(token, { secret: this.config.getOrThrow('JWT_ACCESS_SECRET') });
      if (payload.purpose !== 'totp') {
        throw new UnauthorizedException('Invalid pre-auth token');
      }
      return payload;
    } catch {
      throw new UnauthorizedException('Invalid or expired pre-auth token');
    }
  }
}
