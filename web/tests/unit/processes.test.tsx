import { act, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { focusManager, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router';
import { ApiProvider } from '../../src/api/context';
import type { ProcessPage } from '../../src/api/types';
import { ProcessesPage, REFRESH_MS } from '../../src/features/processes/ProcessesPage';
import { expectNoSeriousAxeIssues } from '../axe';
import '../i18n-test';
import { fakeApi, fixture, testQueryClient } from '../support/fake-api';

// User story 3 (FR-011, FR-012, FR-013, contracts/ui-routes.md).

function Location() {
  const location = useLocation();
  return <output data-testid="location">{`${location.pathname}${location.search}`}</output>;
}

function renderPage(entry = '/processes', api = fakeApi()) {
  render(
    <QueryClientProvider client={testQueryClient()}>
      <ApiProvider client={api}>
        <MemoryRouter initialEntries={[entry]}>
          <Routes>
            <Route path="/processes" element={<ProcessesPage />} />
            <Route path="/processes/:pid" element={<ProcessesPage />} />
          </Routes>
          <Location />
        </MemoryRouter>
      </ApiProvider>
    </QueryClientProvider>,
  );
  return api;
}

const location = () => screen.getByTestId('location').textContent ?? '';
const lastParams = (api: ReturnType<typeof fakeApi>) => api.processes.mock.calls.at(-1)?.[0] as Record<string, unknown>;

describe('processes', () => {
  it('lists the page with the total and the default sort and page size', async () => {
    const api = renderPage();
    const table = await screen.findByRole('table');
    expect(within(table).getAllByRole('row')).toHaveLength(3);
    expect(screen.getByText(/48 processes/)).toBeInTheDocument();
    expect(lastParams(api)).toMatchObject({ sort: 'job', page: 1, pageSize: 50 });
    expect(screen.getByLabelText('Rows per page')).toHaveValue('50');
    expect([...(screen.getByLabelText('Rows per page') as HTMLSelectElement).options].map((o) => o.value)).toEqual(['25', '50', '100']);
  });

  it('filters by namespace, user, state and text, and keeps them in the address', async () => {
    const api = renderPage();
    await screen.findByRole('table');
    await userEvent.type(screen.getByLabelText('Namespace'), '%SYS');
    await userEvent.type(screen.getByLabelText('User'), 'alice');
    await userEvent.type(screen.getByLabelText('State'), 'READ');
    await userEvent.type(screen.getByLabelText('Search'), 'Orders');
    await userEvent.click(screen.getByRole('button', { name: 'Apply filters' }));
    expect(lastParams(api)).toMatchObject({ namespace: '%SYS', user: 'alice', state: 'READ', q: 'Orders', page: 1 });
    expect(location()).toContain('namespace=%25SYS');
    expect(location()).toContain('q=Orders');
  });

  it('limits the text search to 100 characters', async () => {
    renderPage();
    await screen.findByRole('table');
    expect(screen.getByLabelText('Search')).toHaveAttribute('maxLength', '100');
  });

  it('sorts by a column, then descending, and says so', async () => {
    const api = renderPage();
    await screen.findByRole('table');
    await userEvent.click(screen.getByRole('button', { name: 'CPU time' }));
    expect(lastParams(api)).toMatchObject({ sort: 'cpuTime' });
    expect(screen.getByRole('columnheader', { name: /CPU time/ })).toHaveAttribute('aria-sort', 'ascending');
    await userEvent.click(screen.getByRole('button', { name: 'CPU time' }));
    expect(lastParams(api)).toMatchObject({ sort: '-cpuTime' });
    expect(screen.getByRole('columnheader', { name: /CPU time/ })).toHaveAttribute('aria-sort', 'descending');
  });

  it('pages with next and previous', async () => {
    const api = renderPage();
    await screen.findByRole('table');
    await userEvent.click(screen.getByRole('button', { name: 'Next page' }));
    expect(lastParams(api)).toMatchObject({ page: 2 });
    expect(location()).toContain('page=2');
    await userEvent.selectOptions(screen.getByLabelText('Rows per page'), '25');
    expect(lastParams(api)).toMatchObject({ page: 1, pageSize: 25 });
  });

  it('opens one process with every field it has and none it lacks', async () => {
    renderPage();
    await screen.findByRole('table');
    await userEvent.click(screen.getByRole('button', { name: 'Details of process 4285' }));
    const dialog = await screen.findByRole('dialog', { name: 'Process 4285' });
    expect(within(dialog).getByText('MyApp.Orders.1')).toBeInTheDocument();
    expect(within(dialog).getByText('WS-ALICE')).toBeInTheDocument();
    expect(location()).toBe('/processes/4285');
    await userEvent.keyboard('{Escape}');
    expect(location()).toBe('/processes');
  });

  it('shows a process without a user or device without placeholders', async () => {
    renderPage('/processes/429');
    const dialog = await screen.findByRole('dialog', { name: 'Process 429' });
    expect(within(dialog).queryByText('User')).not.toBeInTheDocument();
    expect(within(dialog).queryByText('Device')).not.toBeInTheDocument();
    expect(within(dialog).getByText('CONTROL')).toBeInTheDocument();
  });

  it('says when an opened process has ended', async () => {
    renderPage('/processes/99999');
    expect(await screen.findByText('This process is no longer running.')).toBeInTheDocument();
  });

  it('exports the shown page as CSV', async () => {
    const created: Blob[] = [];
    const url = vi.spyOn(URL, 'createObjectURL').mockImplementation((b) => {
      created.push(b as Blob);
      return 'blob:x';
    });
    renderPage();
    await screen.findByRole('table');
    await userEvent.click(screen.getByRole('button', { name: 'Export CSV' }));
    const text = await created[0]!.text();
    expect(text.split('\r\n')[0]).toContain('pid');
    expect(text).toContain('4285');
    url.mockRestore();
  });

  it('has no serious accessibility issue', async () => {
    renderPage();
    const table = await screen.findByRole('table');
    await expectNoSeriousAxeIssues(table.closest('div[data-page]')!);
  });
});

describe('processes refresh (FR-011, US3 scenario 3)', () => {
  beforeEach(() => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    focusManager.setFocused(true);
  });
  afterEach(() => {
    focusManager.setFocused(undefined);
    vi.useRealTimers();
  });

  it('refreshes every 15 seconds, can be paused, and a process that ended just disappears', async () => {
    const page = fixture<ProcessPage>('processes-page1');
    const processes = vi
      .fn()
      .mockResolvedValueOnce(page)
      .mockResolvedValue({ ...page, items: page.items.slice(0, 1), total: 47 });
    renderPage('/processes', fakeApi({ processes }));
    await screen.findByRole('table');
    expect(REFRESH_MS).toBe(15_000);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(REFRESH_MS + 50);
    });
    expect(await screen.findByText(/47 processes/)).toBeInTheDocument();
    expect(screen.queryByText('4285')).not.toBeInTheDocument();
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();

    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    await user.click(screen.getByRole('button', { name: 'Pause updates' }));
    const calls = processes.mock.calls.length;
    await act(async () => {
      await vi.advanceTimersByTimeAsync(REFRESH_MS * 3);
    });
    expect(processes.mock.calls.length).toBe(calls);
  });
});
