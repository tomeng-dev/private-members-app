import { BadRequestException } from '@nestjs/common';
import { lookup } from 'dns/promises';
import { isIP } from 'net';
import { URL } from 'url';

export type LinkPreview = {
  url: string;
  title?: string;
  description?: string;
  imageUrl?: string;
};

const BLOCKED_HOSTS = new Set(['localhost', 'metadata.google.internal']);

function isPrivateIp(ip: string): boolean {
  if (
    ip === '::1' ||
    ip.startsWith('fc') ||
    ip.startsWith('fd') ||
    ip.startsWith('fe80')
  ) {
    return true;
  }
  const parts = ip.split('.').map(Number);
  if (parts.length !== 4 || parts.some((n) => Number.isNaN(n))) return false;
  const [a, b] = parts;
  if (a === 10 || a === 127 || a === 0) return true;
  if (a === 169 && b === 254) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  return false;
}

/** Validate URL scheme + resolve DNS; reject private/link-local destinations (SSRF). */
export async function assertSafePublicHttpUrl(raw: string): Promise<URL> {
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    throw new BadRequestException('Invalid link URL');
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new BadRequestException('Only http/https links are allowed');
  }
  if (parsed.username || parsed.password) {
    throw new BadRequestException('Credentials in URLs are not allowed');
  }
  const host = parsed.hostname.toLowerCase();
  if (
    BLOCKED_HOSTS.has(host) ||
    host.endsWith('.local') ||
    host.endsWith('.internal')
  ) {
    throw new BadRequestException('Link host is not allowed');
  }
  if (isIP(host)) {
    if (isPrivateIp(host)) {
      throw new BadRequestException('Link host is not allowed');
    }
  } else {
    const records = await lookup(host, { all: true });
    if (!records.length)
      throw new BadRequestException('Link host could not be resolved');
    for (const r of records) {
      if (isPrivateIp(r.address)) {
        throw new BadRequestException(
          'Link host resolves to a private address',
        );
      }
    }
  }
  return parsed;
}

export async function fetchLinkPreview(raw: string): Promise<LinkPreview> {
  const url = await assertSafePublicHttpUrl(raw);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 4000);
  try {
    const res = await fetch(url.toString(), {
      method: 'GET',
      redirect: 'error', // no open redirect chain into private IPs
      signal: controller.signal,
      headers: {
        'User-Agent': 'PrivateMembersBot/1.0 (+link-preview)',
        Accept: 'text/html,application/xhtml+xml',
      },
    });
    if (!res.ok) {
      return { url: url.toString(), title: url.hostname };
    }
    const ctype = res.headers.get('content-type') ?? '';
    if (!ctype.includes('text/html') && !ctype.includes('xhtml')) {
      return { url: url.toString(), title: url.hostname };
    }
    const text = (await res.text()).slice(0, 200_000);
    const title =
      matchMeta(text, 'og:title') || matchTag(text, 'title') || url.hostname;
    const description =
      matchMeta(text, 'og:description') || matchMeta(text, 'description');
    let imageUrl = matchMeta(text, 'og:image');
    if (imageUrl) {
      try {
        imageUrl = new URL(imageUrl, url).toString();
        if (
          !imageUrl.startsWith('https://') &&
          !imageUrl.startsWith('http://')
        ) {
          imageUrl = undefined;
        }
      } catch {
        imageUrl = undefined;
      }
    }
    return {
      url: url.toString(),
      title: title?.slice(0, 500),
      description: description?.slice(0, 1000),
      imageUrl: imageUrl?.slice(0, 1000),
    };
  } catch {
    return { url: url.toString(), title: url.hostname };
  } finally {
    clearTimeout(timer);
  }
}

function matchMeta(html: string, name: string): string | undefined {
  const re = new RegExp(
    `<meta[^>]+(?:property|name)=["']${name}["'][^>]+content=["']([^"']+)["']`,
    'i',
  );
  const re2 = new RegExp(
    `<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${name}["']`,
    'i',
  );
  return html.match(re)?.[1] || html.match(re2)?.[1];
}

function matchTag(html: string, tag: string): string | undefined {
  const m = html.match(new RegExp(`<${tag}[^>]*>([^<]+)</${tag}>`, 'i'));
  return m?.[1]?.trim();
}
