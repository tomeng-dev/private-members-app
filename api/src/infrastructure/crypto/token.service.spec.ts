import { TokenService } from './token.service';

describe('TokenService', () => {
  const svc = new TokenService();

  it('generates opaque tokens and stable hashes', () => {
    const a = svc.generateOpaque();
    const b = svc.generateOpaque();
    expect(a).not.toEqual(b);
    expect(svc.hash(a)).toHaveLength(64);
    expect(svc.hash(a)).toEqual(svc.hash(a));
  });
});
