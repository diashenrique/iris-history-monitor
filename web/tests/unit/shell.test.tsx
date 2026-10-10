import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { App, SETTINGS_INTERVAL } from '../../src/App';
import { expectNoSeriousAxeIssues } from '../axe';
import '../i18n-test';
import { fakeApi, fixture, forbidden, networkDown, testQueryClient } from '../support/fake-api';

function renderApp(api = fakeApi()) {
  window.location.hash = '#/';
  return { api, ...render(<App client={api} queryClient={testQueryClient()} />) };
}

describe('shell', () => {
  it('shows the not-enabled screen with a link to the old pages when the switch is off (FR-002)', async () => {
    const { container } = renderApp(fakeApi({ settings: vi.fn(async () => fixture('settings-off')) }));
    expect(await screen.findByRole('heading', { name: 'The new monitor is not turned on' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open the existing pages' })).toHaveAttribute(
      'href',
      '/csp/irismonitor/dashboard.csp',
    );
    await expectNoSeriousAxeIssues(container);
  });

  it('shows no-access naming the role on 403 and loads no data (FR-016)', async () => {
    const api = fakeApi({ settings: vi.fn(async () => Promise.reject(forbidden())) });
    renderApp(api);
    expect(await screen.findByRole('heading', { name: 'You do not have access to the monitor' })).toBeInTheDocument();
    expect(screen.getByText(/HistoryMonitorViewer/)).toBeInTheDocument();
    expect(api.overview).not.toHaveBeenCalled();
  });

  it('shows an error with a retry when the monitor does not answer', async () => {
    const settings = vi.fn().mockRejectedValueOnce(networkDown()).mockResolvedValue(fixture('settings-on'));
    renderApp(fakeApi({ settings }));
    expect(await screen.findByRole('alert')).toHaveTextContent('The monitor did not answer.');
    await userEvent.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('navigation', { name: 'Main' })).toBeInTheDocument();
  });

  it('when on, shows the layout: skip link first, navigation with delivered screens only, title', async () => {
    const { container } = renderApp();
    const nav = await screen.findByRole('navigation', { name: 'Main' });
    expect(nav).toHaveTextContent('Overview');
    expect(nav).toHaveTextContent('History');
    expect(nav).not.toHaveTextContent('Processes');
    await userEvent.tab();
    expect(screen.getByText('Skip to content')).toHaveFocus();
    expect(document.title).toBe('Overview · IRIS History Monitor');
    expect(screen.getByLabelText('Language')).toBeInTheDocument();
    expect(screen.getByLabelText('Appearance')).toBeInTheDocument();
    await expectNoSeriousAxeIssues(container);
  });

  it('a later screen addressed directly says it is not available yet', async () => {
    const api = fakeApi();
    window.location.hash = '#/processes?namespace=USER';
    render(<App client={api} queryClient={testQueryClient()} />);
    expect(await screen.findByRole('heading', { name: 'Not available yet' })).toBeInTheDocument();
  });

  it('re-reads the switch every 60 s, so turning it off reaches an open screen (spec Edge Cases)', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    try {
      const settings = vi.fn().mockResolvedValueOnce(fixture('settings-on')).mockResolvedValue(fixture('settings-off'));
      renderApp(fakeApi({ settings }));
      expect(await screen.findByRole('navigation', { name: 'Main' })).toBeInTheDocument();
      await act(async () => {
        await vi.advanceTimersByTimeAsync(SETTINGS_INTERVAL + 100);
      });
      expect(await screen.findByRole('heading', { name: 'The new monitor is not turned on' })).toBeInTheDocument();
    } finally {
      vi.useRealTimers();
    }
  });

  it('changing the language translates the screen and is remembered (FR-017)', async () => {
    renderApp();
    await screen.findByRole('navigation', { name: 'Main' });
    await userEvent.selectOptions(screen.getByLabelText('Language'), 'pt-BR');
    expect(await screen.findByRole('navigation', { name: 'Principal' })).toHaveTextContent('Visão geral');
    expect(localStorage.getItem('hm.language')).toBe('pt-BR');
    expect(document.documentElement.lang).toBe('pt-BR');
    await userEvent.selectOptions(screen.getByLabelText('Idioma'), 'en');
  });
});
