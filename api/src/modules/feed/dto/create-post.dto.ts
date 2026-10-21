import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
} from 'class-validator';

export class CreatePostDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  body?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  @MaxLength(1000)
  linkUrl?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  mediaIds?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  sharedFromPostId?: string;
}

export class UpdatePostDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  body?: string;
}

export class CreateCommentDto {
  @ApiProperty()
  @IsString()
  @MaxLength(2000)
  body!: string;
}

export class ReportDto {
  @ApiProperty({
    enum: ['post', 'comment', 'user', 'message', 'thread_comment'],
  })
  @IsIn(['post', 'comment', 'user', 'message', 'thread_comment'])
  targetType!: 'post' | 'comment' | 'user' | 'message' | 'thread_comment';

  @ApiProperty()
  @IsString()
  targetId!: string;

  @ApiProperty()
  @IsString()
  @MaxLength(2000)
  reason!: string;
}

export class ResolveReportDto {
  @ApiProperty({ enum: ['resolved', 'dismissed'] })
  @IsIn(['resolved', 'dismissed'])
  decision!: 'resolved' | 'dismissed';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  resolution?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  hideContent?: boolean;
}
