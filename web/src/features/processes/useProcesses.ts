import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useApi } from '../../api/context';
import type { ProcessQuery } from '../../lib/url-state';

// One page of processes, filtered, sorted and paged by the API (FR-011). It refreshes every 15 s
// unless paused; the previous page stays on screen while the next one loads, and a process that ended
// in between simply disappears (US3 scenario 3).

export const REFRESH_MS = 15_000;

export function useProcesses(query: ProcessQuery) {
  const api = useApi();
  const [paused, setPaused] = useState(false);
  const params = {
    namespace: query.namespace || undefined,
    user: query.user || undefined,
    state: query.state || undefined,
    q: query.q || undefined,
    sort: query.sort,
    page: query.page,
    pageSize: query.pageSize,
  };
  const result = useQuery({
    queryKey: ['processes', params],
    queryFn: () => api.processes(params),
    refetchInterval: paused ? false : REFRESH_MS,
    refetchIntervalInBackground: false,
    placeholderData: keepPreviousData,
    retry: false,
  });
  return { ...result, paused, setPaused };
}
