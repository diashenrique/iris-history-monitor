import { fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, useLocation } from 'react-router';
import { ApiProvider } from '../../src/api/context';
import { HistoryPage } from '../../src/features/history/HistoryPage';
import '../i18n-test';
import { fakeApi, testQueryClient } from '../support/fake-api';

// The history form and the address (FR-007, FR-013, contracts/ui-routes.md).

vi.mock('../../src/features/history/HistoryChart', () => ({
  default: ({ series }: { series: { name: string }[] }) => <div data-testid="chart">{series.map((s) => s.name).join(',')}</div>,
}));

function Location() {
  const location = useLocation();
  return <output data-testid="location">{location.search}</output>;
}

function renderPage(search = '', api = fakeApi()) {
  render(
    <QueryClientProvider client={testQueryClient()}>
      <ApiProvider client={api}>
        <MemoryRouter initialEntries={[`/history${search}`]}>
          <HistoryPage />
          <Location />
        </MemoryRouter>
      </ApiProvider>
    </QueryClientProvider>,
  );
  return api;
}

const search = () => new URLSearchParams(screen.getByTestId('location').textContent ?? '');

describe('history form', () => {
  it('starts from the defaults: license, hourly, last 7 days', async () => {
    const api = renderPage();
    expect(await screen.findByLabelText('Metric')).toHaveValue('license');
    expect(screen.getByLabelText('Granularity')).toHaveValue('hourly');
    expect(screen.getByLabelText('Period')).toHaveValue('7d');
    expect(api.history).toHaveBeenCalled();
    expect(api.history.mock.calls[0]?.[0]).toBe('license');
    expect(api.history.mock.calls[0]?.[1]).toMatchObject({ granularity: 'hourly', limit: 5000 });
  });

  it('offers the four presets and a custom range', async () => {
    renderPage();
    const period = await screen.findByLabelText('Period');
    const values = [...(period as HTMLSelectElement).options].map((o) => o.value);
    expect(values).toEqual(['24h', '7d', '30d', '90d', 'custom']);
  });

  it('writes every choice to the address', async () => {
    renderPage();
    await userEvent.selectOptions(await screen.findByLabelText('Metric'), 'csp-sessions');
    await userEvent.selectOptions(screen.getByLabelText('Granularity'), 'daily');
    await userEvent.selectOptions(screen.getByLabelText('Period'), '90d');
    expect(search().get('metric')).toBe('csp-sessions');
    expect(search().get('granularity')).toBe('daily');
    expect(search().get('preset')).toBe('90d');
  });

  it('a custom range is entered in local time and sent in UTC', async () => {
    const api = renderPage();
    await userEvent.selectOptions(await screen.findByLabelText('Period'), 'custom');
    const from = screen.getByLabelText('From');
    const to = screen.getByLabelText('To');
    // jsdom does not type into datetime-local inputs, so the value is set as the browser would.
    fireEvent.change(from, { target: { value: '2026-10-01T08:00' } });
    fireEvent.change(to, { target: { value: '2026-10-02T08:00' } });
    const expectedFrom = new Date('2026-10-01T08:00').toISOString().replace(/\.\d{3}Z$/, 'Z');
    expect(search().get('from')).toBe(expectedFrom);
    const last = api.history.mock.calls.at(-1)?.[1] as Record<string, string>;
    expect(last.from).toBe(expectedFrom);
  });

  it('restores a view from the address', async () => {
    renderPage('?metric=database-size&granularity=daily&preset=30d&db=USER');
    expect(await screen.findByLabelText('Metric')).toHaveValue('database-size');
    expect(screen.getByLabelText('Granularity')).toHaveValue('daily');
    expect(screen.getByLabelText('Period')).toHaveValue('30d');
    expect(await screen.findByRole('checkbox', { name: 'USER' })).toBeChecked();
  });

  it('replaces invalid address values with the defaults and says so', async () => {
    renderPage('?metric=cpu&granularity=weekly');
    expect(await screen.findByLabelText('Metric')).toHaveValue('license');
    expect(await screen.findByText(/were not valid/)).toHaveTextContent('metric, granularity');
  });

  it('shows the database choice only for database size', async () => {
    renderPage('?metric=license');
    await screen.findByLabelText('Metric');
    expect(screen.queryByRole('group', { name: 'Databases' })).not.toBeInTheDocument();
  });
});
