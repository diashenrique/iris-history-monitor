import { useQuery } from '@tanstack/react-query';
import { useCallback, useState } from 'react';
import type { ApiClient } from '../../api/client';
import { useApi } from '../../api/context';
import type { Granularity, HistoryMetric, Series } from '../../api/types';

// A complete series for the chosen period (FR-009, research R8): ask for 5000 timestamps per page and
// follow `next` until the series is complete, at most 20 pages per load; past that the screen says the
// series is incomplete and can load more from where it stopped.

export const PAGE_LIMIT = 5000;
export const MAX_PAGES = 20;

export interface HistoryResult {
  series: Series[];
  coverage: { first: string; last: string } | null;
  partial: boolean;
  complete: boolean;
  next?: string;
}

function merge(into: Map<string, Series>, series: Series[]) {
  for (const s of series) {
    const existing = into.get(s.name);
    if (existing) existing.points.push(...s.points);
    else into.set(s.name, { name: s.name, points: [...s.points] });
  }
}

export async function fetchHistory(
  api: ApiClient,
  metric: HistoryMetric,
  granularity: Granularity,
  range: { from: string; to: string },
  cursor?: string,
): Promise<HistoryResult> {
  const series = new Map<string, Series>();
  let coverage: HistoryResult['coverage'] = null;
  let partial = false;
  let next = cursor;
  let first = true;
  for (let page = 0; page < MAX_PAGES; page++) {
    const params: Record<string, string | number> = { granularity, ...range, limit: PAGE_LIMIT };
    if (next) params.cursor = next;
    const r = await api.history(metric, params);
    if (first) {
      coverage = r.coverage;
      partial = r.partial;
      first = false;
    }
    merge(series, r.series);
    next = r.truncated ? r.next : undefined;
    if (!next) break;
  }
  for (const s of series.values()) s.points.sort((a, b) => (a.t < b.t ? -1 : a.t > b.t ? 1 : 0));
  return { series: [...series.values()], coverage, partial, complete: !next, next };
}

/** Joins a "load more" result onto what is already shown. */
export function appendHistory(base: HistoryResult, more: HistoryResult): HistoryResult {
  const series = new Map(base.series.map((s) => [s.name, { name: s.name, points: [...s.points] }]));
  merge(series, more.series);
  return { ...base, series: [...series.values()], complete: more.complete, next: more.next };
}

export function useHistory(metric: HistoryMetric, granularity: Granularity, range: { from: string; to: string }) {
  const api = useApi();
  const query = useQuery({
    queryKey: ['history', metric, granularity, range.from, range.to],
    queryFn: () => fetchHistory(api, metric, granularity, range),
    staleTime: 60_000,
  });
  const [extra, setExtra] = useState<{ key: string; result: HistoryResult } | null>(null);
  const key = `${metric}|${granularity}|${range.from}|${range.to}|${query.dataUpdatedAt}`;
  const result = extra && extra.key === key ? extra.result : query.data;
  const [loadingMore, setLoadingMore] = useState(false);

  const loadMore = useCallback(async () => {
    if (!result?.next) return;
    setLoadingMore(true);
    try {
      const more = await fetchHistory(api, metric, granularity, range, result.next);
      setExtra({ key, result: appendHistory(result, more) });
    } finally {
      setLoadingMore(false);
    }
  }, [api, metric, granularity, range, result, key]);

  return { result, isPending: query.isPending, error: query.error, retry: () => void query.refetch(), loadMore, loadingMore };
}
