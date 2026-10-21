import { canGrantFoundingMember } from './founding.policy';

describe('canGrantFoundingMember', () => {
  it('grants while under cap by default', () => {
    expect(canGrantFoundingMember(0, 20, undefined)).toBe(true);
    expect(canGrantFoundingMember(19, 20, true)).toBe(true);
  });
  it('stops at cap', () => {
    expect(canGrantFoundingMember(20, 20, true)).toBe(false);
  });
  it('honors explicit false', () => {
    expect(canGrantFoundingMember(5, 20, false)).toBe(false);
  });
});
