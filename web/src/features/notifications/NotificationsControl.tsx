import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button, Dialog } from '../../design/components';
import { availability, type Availability } from './availability';
import { notificationsStore, useNotificationsState } from './store';

// Spec 005 user story 2 (FR-001 to FR-003, FR-009) and contracts/ui-notifications.md: a header button that
// opens a dialog to turn notifications on or off, and says why they cannot work when they cannot.

type Shown = 'on' | 'off' | 'paused' | 'unavailable';

function shownState(avail: Availability, on: boolean, idle: boolean): Shown {
  if (avail === 'insecure' || avail === 'unsupported' || avail === 'denied') return 'unavailable';
  if (!on || avail !== 'granted') return 'off';
  return idle ? 'paused' : 'on';
}

export function NotificationsControl() {
  const { t } = useTranslation();
  const { on, idle } = useNotificationsState();
  const [open, setOpen] = useState(false);
  // The browser's permission changes outside React; re-read it after asking.
  const [, setAsked] = useState(0);
  const avail = availability();
  const state = shownState(avail, on, idle);

  async function turnOn() {
    const answer = avail === 'granted' ? 'granted' : await Notification.requestPermission();
    setAsked((n) => n + 1);
    if (answer === 'granted') notificationsStore.setOn(true);
  }

  const blocked = avail === 'insecure' || avail === 'unsupported' || avail === 'denied';

  return (
    <>
      <Button
        aria-label={t('notifications.buttonLabel', { state: t(`notifications.states.${state}`) })}
        title={t('notifications.buttonLabel', { state: t(`notifications.states.${state}`) })}
        onClick={() => setOpen(true)}
        className="relative inline-flex items-center justify-center px-2.5"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path
            d="M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9Zm4.3 13a2 2 0 0 0 3.4 0"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {state === 'off' || state === 'unavailable' ? <path d="M3 3l18 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /> : null}
        </svg>
        {state === 'on' && <span aria-hidden="true" className="absolute right-1 top-1 size-2 rounded-full bg-ok" />}
      </Button>
      <Dialog open={open} onOpenChange={setOpen} title={t('notifications.label')}>
        <div className="grid gap-3 text-sm">
          {avail === 'insecure' ? (
            <p className="m-0">{t('notifications.insecure')}</p>
          ) : avail === 'unsupported' ? (
            <p className="m-0">{t('notifications.unsupported')}</p>
          ) : avail === 'denied' ? (
            <p className="m-0">{t('notifications.denied')}</p>
          ) : (
            <>
              <p className="m-0">{t('notifications.intro')}</p>
              {state === 'on' && <p className="m-0 font-medium">{t('notifications.isOn')}</p>}
              {state === 'paused' && <p className="m-0 font-medium">{t('notifications.paused')}</p>}
            </>
          )}
          {!blocked && (
            <p className="m-0">
              {state === 'off' ? (
                <Button onClick={() => void turnOn()}>{t('notifications.turnOn')}</Button>
              ) : (
                <Button onClick={() => notificationsStore.setOn(false)}>{t('notifications.turnOff')}</Button>
              )}
            </p>
          )}
        </div>
      </Dialog>
    </>
  );
}
