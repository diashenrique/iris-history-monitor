import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router';
import { ApiProvider } from '../../src/api/context';
import type { HistorySeries } from '../../src/api/types';
import { HistoryPage } from '../../src/features/history/HistoryPage';
import { HistoryTable } from '../../src/features/history/HistoryTable';
import { expectNoSeriousAxeIssues } from '../axe';
import '../i18n-test';
import { fakeApi, fixture, testQueryClient } from '../support/fake-api';

// What the history screen shows (FR-008, FR-010, FR-018, spec edge cases).

const chartProps: { series: { name: string; points: { t: string }[] }[] }[] = [];
vi.mock('../../src/features/history/HistoryChart', () => ({
  default: (props: { series: { name: string; points: { t: string }[] }[] }) => {
    chartProps.push(props);
    return <div data-testid="chart" />;
  },
}));

function renderPage(search: string, history: ReturnType<typeof vi.fn>) {
  return render(
    <QueryClientProvider client={testQueryClient()}>
      <ApiProvider client={fakeApi({ history })}>
        <MemoryRouter initialEntries={[`/history${search}`]}>
          <HistoryPage />
        </MemoryRouter>
      </ApiProvider>
    </QueryClientProvider>,
  );
}

beforeEach(() => {
  chartProps.length = 0;
});

describe('history view', () => {
  it('chart and table show the same points', async () => {
    const data = fixture<HistorySeries>('history-database');
    renderPage('?metric=database-size&granularity=daily&preset=7d', vi.fn(async () => data));
    const table = await screen.findByRole('table');
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows).toHaveLength(3);
    const last = chartProps.at(-1)!;
    expect(last.series.map((s) => s.name)).toEqual(['IRISLIB', 'USER']);
    expect(last.series[1]!.points).toHaveLength(3);
    expect(rows[0]).toHaveTextContent('285');
    expect(rows[0]).toHaveTextContent('1,010');
  });

  it('names the time zone of the times', async () => {
    renderPage('?metric=database-size&granularity=daily', vi.fn(async () => fixture('history-database')));
    const table = await screen.findByRole('table');
    expect(within(table).getAllByRole('columnheader')[0]).toHaveTextContent(/^Time \(.+\)$/);
  });

  it('states the period actually covered when it is shorter than the one asked', async () => {
    renderPage(
      '?metric=license&granularity=hourly',
      vi.fn().mockResolvedValueOnce(fixture('history-hourly-truncated')).mockResolvedValueOnce(fixture('history-hourly-page2')),
    );
    expect(await screen.findByText(/keeps data for part of the period only/)).toBeInTheDocument();
  });

  it('says there is no data for an empty period', async () => {
    renderPage('?metric=csp-sessions&granularity=daily', vi.fn(async () => fixture('history-empty')));
    expect(await screen.findByText('No data for this period.')).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });

  it('lets the user choose which databases to show', async () => {
    renderPage('?metric=database-size&granularity=daily', vi.fn(async () => fixture('history-database')));
    const user = await screen.findByRole('checkbox', { name: 'USER' });
    await userEvent.click(user);
    expect(chartProps.at(-1)!.series.map((s) => s.name)).toEqual(['USER']);
    expect(within(screen.getByRole('table')).getAllByRole('columnheader')).toHaveLength(2);
  });

  it('offers to load more when the series stopped at the page limit', async () => {
    const page = fixture<HistorySeries>('history-hourly-truncated');
    renderPage('?metric=license&granularity=hourly', vi.fn(async () => page));
    expect(await screen.findByRole('button', { name: 'Load more' })).toBeInTheDocument();
    expect(screen.getByText(/the period has more/)).toBeInTheDocument();
  });

  it('has no serious accessibility issue', async () => {
    const { container } = renderPage('?metric=database-size&granularity=daily', vi.fn(async () => fixture('history-database')));
    await screen.findByRole('table');
    await expectNoSeriousAxeIssues(container);
  });
});

describe('history table across a daylight-saving change (spec edge cases)', () => {
  it('keeps the points in order and shows no time twice', () => {
    const data = fixture<HistorySeries>('history-dst');
    render(<HistoryTable series={data.series} timeZone="America/New_York" />);
    const cells = screen.getAllByRole('rowheader').map((c) => c.textContent ?? '');
    expect(cells).toHaveLength(6);
    expect(new Set(cells).size).toBe(6);
    const values = screen.getAllByRole('cell').map((c) => Number(c.textContent));
    expect(values).toEqual([3, 4, 5, 6, 7, 8]);
  });
});
