import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEmail,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateApplicationDto {
  @ApiProperty()
  @IsEmail()
  email!: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  firstName!: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  lastName!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(40)
  phone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  company?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  state?: string;

  @ApiProperty({ example: 'Ferrari' })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  vehicleMake!: string;

  @ApiProperty({ example: '488 GTB' })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  vehicleModel!: string;

  @ApiProperty({ example: 2019 })
  @Type(() => Number)
  @IsInt()
  @Min(1950)
  @Max(2100)
  vehicleYear!: number;

  @ApiProperty({
    example: 250000,
    description: 'Estimated USD value; must be >= 200000',
  })
  @Type(() => Number)
  @IsInt()
  @Min(200000)
  vehicleEstimatedValue!: number;

  @ApiPropertyOptional({ description: 'Optional invite code' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  inviteCode?: string;

  @ApiProperty({ description: 'Must be true — Privacy Notice consent' })
  @Type(() => Boolean)
  @IsBoolean()
  consentPrivacy!: boolean;

  @ApiProperty({ description: 'Must be true — Terms consent' })
  @Type(() => Boolean)
  @IsBoolean()
  consentTerms!: boolean;
}
