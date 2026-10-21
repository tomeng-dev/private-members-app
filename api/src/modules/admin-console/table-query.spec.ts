import { describe, expect, it } from 'vitest';
import { bucketByWeek, normalizeTableQuery, paged, toCsv, weekStart } from './table-query';

describe('table query helpers', () => {
  it('clamps page and pageSize and whitelists sort', () => {
    const q = normalizeTableQuery({ page: '-3', pageSize: '1000', sort: 'passwordHash', order: 'x' }, ['createdAt', 'email'], 'createdAt');
    expect(q).toMatchObject({ page: 1, pageSize: 100, sort: 'createdAt', order: 'desc', skip: 0 });
  });
  it('computes skip and keeps allowed sort', () => {
    const q = normalizeTableQuery({ page: 3, pageSize: 10, sort: 'email', order: 'asc', q: '  bob ' }, ['email'], 'email');
    expect(q).toMatchObject({ skip: 20, take: 10, sort: 'email', order: 'asc', q: 'bob' });
  });
  it('pages', () => {
    const q = normalizeTableQuery({ pageSize: 10 }, [], 'createdAt');
    expect(paged([1, 2], 21, q).pageCount).toBe(3);
  });
  it('buckets by monday week', () => {
    expect(weekStart(new Date('2026-10-21T10:00:00Z'))).toBe('2026-10-19');
    const b = bucketByWeek([new Date('2026-10-20T00:00:00Z'), new Date('2026-10-12T00:00:00Z'), new Date('2025-01-01')], 3, new Date('2026-10-21T00:00:00Z'));
    expect(b.map((x) => x.count)).toEqual([0, 1, 1]);
  });
  it('escapes CSV and guards formula injection', () => {
    const csv = toCsv([{ a: '=SUM(A1)', b: 'x,"y"' }], ['a', 'b']);
    expect(csv).toBe(`a,b\n'=SUM(A1),"x,""y"""`);
  });
});
