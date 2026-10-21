import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import {
  EventStatus,
  RsvpPaymentStatus,
  RsvpStatus,
  SpeakerRole,
} from '@prisma/client';

export class CreateThreadCommentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  body!: string;
}

export class MuteThreadDto {
  @IsOptional()
  @IsBoolean()
  mute?: boolean;
}

export class SpeakerDto {
  @IsString()
  @MaxLength(200)
  name!: string;

  @IsEnum(SpeakerRole)
  role!: SpeakerRole;

  @IsOptional()
  @IsString()
  bio?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  topic?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  hostName?: string;

  @IsOptional()
  @IsString()
  menuNotes?: string;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}

export class UpsertEventDto {
  @IsString()
  @MaxLength(255)
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  venueName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  venueAddress?: string;

  @IsDateString()
  startsAt!: string;

  @IsOptional()
  @IsDateString()
  endsAt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  timezone?: string;

  @IsOptional()
  @IsEnum(EventStatus)
  status?: EventStatus;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverImageKey?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  capacity?: number | null;

  @IsOptional()
  @IsDateString()
  rsvpCutoffAt?: string | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  feeUsdCents?: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  paymentLinkUrl?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SpeakerDto)
  speakers?: SpeakerDto[];
}

export class RsvpDto {
  @IsEnum(RsvpStatus)
  status!: RsvpStatus;
}

export class MarkRsvpPaymentDto {
  @IsEnum(RsvpPaymentStatus)
  paymentStatus!: RsvpPaymentStatus;
}

export class ScanQrDto {
  @IsString()
  @MinLength(10)
  @MaxLength(500)
  token!: string;
}

export class ManualCheckinDto {
  @IsUUID()
  userId!: string;

  @IsOptional()
  @IsBoolean()
  walkIn?: boolean;
}
