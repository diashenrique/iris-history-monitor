import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import i18n from '../../src/i18n';
import { NotificationsControl } from '../../src/features/notifications/NotificationsControl';
import { notificationsStore } from '../../src/features/notifications/store';
import { expectNoSeriousAxeIssues } from '../axe';
import '../i18n-test';

// Spec 005 user story 2 (FR-001 to FR-003, FR-009) and contracts/ui-notifications.md.

const requestPermission = vi.fn();

function browser({ secure = true, permission = 'default' as NotificationPermission | null, answer = 'granted' as NotificationPermission } = {}) {
  Object.defineProperty(window, 'isSecureContext', { configurable: true, value: secure });
  if (permission === null) {
    vi.stubGlobal('Notification', undefined);
    return;
  }
  const N = { permission, requestPermission };
  requestPermission.mockImplementation(async () => {
    N.permission = answer;
    return answer;
  });
  vi.stubGlobal('Notification', N);
}

async function openDialog() {
  await userEvent.click(screen.getByRole('button', { name: /^Notifications: / }));
  return screen.getByRole('dialog', { name: 'Notifications' });
}

beforeEach(() => {
  localStorage.clear();
  requestPermission.mockReset();
  notificationsStore.reset({ on: false });
});

afterEach(async () => {
  vi.unstubAllGlobals();
  await i18n.changeLanguage('en');
});

describe('notifications control', () => {
  it('off: explains, and turning on asks the browser only on the click', async () => {
    browser();
    const { container } = render(<NotificationsControl />);
    expect(screen.getByRole('button', { name: 'Notifications: off' })).toBeInTheDocument();
    expect(requestPermission).not.toHaveBeenCalled();
    const dialog = await openDialog();
    expect(dialog).toHaveTextContent('Hidden tabs are checked about once a minute.');
    await userEvent.click(screen.getByRole('button', { name: 'Turn on' }));
    expect(requestPermission).toHaveBeenCalledTimes(1);
    expect(notificationsStore.get().on).toBe(true);
    expect(localStorage.getItem('hm.notifications')).toBe('on');
    expect(screen.getByText('Notifications are on in this browser.')).toBeInTheDocument();
    await expectNoSeriousAxeIssues(container.ownerDocument.body);
  });

  it('refused by the browser: stays off and says how to allow them', async () => {
    browser({ answer: 'denied' });
    render(<NotificationsControl />);
    await openDialog();
    await userEvent.click(screen.getByRole('button', { name: 'Turn on' }));
    expect(notificationsStore.get().on).toBe(false);
    expect(screen.getByText(/blocks notifications for this site/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Turn on' })).not.toBeInTheDocument();
  });

  it('on a plain HTTP address: unavailable, says HTTPS is needed, no Turn on', async () => {
    browser({ secure: false });
    render(<NotificationsControl />);
    expect(screen.getByRole('button', { name: 'Notifications: unavailable' })).toBeInTheDocument();
    await openDialog();
    expect(screen.getByText(/need a secure address \(HTTPS\)/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Turn on' })).not.toBeInTheDocument();
  });

  it('a browser without notifications says so', async () => {
    browser({ permission: null });
    render(<NotificationsControl />);
    await openDialog();
    expect(screen.getByText('This browser does not support notifications.')).toBeInTheDocument();
  });

  it('on: turning off clears the choice; paused says so', async () => {
    browser({ permission: 'granted' });
    notificationsStore.reset({ on: true });
    const { unmount } = render(<NotificationsControl />);
    expect(screen.getByRole('button', { name: 'Notifications: on' })).toBeInTheDocument();
    await openDialog();
    await userEvent.click(screen.getByRole('button', { name: 'Turn off' }));
    expect(notificationsStore.get().on).toBe(false);
    expect(localStorage.getItem('hm.notifications')).toBeNull();
    unmount();
    notificationsStore.reset({ on: true, idle: true });
    render(<NotificationsControl />);
    expect(screen.getByRole('button', { name: 'Notifications: paused' })).toBeInTheDocument();
    await openDialog();
    expect(screen.getByText(/paused after 8 hours without activity/)).toBeInTheDocument();
  });

  it('is translated', async () => {
    browser();
    await i18n.changeLanguage('pt-BR');
    const { unmount } = render(<NotificationsControl />);
    expect(screen.getByRole('button', { name: 'Notificações: desligadas' })).toBeInTheDocument();
    unmount();
    await i18n.changeLanguage('es');
    render(<NotificationsControl />);
    expect(screen.getByRole('button', { name: 'Notificaciones: desactivadas' })).toBeInTheDocument();
  });
});
