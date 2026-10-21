import { describe, expect, it } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import { assertPasswordPolicy } from './password-policy';

describe('password policy', () => {
  it('rejects short', () => {
    expect(() => assertPasswordPolicy('Ab1')).toThrow(BadRequestException);
  });
  it('accepts strong', () => {
    expect(() => assertPasswordPolicy('MemberPass1!')).not.toThrow();
  });
});
