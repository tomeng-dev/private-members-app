import { stripScripts } from './sanitize.policy';

describe('stripScripts', () => {
  it('removes script tags', () => {
    expect(stripScripts('Hello <script>alert(1)</script> world')).toBe(
      'Hello  world',
    );
  });
  it('handles null', () => {
    expect(stripScripts(null)).toBeUndefined();
  });
});
