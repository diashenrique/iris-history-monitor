import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '../design/components';

// Screens outside the routes (contracts/ui-routes.md): no access, error, loading.

/** The role an account needs (spec 001, util.Security). */
export const ROLE = 'HistoryMonitorViewer';

function Message({ title, children }: { title: string; children: ReactNode }) {
  return (
    <main id="main" tabIndex={-1} className="mx-auto max-w-xl px-4 py-16">
      <h1 className="mb-3 text-2xl font-semibold tracking-tight text-balance">{title}</h1>
      <div className="grid gap-4 text-muted">{children}</div>
    </main>
  );
}

export function NoAccessScreen() {
  const { t } = useTranslation();
  return (
    <Message title={t('noAccess.title')}>
      <p>{t('noAccess.body', { role: ROLE })}</p>
    </Message>
  );
}

export function ErrorScreen({ message, onRetry }: { message: string; onRetry: () => void }) {
  const { t } = useTranslation();
  return (
    <Message title={t('error.title')}>
      <p role="alert">{message}</p>
      <p>
        <Button onClick={onRetry}>{t('error.retry')}</Button>
      </p>
    </Message>
  );
}

export function LoadingScreen({ label }: { label: string }) {
  return (
    <main id="main" tabIndex={-1} className="mx-auto max-w-xl px-4 py-16 text-muted" aria-busy="true">
      <p role="status">{label}</p>
    </main>
  );
}
