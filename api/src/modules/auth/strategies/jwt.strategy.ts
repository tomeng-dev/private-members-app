import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';

export type JwtPayload = {
  sub: string;
  email: string;
  roles: string[];
};

/**
 * Supports JWT key rotation via JWT_KID + JWT_ACCESS_SECRET_PREVIOUS.
 * Tokens signed with the previous secret remain valid until they expire.
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const current = config.getOrThrow<string>('JWT_ACCESS_SECRET');
    const previous = config.get<string>('JWT_ACCESS_SECRET_PREVIOUS');
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKeyProvider: (
        _req: unknown,
        rawJwt: string,
        done: (err: Error | null, secret?: string) => void,
      ) => {
        try {
          const parts = rawJwt.split('.');
          if (parts.length < 2) return done(null, current);
          const header = JSON.parse(
            Buffer.from(parts[0], 'base64url').toString('utf8'),
          ) as { kid?: string };
          const kid = header.kid ?? 'v1';
          const activeKid = config.get<string>('JWT_KID') ?? 'v1';
          if (previous && kid !== activeKid) {
            return done(null, previous);
          }
          return done(null, current);
        } catch {
          return done(null, current);
        }
      },
    });
  }

  async validate(payload: JwtPayload) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: { roles: { include: { role: true } } },
    });
    if (
      !user ||
      user.status === 'deleted' ||
      user.status === 'suspended' ||
      user.deletionRequestedAt
    ) {
      throw new UnauthorizedException('Account not active');
    }
    return {
      userId: user.id,
      email: user.email,
      roles: user.roles.map((r) => r.role.name),
    };
  }
}
