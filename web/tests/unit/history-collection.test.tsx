import { render, screen, within } from '@testing-library/react';
import { QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router';
import { ApiProvider } from '../../src/api/context';
import type { HistoryCollection } from '../../src/api/types';
import i18n from '../../src/i18n';
import { HistoryPage } from '../../src/features/history/HistoryPage';
import { expectNoSeriousAxeIssues } from '../axe';
import '../i18n-test';
import { fakeApi, fixture, testQueryClient } from '../support/fake-api';

// Spec 004 user stories 1 and 2: History says whether the instance records history (FR-004, SC-001) and
// how long it keeps each granularity (FR-005).

vi.mock('../../src/features/history/HistoryChart', () => ({ default: () => <div data-testid="chart" /> }));

const README = 'https://github.com/diashenrique/iris-history-monitor#turning-on-history-collection';

function renderPage(collection: HistoryCollection, history = fixture('history-database'), search = '?metric=license&granularity=hourly&preset=7d') {
  const api = fakeApi({ historyCollection: vi.fn(async () => collection), history: vi.fn(async () => history) });
  return render(
    <QueryClientProvider client={testQueryClient()}>
      <ApiProvider client={api}>
        <MemoryRouter initialEntries={[`/history${search}`]}>
          <HistoryPage />
        </MemoryRouter>
      </ApiProvider>
    </QueryClientProvider>,
  );
}

const off = () => fixture<HistoryCollection>('collection-off');
const stale = () => fixture<HistoryCollection>('collection-stale');
const recording = () => fixture<HistoryCollection>('collection-recording');

afterEach(async () => {
  await i18n.changeLanguage('en');
});

describe('history collection notice', () => {
  it('off with no data: the notice replaces the empty chart, with the administrator steps (SC-001)', async () => {
    const { container } = renderPage(off(), fixture('history-empty'));
    const notice = await screen.findByRole('status', { name: /history is not being recorded/i });
    expect(within(notice).getByRole('link', { name: /turn on history collection/i })).toHaveAttribute('href', README);
    expect(notice).toHaveTextContent(/administrator/i);
    expect(screen.queryByText('No data for this period.')).not.toBeInTheDocument();
    expect(screen.queryByTestId('chart')).not.toBeInTheDocument();
    await expectNoSeriousAxeIssues(container);
  });

  it('off with older data: the chart stays, with a notice naming the last sample', async () => {
    renderPage({ ...off(), lastSample: '2026-10-08T23:55:00Z' });
    const notice = await screen.findByRole('status', { name: /recording has stopped/i });
    expect(notice).toHaveTextContent(/last sample/i);
    expect(notice).toHaveTextContent(/2026/);
    expect(await screen.findByTestId('chart')).toBeInTheDocument();
  });

  it('stale with the collector not running: names the likely cause', async () => {
    renderPage(stale());
    const notice = await screen.findByRole('status', { name: /recording has stopped/i });
    expect(notice).toHaveTextContent(/collector is not running/i);
  });

  it('recording: no notice', async () => {
    renderPage(recording());
    expect(await screen.findByTestId('chart')).toBeInTheDocument();
    expect(screen.queryByRole('status', { name: /not being recorded|recording has stopped/i })).not.toBeInTheDocument();
  });

  it('is translated', async () => {
    await i18n.changeLanguage('pt-BR');
    renderPage(off(), fixture('history-empty'));
    expect(await screen.findByRole('status', { name: /histórico não está sendo gravado/i })).toBeInTheDocument();
    await i18n.changeLanguage('es');
    renderPage(stale());
    expect((await screen.findAllByRole('status', { name: /grabación del historial se detuvo/i })).length).toBeGreaterThan(0);
  });
});

describe('retention limits (US2)', () => {
  it('shows how long the chosen granularity is kept, next to the choice', async () => {
    renderPage(recording(), fixture('history-database'), '?metric=license&granularity=5min&preset=24h');
    const select = await screen.findByLabelText('Granularity');
    const help = document.getElementById(select.getAttribute('aria-describedby') ?? '');
    await vi.waitFor(() => expect(help).toHaveTextContent('Kept: last 7 days'));
  });

  it('daily is kept indefinitely; an unknown limit shows nothing', async () => {
    renderPage(stale(), fixture('history-database'), '?metric=license&granularity=daily&preset=30d');
    expect(await screen.findByText('Kept: indefinitely')).toBeInTheDocument();
  });

  it('the partial notice names the retention limit when the period starts before it', async () => {
    renderPage(recording(), fixture('history-hourly-truncated'), '?metric=license&granularity=5min&preset=30d');
    expect(await screen.findByText(/keeps 5-minute detail for 7 days/i)).toBeInTheDocument();
  });
});
