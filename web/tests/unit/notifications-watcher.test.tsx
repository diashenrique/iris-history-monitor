import { act, render } from '@testing-library/react';
import { QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router';
import { ApiProvider } from '../../src/api/context';
import type { OverviewSnapshot, Status } from '../../src/api/types';
import { IDLE_MS, WATCH_MS, useNotificationWatcher } from '../../src/features/notifications/useNotificationWatcher';
import { notificationsStore } from '../../src/features/notifications/store';
import '../i18n-test';
import { fakeApi, testQueryClient } from '../support/fake-api';

// Spec 005 US1 (FR-004 to FR-007a) and FR-008 (idle stop), with a fake Notification and fake timers.

class FakeNotification {
  static permission: NotificationPermission = 'granted';
  static shown: FakeNotification[] = [];
  onclick: (() => void) | null = null;
  closed = false;
  constructor(
    public title: string,
    public options: NotificationOptions = {},
  ) {
    FakeNotification.shown.push(this);
  }
  close() {
    this.closed = true;
  }
}

const snapshot = (pairs: [string, Status][]): OverviewSnapshot => ({
  generatedAt: '2026-10-13T00:00:00Z',
  metrics: pairs.map(([name, status]) => ({ name, value: null, unit: '', status })),
});

function Watcher() {
  useNotificationWatcher();
  return null;
}

function renderWatcher(readings: OverviewSnapshot[], path = '/history', client = testQueryClient()) {
  let i = 0;
  const overview = vi.fn(async () => readings[Math.min(i++, readings.length - 1)]);
  render(
    <QueryClientProvider client={client}>
      <ApiProvider client={fakeApi({ overview })}>
        <MemoryRouter initialEntries={[path]}>
          <Watcher />
        </MemoryRouter>
      </ApiProvider>
    </QueryClientProvider>,
  );
  return overview;
}

async function tick(ms = WATCH_MS + 10) {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(ms);
  });
}

function setHidden(hidden: boolean) {
  Object.defineProperty(document, 'visibilityState', { configurable: true, value: hidden ? 'hidden' : 'visible' });
}

beforeEach(() => {
  vi.useFakeTimers({ shouldAdvanceTime: true });
  localStorage.clear();
  FakeNotification.shown = [];
  FakeNotification.permission = 'granted';
  vi.stubGlobal('Notification', FakeNotification);
  Object.defineProperty(window, 'isSecureContext', { configurable: true, value: true });
  setHidden(false);
  notificationsStore.reset({ on: true });
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe('notification watcher', () => {
  it('a worse change on another screen makes one notification, and the same state makes no other', async () => {
    renderWatcher([
      snapshot([['licenseCurrentPct', 'ok']]),
      snapshot([['licenseCurrentPct', 'warning']]),
      snapshot([['licenseCurrentPct', 'warning']]),
    ]);
    await tick(10);
    expect(FakeNotification.shown).toHaveLength(0); // first reading: baseline only
    await tick();
    expect(FakeNotification.shown).toHaveLength(1);
    expect(FakeNotification.shown[0]!.title).toBe('IRIS History Monitor');
    expect(FakeNotification.shown[0]!.options.body).toBe('License use is now Warning');
    await tick();
    expect(FakeNotification.shown).toHaveLength(1);
  });

  it('several worse metrics in one reading make one notification', async () => {
    renderWatcher([
      snapshot([['licenseCurrentPct', 'ok'], ['journalSpace', 'warning']]),
      snapshot([['licenseCurrentPct', 'warning'], ['journalSpace', 'critical']]),
    ]);
    await tick(10);
    await tick();
    expect(FakeNotification.shown).toHaveLength(1);
    expect(FakeNotification.shown[0]!.options.body).toMatch(/^2 metrics got worse: /);
  });

  it('on the visible Overview it does not notify; with the tab hidden it does (FR-007a)', async () => {
    renderWatcher([snapshot([['a', 'ok']]), snapshot([['a', 'warning']]), snapshot([['a', 'critical']])], '/');
    await tick(10);
    await tick();
    expect(FakeNotification.shown).toHaveLength(0);
    setHidden(true);
    await tick();
    expect(FakeNotification.shown).toHaveLength(1);
  });

  it('clicking the notification focuses the window and opens the Overview (FR-007)', async () => {
    const focus = vi.spyOn(window, 'focus').mockImplementation(() => {});
    renderWatcher([snapshot([['a', 'ok']]), snapshot([['a', 'warning']])]);
    await tick(10);
    await tick();
    FakeNotification.shown[0]!.onclick?.();
    expect(focus).toHaveBeenCalled();
    expect(window.location.hash).toBe('#/');
    expect(FakeNotification.shown[0]!.closed).toBe(true);
  });

  it('off, or without permission, the watcher does not read the overview', async () => {
    notificationsStore.reset({ on: false });
    const overview = renderWatcher([snapshot([['a', 'ok']])]);
    await tick();
    expect(overview).not.toHaveBeenCalled();
    notificationsStore.reset({ on: true });
    FakeNotification.permission = 'default';
    await tick();
    expect(overview).not.toHaveBeenCalled();
  });

  it("does not touch the Overview's own figures, so a paused Overview stays still (research R2)", async () => {
    const client = testQueryClient();
    client.setQueryData(['overview'], snapshot([['a', 'ok']]));
    const before = client.getQueryState(['overview'])!.dataUpdatedAt;
    renderWatcher([snapshot([['a', 'ok']]), snapshot([['a', 'warning']])], '/history', client);
    await tick(10);
    await tick();
    expect(FakeNotification.shown).toHaveLength(1);
    expect(client.getQueryState(['overview'])!.dataUpdatedAt).toBe(before);
  });

  it('after 8 hours without interaction it stops, says so once, and resumes on interaction (FR-008)', async () => {
    const overview = renderWatcher([snapshot([['a', 'ok']])]);
    await tick(10);
    await tick(IDLE_MS + 61_000);
    expect(notificationsStore.get().idle).toBe(true);
    expect(FakeNotification.shown.map((n) => n.options.body)).toEqual(['Notifications paused after 8 hours without activity.']);
    const calls = overview.mock.calls.length;
    await tick(5 * WATCH_MS);
    expect(overview.mock.calls.length).toBe(calls);
    await act(async () => {
      window.dispatchEvent(new Event('pointerdown'));
    });
    expect(notificationsStore.get().idle).toBe(false);
    await tick();
    expect(overview.mock.calls.length).toBeGreaterThan(calls);
  });
});
