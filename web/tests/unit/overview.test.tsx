import { render, screen, within } from '@testing-library/react';
import { QueryClientProvider } from '@tanstack/react-query';
import { ApiProvider } from '../../src/api/context';
import { OverviewPage } from '../../src/features/overview/OverviewPage';
import { expectNoSeriousAxeIssues } from '../axe';
import '../i18n-test';
import { fakeApi, fixture, testQueryClient } from '../support/fake-api';

// User story 1 (spec 002): every metric with value, unit and status, non-ok first (FR-003, FR-004).

function renderOverview(api = fakeApi()) {
  return render(
    <QueryClientProvider client={testQueryClient()}>
      <ApiProvider client={api}>
        <OverviewPage />
      </ApiProvider>
    </QueryClientProvider>,
  );
}

function names(list: HTMLElement): string[] {
  return within(list)
    .getAllByRole('listitem')
    .map((li) => li.getAttribute('data-metric') ?? '');
}

describe('Overview', () => {
  it('shows all 18 metrics: the ones needing attention first, then the healthy ones', async () => {
    renderOverview();
    const attention = await screen.findByRole('list', { name: 'Needs attention' });
    const healthy = screen.getAllByRole('list', { name: /^Healthy/ });
    const total = names(attention).length + healthy.reduce((n, l) => n + names(l).length, 0);
    expect(total).toBe(18);
  });

  it('orders attention as critical, unavailable, warning, keeping the API order inside a status', async () => {
    renderOverview();
    const attention = await screen.findByRole('list', { name: 'Needs attention' });
    expect(names(attention)).toEqual(['journalSpace', 'ecpDataServer', 'lastBackup', 'licenseHighPct', 'seriousAlerts']);
  });

  it('shows status as icon and label, the API reason for unavailable, and Never for a missing backup', async () => {
    renderOverview();
    const attention = await screen.findByRole('list', { name: 'Needs attention' });
    const items = within(attention).getAllByRole('listitem');
    expect(within(items[0]!).getByText('Critical')).toBeInTheDocument();
    expect(within(items[1]!).getByText('Unavailable')).toBeInTheDocument();
    expect(within(items[1]!).getByText('not reported by the dashboard sample')).toBeInTheDocument();
    expect(within(items[2]!).getByText('Never')).toBeInTheDocument();
    for (const li of items) expect(li.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
  });

  it('groups healthy metrics by area with values and units', async () => {
    renderOverview();
    const licenses = await screen.findByRole('list', { name: 'Healthy: Licenses' });
    const use = within(licenses).getByText('License use').closest('li')!;
    expect(use).toHaveTextContent('63');
    expect(use).toHaveTextContent('%');
    expect(within(use).getByRole('meter', { name: 'License use' })).toHaveAttribute('aria-valuenow', '63');
  });

  it('summarises the counts per status', async () => {
    renderOverview();
    const summary = await screen.findByRole('group', { name: 'Status summary' });
    expect(summary).toHaveTextContent('1 critical');
    expect(summary).toHaveTextContent('1 unavailable');
    expect(summary).toHaveTextContent('3 warnings');
    expect(summary).toHaveTextContent('13 ok');
  });

  it('says everything is healthy when nothing needs attention', async () => {
    renderOverview(fakeApi({ overview: vi.fn(async () => fixture('overview-healthy')) }));
    expect(await screen.findByText('Every metric is healthy.')).toBeInTheDocument();
    expect(screen.queryByRole('list', { name: 'Needs attention' })).not.toBeInTheDocument();
  });

  it('has a focusable heading and no serious accessibility issue', async () => {
    const { container } = renderOverview();
    await screen.findByRole('list', { name: 'Needs attention' });
    expect(screen.getByRole('heading', { level: 1, name: 'Overview' })).toHaveAttribute('tabindex', '-1');
    await expectNoSeriousAxeIssues(container);
  });
});
