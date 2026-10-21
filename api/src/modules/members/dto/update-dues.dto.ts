import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MembershipStatus } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateDuesDto {
  @ApiProperty({ enum: MembershipStatus })
  @IsEnum(MembershipStatus)
  membershipStatus!: MembershipStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  externalRef?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;

  @ApiPropertyOptional({ description: 'Admin override for founding badge' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  foundingMember?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  amountUsdCents?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  renewalDate?: string;
}
