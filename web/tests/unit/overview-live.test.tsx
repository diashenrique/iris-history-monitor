import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { focusManager, QueryClientProvider } from '@tanstack/react-query';
import { ApiProvider } from '../../src/api/context';
import { OverviewPage } from '../../src/features/overview/OverviewPage';
import { pushTrend, REFRESH_MS, TREND_SIZE } from '../../src/features/overview/useOverview';
import type { OverviewSnapshot } from '../../src/api/types';
import '../i18n-test';
import { fakeApi, fixture, networkDown, testQueryClient } from '../support/fake-api';

// Live behaviour of the Overview (FR-005, FR-006, research R7).

function renderOverview(api = fakeApi()) {
  render(
    <QueryClientProvider client={testQueryClient()}>
      <ApiProvider client={api}>
        <OverviewPage />
      </ApiProvider>
    </QueryClientProvider>,
  );
  return api;
}

async function advance(ms: number) {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(ms);
  });
}

beforeEach(() => {
  vi.useFakeTimers({ shouldAdvanceTime: true });
  focusManager.setFocused(true);
});
afterEach(() => {
  focusManager.setFocused(undefined);
  vi.useRealTimers();
});

describe('Overview live updates', () => {
  it('refreshes every 10 seconds', async () => {
    const api = renderOverview();
    await screen.findByRole('list', { name: 'Needs attention' });
    expect(REFRESH_MS).toBe(10_000);
    const before = api.overview.mock.calls.length;
    await advance(REFRESH_MS + 50);
    expect(api.overview.mock.calls.length).toBe(before + 1);
  });

  it('pause stops the refresh and resume restarts it', async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    const api = renderOverview();
    await screen.findByRole('list', { name: 'Needs attention' });
    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(screen.getByRole('button', { name: 'Resume' })).toHaveAttribute('aria-pressed', 'true');
    const paused = api.overview.mock.calls.length;
    await advance(REFRESH_MS * 3);
    expect(api.overview.mock.calls.length).toBe(paused);
    await user.click(screen.getByRole('button', { name: 'Resume' }));
    await advance(REFRESH_MS + 50);
    expect(api.overview.mock.calls.length).toBeGreaterThan(paused);
  });

  it('stops refreshing while the browser tab is hidden', async () => {
    const api = renderOverview();
    await screen.findByRole('list', { name: 'Needs attention' });
    act(() => focusManager.setFocused(false));
    const hidden = api.overview.mock.calls.length;
    await advance(REFRESH_MS * 3);
    expect(api.overview.mock.calls.length).toBe(hidden);
  });

  it('a failed refresh keeps the figures, marks them out of date, and the next success clears it', async () => {
    const overview = vi
      .fn()
      .mockResolvedValueOnce(fixture('overview'))
      .mockRejectedValueOnce(networkDown())
      .mockResolvedValue(fixture('overview-healthy'));
    renderOverview(fakeApi({ overview }));
    await screen.findByRole('list', { name: 'Needs attention' });
    await advance(REFRESH_MS + 50);
    expect(await screen.findByText('Figures out of date.')).toBeInTheDocument();
    expect(screen.getByRole('list', { name: 'Needs attention' })).toBeInTheDocument();
    await advance(REFRESH_MS + 50);
    expect(await screen.findByText('Every metric is healthy.')).toBeInTheDocument();
    expect(screen.queryByText('Figures out of date.')).not.toBeInTheDocument();
  });

  it('shows the time of the last successful update', async () => {
    renderOverview();
    await screen.findByRole('list', { name: 'Needs attention' });
    expect(screen.getByText('Updated').parentElement?.querySelector('time')).toHaveAttribute('dateTime');
  });
});

describe('trend buffer', () => {
  const snap = (v: number): OverviewSnapshot => ({
    generatedAt: '2026-10-09T17:00:00Z',
    metrics: [
      { name: 'processes', value: v, unit: 'count', status: 'ok' },
      { name: 'lockTable', value: 'Normal', unit: 'text', status: 'ok' },
      { name: 'cspSessions', value: null, unit: 'count', status: 'unavailable', reason: 'x' },
    ],
  });

  it('keeps numeric values only, at most the last 60', () => {
    expect(TREND_SIZE).toBe(60);
    let trend: Record<string, number[]> = {};
    for (let i = 1; i <= 65; i++) trend = pushTrend(trend, snap(i));
    expect(trend.processes).toHaveLength(60);
    expect(trend.processes?.[0]).toBe(6);
    expect(trend.processes?.at(-1)).toBe(65);
    expect(trend.lockTable).toBeUndefined();
    expect(trend.cspSessions).toBeUndefined();
  });
});
