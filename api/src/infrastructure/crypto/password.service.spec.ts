import { PasswordService } from './password.service';

describe('PasswordService (argon2id)', () => {
  const svc = new PasswordService();

  it('hashes and verifies a password', async () => {
    const hashed = await svc.hash('SecurePass1!');
    expect(hashed).not.toContain('SecurePass1!');
    expect(await svc.verify(hashed, 'SecurePass1!')).toBe(true);
    expect(await svc.verify(hashed, 'wrong')).toBe(false);
  });
});
