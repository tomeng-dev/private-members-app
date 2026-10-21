import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { AuthService } from './auth.service';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { SetPasswordDto } from './dto/set-password.dto';
import { IsString, MinLength } from 'class-validator';

class TotpPreAuthDto {
  @IsString()
  preAuthToken!: string;
}
class TotpCodeDto {
  @IsString()
  preAuthToken!: string;
  @IsString()
  @MinLength(6)
  code!: string;
}

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  private meta(req: Request) {
    return {
      ip:
        (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
        req.ip,
      ua: req.headers['user-agent'],
    };
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('login')
  @HttpCode(200)
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto.email, dto.password, this.meta(req));
  }

  @Public()
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @Post('2fa/setup')
  @HttpCode(200)
  totpSetup(@Body() dto: TotpPreAuthDto) {
    return this.auth.beginTotpSetup(dto.preAuthToken);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('2fa/setup/confirm')
  @HttpCode(200)
  totpConfirm(@Body() dto: TotpCodeDto) {
    return this.auth.confirmTotpSetup(dto.preAuthToken, dto.code);
  }

  @Public()
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @Post('2fa/verify')
  @HttpCode(200)
  totpVerify(@Body() dto: TotpCodeDto, @Req() req: Request) {
    return this.auth.verifyTotpLogin(
      dto.preAuthToken,
      dto.code,
      this.meta(req),
    );
  }

  @Public()
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @Post('refresh')
  @HttpCode(200)
  refresh(@Body() dto: RefreshDto, @Req() req: Request) {
    return this.auth.refresh(dto.refreshToken, this.meta(req));
  }

  @ApiBearerAuth()
  @Post('logout')
  @HttpCode(200)
  logout(
    @Body() dto: RefreshDto,
    @CurrentUser() user: AuthUser,
    @Req() req: Request,
  ) {
    return this.auth.logout(dto.refreshToken, user.userId, this.meta(req));
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('forgot-password')
  @HttpCode(200)
  forgot(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto.email);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('reset-password')
  @HttpCode(200)
  reset(@Body() dto: ResetPasswordDto) {
    return this.auth.resetOrSetPassword(dto.token, dto.password, 'reset');
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('set-password')
  @HttpCode(200)
  setPassword(@Body() dto: SetPasswordDto) {
    return this.auth.resetOrSetPassword(dto.token, dto.password, 'set');
  }

  @ApiBearerAuth()
  @Get('sessions')
  sessions(@CurrentUser() user: AuthUser) {
    return this.auth.listSessions(user.userId);
  }

  @ApiBearerAuth()
  @Delete('sessions/:id')
  @HttpCode(200)
  revokeSession(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.auth.revokeSession(user.userId, id);
  }

  @ApiBearerAuth()
  @Post('sessions/revoke-all')
  @HttpCode(200)
  revokeAll(@CurrentUser() user: AuthUser) {
    return this.auth.revokeAllSessions(user.userId);
  }
}
