import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class BulkApplicationsDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @IsUUID('all', { each: true })
  ids!: string[];

  @ApiProperty({ enum: ['approve', 'decline'] })
  @IsIn(['approve', 'decline'])
  action!: 'approve' | 'decline';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  reason?: string;
}

export class BulkMembersDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @IsUUID('all', { each: true })
  ids!: string[];

  @ApiProperty({ enum: ['suspend', 'reinstate'] })
  @IsIn(['suspend', 'reinstate'])
  action!: 'suspend' | 'reinstate';

  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  reason!: string;
}

export const BROADCAST_SEGMENTS = [
  'all',
  'founding',
  'dues_due',
  'overdue',
  'event_rsvps',
] as const;
export type BroadcastSegment = (typeof BROADCAST_SEGMENTS)[number];

export class BroadcastDto {
  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  title!: string;

  @ApiProperty()
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  body!: string;

  @ApiProperty({ enum: BROADCAST_SEGMENTS })
  @IsIn(BROADCAST_SEGMENTS as unknown as string[])
  segment!: BroadcastSegment;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  eventId?: string;

  @ApiProperty({ type: [String], enum: ['push', 'email', 'in_app'] })
  @IsArray()
  @ArrayMinSize(1)
  @IsIn(['push', 'email', 'in_app'], { each: true })
  channels!: ('push' | 'email' | 'in_app')[];

  @ApiPropertyOptional({ description: 'Only count recipients, send nothing' })
  @IsOptional()
  @IsBoolean()
  dryRun?: boolean;
}
