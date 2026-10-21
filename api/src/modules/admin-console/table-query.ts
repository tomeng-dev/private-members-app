/** Pure helpers for server-side table queries (unit tested). */
export type SortOrder = 'asc' | 'desc';

export interface TableQueryInput {
  page?: string | number;
  pageSize?: string | number;
  sort?: string;
  order?: string;
  q?: string;
}

export interface NormalizedTableQuery {
  page: number;
  pageSize: number;
  skip: number;
  take: number;
  sort: string;
  order: SortOrder;
  q: string | null;
}

export function normalizeTableQuery(
  input: TableQueryInput,
  allowedSorts: readonly string[],
  defaultSort: string,
  defaultOrder: SortOrder = 'desc',
): NormalizedTableQuery {
  const page = Math.max(1, Math.floor(Number(input.page) || 1));
  const pageSize = Math.min(
    100,
    Math.max(5, Math.floor(Number(input.pageSize) || 20)),
  );
  const sort =
    input.sort && allowedSorts.includes(input.sort) ? input.sort : defaultSort;
  const order: SortOrder =
    input.order === 'asc' || input.order === 'desc'
      ? input.order
      : defaultOrder;
  const q = (input.q ?? '').trim().slice(0, 100) || null;
  return {
    page,
    pageSize,
    skip: (page - 1) * pageSize,
    take: pageSize,
    sort,
    order,
    q,
  };
}

export function paged<T>(items: T[], total: number, q: NormalizedTableQuery) {
  return {
    items,
    total,
    page: q.page,
    pageSize: q.pageSize,
    pageCount: Math.max(1, Math.ceil(total / q.pageSize)),
    sort: q.sort,
    order: q.order,
  };
}

/** Monday-based ISO week start (UTC) for bucketing chart data. */
export function weekStart(d: Date): string {
  const x = new Date(
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
  );
  const day = (x.getUTCDay() + 6) % 7;
  x.setUTCDate(x.getUTCDate() - day);
  return x.toISOString().slice(0, 10);
}

export function bucketByWeek(dates: Date[], weeks: number, now = new Date()) {
  const buckets: { week: string; count: number }[] = [];
  const start = new Date(weekStart(now) + 'T00:00:00Z');
  for (let i = weeks - 1; i >= 0; i--) {
    const w = new Date(start.getTime() - i * 7 * 86400000);
    buckets.push({ week: w.toISOString().slice(0, 10), count: 0 });
  }
  const idx = new Map(buckets.map((b, i) => [b.week, i]));
  for (const d of dates) {
    const i = idx.get(weekStart(d));
    if (i !== undefined) buckets[i].count++;
  }
  return buckets;
}

export function toCsv(
  rows: Record<string, unknown>[],
  columns: string[],
): string {
  const esc = (v: unknown) => {
    if (v === null || v === undefined) return '';
    let s = v instanceof Date ? v.toISOString() : String(v);
    // CSV injection guard for spreadsheet apps
    if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
    return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [
    columns.join(','),
    ...rows.map((r) => columns.map((c) => esc(r[c])).join(',')),
  ].join('\n');
}
