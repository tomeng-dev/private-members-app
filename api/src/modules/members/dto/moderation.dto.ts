import {
  IsArray,
  IsEnum,
  IsIn,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { RoleName } from '@prisma/client';

export class ModerationActionDto {
  @IsIn(['warn', 'suspend', 'reinstate'])
  action!: 'warn' | 'suspend' | 'reinstate';

  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  reason!: string;
}

export class AssignRolesDto {
  @IsArray()
  @IsEnum(RoleName, { each: true })
  roles!: RoleName[];
}
