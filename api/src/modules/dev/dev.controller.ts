import { Controller, Get, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import {
  devDefaultMemberPassword,
  environmentLabel,
} from '../../common/env/runtime-env';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

/**
 * Development-only helpers. `accounts` 404s in production/staging (or when no
 * dev password is configured) so the shortcut cannot be discovered or used
 * there; `env` only reports the DEV/STAGING/PROD label used by the UI badge.
 */
@ApiTags('dev')
@Controller('dev')
export class DevController {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  @Public()
  @Get('env')
  env() {
    return { environment: environmentLabel(this.config) };
  }

  @Public()
  @Get('accounts')
  async accounts() {
    const pw = devDefaultMemberPassword(this.config);
    if (!pw) throw new NotFoundException();
    const users = await this.prisma.user.findMany({
      where: {
        email: { startsWith: 'member', endsWith: '@example.com' },
        deletedAt: null,
      },
      include: { roles: { include: { role: true } } },
      orderBy: { email: 'asc' },
      take: 20,
    });
    return {
      note: 'DEV ONLY — demo accounts; password from DEV_DEFAULT_MEMBER_PASSWORD',
      items: users.map((u) => ({
        email: u.email,
        name: `${u.firstName} ${u.lastName}`,
        status: u.status,
        foundingMember: u.foundingMember,
        roles: u.roles.map((r) => r.role.name),
      })),
    };
  }
}
