import {
  IsArray,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class StartConversationDto {
  @IsUUID()
  memberId!: string;
}

export class SendMessageDto {
  @IsOptional()
  @IsString()
  @MaxLength(8000)
  body?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  linkUrl?: string;

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  mediaIds?: string[];

  @IsOptional()
  @IsUUID()
  sharedPostId?: string;
}

export class SharePostDmDto {
  @IsUUID()
  postId!: string;

  @IsUUID()
  memberId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;
}

export class BlockMemberDto {
  @IsUUID()
  memberId!: string;
}

export class ReportMessageDto {
  @IsUUID()
  messageId!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  reason!: string;
}
