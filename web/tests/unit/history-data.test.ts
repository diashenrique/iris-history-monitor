import { fetchHistory, MAX_PAGES, PAGE_LIMIT } from '../../src/features/history/useHistory';
import type { HistorySeries } from '../../src/api/types';
import { fakeApi, fixture } from '../support/fake-api';

// Complete series (FR-009, research R8): limit 5000, follow `next` until complete, at most 20 pages.

const range = { from: '2026-10-01T00:00:00Z', to: '2026-10-08T00:00:00Z' };

describe('fetchHistory', () => {
  it('asks for 5000 points per page and follows next until the series is complete', async () => {
    const history = vi
      .fn()
      .mockResolvedValueOnce(fixture('history-hourly-truncated'))
      .mockResolvedValueOnce(fixture('history-hourly-page2'));
    const api = fakeApi({ history });
    const r = await fetchHistory(api, 'license', 'hourly', range);
    expect(PAGE_LIMIT).toBe(5000);
    expect(history).toHaveBeenCalledTimes(2);
    expect(history.mock.calls[0]).toEqual(['license', { granularity: 'hourly', ...range, limit: 5000 }]);
    expect(history.mock.calls[1]?.[1]).toMatchObject({ cursor: '2026-10-03T02:00:00Z' });
    expect(r.complete).toBe(true);
    expect(r.series.map((s) => s.name)).toEqual(['Avg', 'Max']);
    expect(r.series[0]!.points.map((p) => p.t)).toEqual([
      '2026-10-03T00:00:00Z',
      '2026-10-03T01:00:00Z',
      '2026-10-03T02:00:00Z',
      '2026-10-03T03:00:00Z',
      '2026-10-03T04:00:00Z',
    ]);
  });

  it('keeps the coverage and partial flag of the first page', async () => {
    const api = fakeApi({
      history: vi
        .fn()
        .mockResolvedValueOnce(fixture('history-hourly-truncated'))
        .mockResolvedValueOnce(fixture('history-hourly-page2')),
    });
    const r = await fetchHistory(api, 'license', 'hourly', range);
    expect(r.partial).toBe(true);
    expect(r.coverage).toEqual({ first: '2026-10-03T00:00:00Z', last: '2026-10-07T23:00:00Z' });
  });

  it('stops after 20 pages, says the series is incomplete and can continue from where it stopped', async () => {
    const page = fixture<HistorySeries>('history-hourly-truncated');
    const history = vi.fn(async () => page);
    const r = await fetchHistory(fakeApi({ history }), 'license', 'hourly', range);
    expect(MAX_PAGES).toBe(20);
    expect(history).toHaveBeenCalledTimes(20);
    expect(r.complete).toBe(false);
    expect(r.next).toBe(page.next);
  });

  it('starts from a cursor to load more', async () => {
    const history = vi.fn(async (_metric: string, _params: Record<string, unknown>) => fixture('history-hourly-page2'));
    const r = await fetchHistory(fakeApi({ history }), 'license', 'hourly', range, '2026-10-03T02:00:00Z');
    expect(history.mock.calls[0]?.[1]).toMatchObject({ cursor: '2026-10-03T02:00:00Z' });
    expect(r.complete).toBe(true);
  });

  it('an empty period gives no series and no coverage', async () => {
    const r = await fetchHistory(fakeApi({ history: vi.fn(async () => fixture('history-empty')) }), 'csp-sessions', 'daily', range);
    expect(r.series).toEqual([]);
    expect(r.coverage).toBeNull();
  });
});
