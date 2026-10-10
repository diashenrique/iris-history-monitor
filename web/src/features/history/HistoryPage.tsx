import { useQuery } from '@tanstack/react-query';
import { lazy, Suspense, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useSearchParams } from 'react-router';
import { Button, StatusIcon } from '../../design/components';
import { formatDateTime } from '../../i18n/format';
import { download, historyCsv } from '../../lib/csv';
import { parseHistory, presetRange, serializeHistory, type HistoryQuery } from '../../lib/url-state';
import { useApi } from '../../api/context';
import { ErrorScreen } from '../../shell/screens';
import { CollectionNotice, needsNotice, startsBeforeRetention } from './CollectionNotice';
import { HistoryForm } from './HistoryForm';
import { HistoryTable } from './HistoryTable';
import { useHistory } from './useHistory';

// User story 2: one history screen for license, CSP sessions and database size (FR-007 to FR-010).
// The chart library loads only here (research R11).
const HistoryChart = lazy(() => import('./HistoryChart'));

export function HistoryPage() {
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const [params, setParams] = useSearchParams();
  const search = params.toString();
  const { value: query, invalid } = useMemo(() => parseHistory(search), [search]);

  // A preset ends "now" when the view is chosen; the range then stays fixed until the view changes.
  const range = useMemo(
    () => (query.preset ? presetRange(query.preset) : { from: query.from!, to: query.to! }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [query.preset, query.from, query.to, query.metric, query.granularity],
  );
  const { result, isPending, error, retry, loadMore, loadingMore } = useHistory(query.metric, query.granularity, range);
  // Spec 004: whether history is being recorded, re-read every minute so the notice goes when it resumes.
  const api = useApi();
  const collection = useQuery({ queryKey: ['history-collection'], queryFn: () => api.historyCollection(), refetchInterval: 60_000 }).data;
  const retention = collection?.retention[query.granularity];
  const beforeRetention = useMemo(() => startsBeforeRetention(range.from, retention), [range.from, retention]);

  function change(next: HistoryQuery) {
    setParams(serializeHistory(next), { replace: false });
  }

  const allNames = result?.series.map((s) => s.name) ?? [];
  const shown =
    query.metric === 'database-size' && query.databases.length
      ? (result?.series ?? []).filter((s) => query.databases.includes(s.name))
      : (result?.series ?? []);
  const points = shown[0]?.points.length ?? 0;
  const metricName = t(`history.metrics.${query.metric}`);
  const unit = query.metric === 'database-size' ? t('history.unitMB') : undefined;
  const chartLabel = t('history.chartLabel', {
    metric: metricName,
    granularity: t(`history.granularities.${query.granularity}`),
    from: formatDateTime(new Date(range.from), lang),
    to: formatDateTime(new Date(range.to), lang),
  });

  function toggleDatabase(name: string, on: boolean) {
    const current = query.databases.length ? query.databases : [];
    const next = on ? [...current, name] : current.filter((d) => d !== name);
    change({ ...query, databases: next });
  }

  return (
    <div className="grid gap-5 pb-6">
      <h1 tabIndex={-1} className="m-0 pt-7 text-[1.75rem] font-semibold leading-tight tracking-tight outline-none max-sm:text-[1.4rem]">
        {t('history.title')}
      </h1>

      {invalid.length > 0 && (
        <p role="status" className="m-0 rounded-[10px] bg-warning-soft px-3.5 py-2.5 text-warning">
          {t('history.invalid', { names: invalid.filter((n, i, a) => a.indexOf(n) === i).join(', ') })}
        </p>
      )}

      <HistoryForm query={query} range={range} onChange={change} retention={retention} />

      {collection && <CollectionNotice collection={collection} />}

      {query.metric === 'database-size' && allNames.length > 0 && (
        <fieldset role="group" aria-label={t('history.databases')} className="m-0 flex flex-wrap gap-x-4 gap-y-2 border-0 p-0">
          <legend className="mb-1 text-sm text-muted">{t('history.databases')}</legend>
          {allNames.map((name) => (
            <label key={name} className="inline-flex items-center gap-2">
              <input
                type="checkbox"
                className="size-4 accent-[var(--color-accent)]"
                checked={query.databases.includes(name)}
                onChange={(e) => toggleDatabase(name, e.target.checked)}
              />
              {name}
            </label>
          ))}
        </fieldset>
      )}

      {isPending && (
        <p role="status" className="text-muted">
          {t('history.loading')}
        </p>
      )}
      {error && !result && <ErrorScreen message={error instanceof Error ? error.message : t('error.network')} onRetry={retry} />}

      {result && (
        <>
          {result.partial && result.coverage && (
            <p role="status" className="m-0 flex items-start gap-2 rounded-[10px] bg-warning-soft px-3.5 py-2.5 text-warning">
              <StatusIcon status="warning" size={18} />
              <span>
                {t('history.partial', {
                  first: formatDateTime(new Date(result.coverage.first), lang),
                  last: formatDateTime(new Date(result.coverage.last), lang),
                })}
                {beforeRetention && (
                  <>
                    {' '}
                    {t('history.partialRetention', { granularity: t(`history.retentionNames.${query.granularity}`), days: retention!.days })}
                  </>
                )}
              </span>
            </p>
          )}

          {shown.length === 0 ? (
            // When the instance has never recorded anything, the notice above replaces "no data" (FR-004).
            !(needsNotice(collection) && collection?.lastSample === null) && (
              <p role="status" className="m-0 text-muted">
                {t('history.noData')}
              </p>
            )
          ) : (
            <>
              <div
                className="rounded-[10px] border border-divider bg-surface p-3"
                data-points={points}
                data-range={`${range.from}/${range.to}`}
              >
                <Suspense fallback={<div className="h-[360px]" />}>
                  <HistoryChart series={shown} label={chartLabel} unit={unit} />
                </Suspense>
              </div>
              <div className="flex flex-wrap items-center gap-3">
                <Button onClick={() => download(`history-${query.metric}-${query.granularity}.csv`, historyCsv(shown))}>
                  {t('history.export')}
                </Button>
                {!result.complete && (
                  <>
                    <span className="text-sm text-muted">{t('history.incomplete', { count: points })}</span>
                    <Button onClick={() => void loadMore()} disabled={loadingMore}>
                      {t('history.loadMore')}
                    </Button>
                  </>
                )}
              </div>
              <HistoryTable series={shown} caption={t('history.tableCaption', { metric: metricName })} />
            </>
          )}
        </>
      )}
    </div>
  );
}
