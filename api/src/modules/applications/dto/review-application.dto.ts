import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class ReviewApplicationDto {
  @ApiProperty({ enum: ['approve', 'decline', 'more_info'] })
  @IsIn(['approve', 'decline', 'more_info'])
  decision!: 'approve' | 'decline' | 'more_info';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  internalNote?: string;

  @ApiPropertyOptional({ description: 'Shown to applicant when declined' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  declineReason?: string;

  @ApiPropertyOptional({
    description: 'Message when requesting more information',
  })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  moreInfoMessage?: string;

  @ApiPropertyOptional({
    description: 'Grant founding member badge if under cap (first 20)',
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  grantFoundingMember?: boolean;
}
