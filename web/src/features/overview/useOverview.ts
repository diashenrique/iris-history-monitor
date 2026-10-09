import { useQuery } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { useApi } from '../../api/context';
import type { OverviewSnapshot } from '../../api/types';

// Live Overview (FR-005, FR-006, research R7): refresh every 10 s unless paused or the tab is hidden;
// a failed refresh keeps the last figures and marks them out of date; numeric metrics keep a trend of
// their last 60 values in memory only.

export const REFRESH_MS = 10_000;
export const TREND_SIZE = 60;

export type Trend = Record<string, number[]>;

/** Adds the numeric values of a snapshot to the trend, keeping the last TREND_SIZE of each. */
export function pushTrend(trend: Trend, snapshot: OverviewSnapshot): Trend {
  const next: Trend = { ...trend };
  for (const m of snapshot.metrics) {
    if (typeof m.value !== 'number') continue;
    next[m.name] = [...(trend[m.name] ?? []), m.value].slice(-TREND_SIZE);
  }
  return next;
}

export function useOverview() {
  const api = useApi();
  const [paused, setPaused] = useState(false);
  const query = useQuery({
    queryKey: ['overview'],
    queryFn: () => api.overview(),
    refetchInterval: paused ? false : REFRESH_MS,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: !paused,
    retry: false,
  });

  const [trend, setTrend] = useState<Trend>({});
  const seen = useRef(0);
  useEffect(() => {
    if (query.data && query.dataUpdatedAt !== seen.current) {
      seen.current = query.dataUpdatedAt;
      setTrend((t) => pushTrend(t, query.data));
    }
  }, [query.data, query.dataUpdatedAt]);

  return {
    snapshot: query.data,
    lastSuccessAt: query.dataUpdatedAt ? new Date(query.dataUpdatedAt) : null,
    stale: query.isError && !!query.data,
    failedFirst: query.isError && !query.data,
    error: query.error,
    retry: () => void query.refetch(),
    paused,
    setPaused,
    trend,
  };
}
