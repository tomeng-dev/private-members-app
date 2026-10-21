import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { MediaOwnerType, RoleName } from '@prisma/client';
import type { Request, Response } from 'express';
import { createReadStream } from 'fs';
import { memoryStorage } from 'multer';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { MediaService } from './media.service';

@ApiTags('media')
@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @ApiBearerAuth()
  @Post('presign')
  presign(
    @CurrentUser() user: AuthUser,
    @Body()
    body: { folder: string; filename: string; mimeType: string },
  ) {
    return this.media.requestUpload({
      userId: user.userId,
      folder: body.folder,
      filename: body.filename,
      mimeType: body.mimeType,
    });
  }

  @ApiBearerAuth()
  @Post('finalize')
  finalize(
    @CurrentUser() user: AuthUser,
    @Body()
    body: {
      key: string;
      ownerType: MediaOwnerType;
      ownerId: string;
      vehicleId?: string;
    },
  ) {
    return this.media.finalizeUpload({
      userId: user.userId,
      key: body.key,
      ownerType: body.ownerType,
      ownerId: body.ownerId,
      vehicleId: body.vehicleId,
    });
  }

  @ApiBearerAuth()
  @Post('upload')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 12 * 1024 * 1024 },
    }),
  )
  upload(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File,
    @Body()
    body: {
      folder: string;
      ownerType: MediaOwnerType;
      ownerId: string;
      vehicleId?: string;
    },
  ) {
    return this.media.uploadBuffer({
      userId: user.userId,
      folder: body.folder || 'media',
      filename: file.originalname,
      mimeType: file.mimetype,
      buffer: file.buffer,
      ownerType: body.ownerType,
      ownerId: body.ownerId,
      vehicleId: body.vehicleId,
    });
  }

  @ApiBearerAuth()
  @Get(':id/url')
  url(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.media.signedUrlForMedia(id, user);
  }

  @Public()
  @Post('local-upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 12 * 1024 * 1024 },
    }),
  )
  localUpload(
    @Query('key') key: string,
    @Query('exp') exp: string,
    @Query('sig') sig: string,
    @Query('mime') mime: string,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request,
  ) {
    const buffer = file?.buffer ?? (req.body as Buffer);
    return this.media.handleLocalUpload({
      key,
      exp,
      sig,
      mime,
      buffer: Buffer.isBuffer(buffer) ? buffer : file.buffer,
    });
  }

  @Public()
  @Get('signed')
  async signed(
    @Query('key') key: string,
    @Query('exp') exp: string,
    @Query('sig') sig: string,
    @Res() res: Response,
  ) {
    const abs = await this.media.streamSigned({ key, exp, sig });
    createReadStream(abs).pipe(res);
  }

  @ApiBearerAuth()
  @Roles(RoleName.moderator, RoleName.admin, RoleName.super_admin)
  @Post(':id/hide')
  hide(
    @Param('id') id: string,
    @Body() body: { hide?: boolean },
    @CurrentUser() user: AuthUser,
  ) {
    return this.media.hideMedia(id, user.userId, body.hide !== false);
  }
}
