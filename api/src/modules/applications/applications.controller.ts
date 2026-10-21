import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { ApplicationStatus, RoleName } from '@prisma/client';
import type { Request } from 'express';
import { memoryStorage } from 'multer';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ApplicationsService } from './applications.service';
import { CreateApplicationDto } from './dto/create-application.dto';
import { ReviewApplicationDto } from './dto/review-application.dto';

@ApiTags('applications')
@Controller()
export class ApplicationsController {
  constructor(private readonly apps: ApplicationsService) {}

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
  @Post('applications')
  create(@Body() dto: CreateApplicationDto, @Req() req: Request) {
    return this.apps.apply(dto, this.meta(req));
  }

  @Public()
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @Post('applications/:id/proof')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        email: { type: 'string' },
        file: { type: 'string', format: 'binary' },
      },
      required: ['email', 'file'],
    },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 15 * 1024 * 1024 },
    }),
  )
  uploadProof(
    @Param('id') id: string,
    @Body('email') email: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.apps.uploadProof(id, email, file);
  }

  @Public()
  @Get('applications/status')
  status(@Query('email') email: string) {
    return this.apps.getStatusByEmail(email);
  }

  @ApiBearerAuth()
  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/applications')
  listAdmin(@Query('status') status?: ApplicationStatus) {
    return this.apps.listForAdmin(status);
  }

  @ApiBearerAuth()
  @Roles(RoleName.admin, RoleName.super_admin)
  @Get('admin/applications/:id')
  getAdmin(@Param('id') id: string) {
    return this.apps.getById(id);
  }

  @ApiBearerAuth()
  @Roles(RoleName.admin, RoleName.super_admin)
  @Post('admin/applications/:id/review')
  review(
    @Param('id') id: string,
    @Body() dto: ReviewApplicationDto,
    @CurrentUser() user: AuthUser,
    @Req() req: Request,
  ) {
    return this.apps.review(id, dto, user.userId, this.meta(req));
  }
}
