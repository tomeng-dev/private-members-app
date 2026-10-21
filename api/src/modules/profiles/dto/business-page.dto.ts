import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UpsertBusinessPageDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(200) companyName!: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  services?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(8000)
  background?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  website?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  contactEmail?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(40)
  contactPhone?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() showContactEmail?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() showContactPhone?: boolean;
}
