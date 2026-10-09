import { QueryClient, QueryClientProvider, useQuery } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { HashRouter, Route, Routes, useLocation } from 'react-router';
import { ApiError, takeReturnRoute, type ApiClient } from './api/client';
import { ApiProvider, useApi } from './api/context';
import { HistoryPage } from './features/history/HistoryPage';
import { OverviewPage } from './features/overview/OverviewPage';
import { Header } from './shell/Header';
import { SCREENS } from './shell/routes';
import { ErrorScreen, LoadingScreen, NoAccessScreen, NotEnabledScreen, SoonScreen } from './shell/screens';

/** How often the shell re-reads the switch, so turning it off reaches open screens (spec Edge Cases). */
export const SETTINGS_INTERVAL = 60_000;

function errorMessage(error: unknown, t: (k: string) => string): string {
  if (error instanceof ApiError && error.kind === 'network') return t('error.network');
  return error instanceof Error ? error.message : t('error.network');
}

/** Sets the document title and moves focus to the screen heading on every route change. */
function useRouteFocus() {
  const location = useLocation();
  const { t } = useTranslation();
  const first = useRef(true);
  useEffect(() => {
    const screen = SCREENS.find((s) => (s.path === '/' ? location.pathname === '/' : location.pathname.startsWith(s.path)));
    document.title = t('app.title', { screen: t(screen?.label ?? 'nav.overview') });
    if (first.current) {
      first.current = false;
      return;
    }
    document.querySelector<HTMLElement>('#main h1')?.focus();
  }, [location.pathname, t]);
}

function Layout() {
  const { t } = useTranslation();
  useRouteFocus();
  return (
    <>
      <a
        href="#main"
        onClick={(e) => {
          e.preventDefault();
          document.getElementById('main')?.focus();
        }}
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-20 focus:rounded-lg focus:bg-raised focus:px-3 focus:py-2"
      >
        {t('skip')}
      </a>
      <Header />
      <main id="main" tabIndex={-1} className="mx-auto max-w-6xl px-4 pb-12 outline-none">
        <Routes>
          <Route path="/" element={<OverviewPage />} />
          <Route path="/history" element={<HistoryPage />} />
          <Route path="/processes" element={<SoonScreen />} />
          <Route path="/processes/:pid" element={<SoonScreen />} />
          <Route path="*" element={<OverviewPage />} />
        </Routes>
      </main>
    </>
  );
}

/** Reads the switch first; shows the screens only when the interface is turned on (FR-002, FR-016). */
function SettingsGate() {
  const api = useApi();
  const { t } = useTranslation();
  const settings = useQuery({
    queryKey: ['settings'],
    queryFn: () => api.settings(),
    refetchInterval: SETTINGS_INTERVAL,
    retry: false,
  });
  if (settings.isPending) return <LoadingScreen label={t('shell.checking')} />;
  if (settings.error instanceof ApiError && settings.error.kind === 'forbidden') return <NoAccessScreen />;
  if (settings.error instanceof ApiError && settings.error.kind === 'unauthorized')
    return <LoadingScreen label={t('shell.checking')} />;
  if (settings.isError && !settings.data)
    return <ErrorScreen message={errorMessage(settings.error, t)} onRetry={() => void settings.refetch()} />;
  if (!settings.data?.interfaceEnabled) return <NotEnabledScreen />;
  return <Layout />;
}

/** After sign-in IRIS lands on the Overview; go back to the screen the user was on (FR-015). */
function restoreReturnRoute() {
  const route = takeReturnRoute();
  if (route && (window.location.hash === '' || window.location.hash === '#/')) window.location.hash = route;
}

export function App({ client, queryClient }: { client?: ApiClient; queryClient?: QueryClient }) {
  useState(restoreReturnRoute);
  const [qc] = useState(() => queryClient ?? new QueryClient({ defaultOptions: { queries: { retry: 1 } } }));
  return (
    <QueryClientProvider client={qc}>
      <ApiProvider client={client}>
        <HashRouter>
          <SettingsGate />
        </HashRouter>
      </ApiProvider>
    </QueryClientProvider>
  );
}
