import { describe, expect, it } from 'vitest';
import { assertSafePublicHttpUrl } from './link-preview';

describe('assertSafePublicHttpUrl', () => {
  it('allows https public hostnames (dns may vary)', async () => {
    // example.com is public; if DNS fails in sandbox, still validates scheme
    await expect(assertSafePublicHttpUrl('https://example.com/path')).resolves.toBeTruthy();
  });

  it('rejects non-http schemes', async () => {
    await expect(assertSafePublicHttpUrl('file:///etc/passwd')).rejects.toThrow();
    await expect(assertSafePublicHttpUrl('ftp://example.com')).rejects.toThrow();
  });

  it('rejects localhost and private IPs', async () => {
    await expect(assertSafePublicHttpUrl('http://localhost/x')).rejects.toThrow();
    await expect(assertSafePublicHttpUrl('http://127.0.0.1/x')).rejects.toThrow();
    await expect(assertSafePublicHttpUrl('http://10.0.0.5/x')).rejects.toThrow();
    await expect(assertSafePublicHttpUrl('http://192.168.1.1/x')).rejects.toThrow();
  });
});
