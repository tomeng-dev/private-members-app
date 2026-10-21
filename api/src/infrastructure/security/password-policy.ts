import { BadRequestException } from '@nestjs/common';

/** Min 10 chars, upper, lower, digit. Special recommended but not required for seniors. */
export function assertPasswordPolicy(password: string) {
  if (password.length < 10) {
    throw new BadRequestException('Password must be at least 10 characters');
  }
  if (
    !/[a-z]/.test(password) ||
    !/[A-Z]/.test(password) ||
    !/[0-9]/.test(password)
  ) {
    throw new BadRequestException(
      'Password must include upper, lower, and a number',
    );
  }
}
