import { ForbiddenException } from '@nestjs/common';
import { RolesGuard } from './roles.guard';

describe('RolesGuard', () => {
  function ctx(roles: string[] | undefined, required: string[] | undefined) {
    const reflector = {
      getAllAndOverride: () => required,
    };
    const guard = new RolesGuard(reflector as any);
    const context = {
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({
        getRequest: () => ({ user: roles ? { roles } : {} }),
      }),
    };
    return { guard, context };
  }

  it('allows when no roles required', () => {
    const { guard, context } = ctx(['member'], undefined);
    expect(guard.canActivate(context as any)).toBe(true);
  });

  it('allows matching role', () => {
    const { guard, context } = ctx(['admin'], ['admin', 'super_admin']);
    expect(guard.canActivate(context as any)).toBe(true);
  });

  it('forbids non-matching role', () => {
    const { guard, context } = ctx(['member'], ['admin']);
    expect(() => guard.canActivate(context as any)).toThrow(ForbiddenException);
  });
});
