import { useCallback, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { Button, Select, ToggleButton } from '../../design/components';
import { download, rowsCsv } from '../../lib/csv';
import { PAGE_SIZES, parseProcesses, PROCESS_FIELDS, serializeProcesses, type ProcessQuery } from '../../lib/url-state';
import { ErrorScreen } from '../../shell/screens';
import { ProcessDetail } from './ProcessDetail';
import { ProcessFilters } from './ProcessFilters';
import { ProcessTable } from './ProcessTable';
import { useProcesses } from './useProcesses';

export { REFRESH_MS } from './useProcesses';

// User story 3: find, sort, page and inspect running processes (FR-011 to FR-013).

export function ProcessesPage() {
  const { t } = useTranslation();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const { pid } = useParams();
  const search = params.toString();
  const { value: query, invalid } = useMemo(() => parseProcesses(search), [search]);
  const { data, error, isPending, refetch, paused, setPaused } = useProcesses(query);

  const go = useCallback(
    (next: ProcessQuery, detail?: string) => {
      const qs = serializeProcesses(next);
      navigate(`/processes${detail ? `/${detail}` : ''}${qs ? `?${qs}` : ''}`);
    },
    [navigate],
  );

  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;

  if (error && !data) {
    return <ErrorScreen message={error instanceof Error ? error.message : t('error.network')} onRetry={() => void refetch()} />;
  }

  return (
    <div className="grid gap-5 pb-6" data-page="processes">
      <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 pt-7">
        <h1 tabIndex={-1} className="m-0 text-[1.75rem] font-semibold leading-tight tracking-tight outline-none max-sm:text-[1.4rem]">
          {t('processes.title')}
        </h1>
        <ToggleButton pressed={paused} onPressedChange={setPaused}>
          {paused ? t('processes.resume') : t('processes.pause')}
        </ToggleButton>
      </div>

      {invalid.length > 0 && (
        <p role="status" className="m-0 rounded-[10px] bg-warning-soft px-3.5 py-2.5 text-warning">
          {t('processes.invalid', { names: invalid.join(', ') })}
        </p>
      )}

      <ProcessFilters
        key={`${query.namespace}|${query.user}|${query.state}|${query.q}`}
        value={query}
        onApply={(f) => go({ ...query, ...f, page: 1 })}
      />

      {isPending && (
        <p role="status" className="m-0 text-muted">
          {t('processes.loading')}
        </p>
      )}

      {data && (
        <>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <p role="status" className="m-0 font-medium">
              {t('processes.total', { count: data.total })}
            </p>
            <Button onClick={() => download('processes.csv', rowsCsv(data.items, [...PROCESS_FIELDS]))}>{t('processes.export')}</Button>
          </div>
          {data.items.length === 0 ? (
            <p className="m-0 text-muted">{t('processes.none')}</p>
          ) : (
            <ProcessTable
              items={data.items}
              sort={query.sort}
              onSort={(sort) => go({ ...query, sort, page: 1 })}
              onOpen={(p) => go(query, p)}
            />
          )}
          <nav aria-label={t('processes.pageOf', { page: query.page, pages })} className="flex flex-wrap items-center gap-3 text-sm">
            <Button onClick={() => go({ ...query, page: query.page - 1 })} disabled={query.page <= 1}>
              {t('processes.previous')}
            </Button>
            <span className="text-muted">{t('processes.pageOf', { page: query.page, pages })}</span>
            <Button onClick={() => go({ ...query, page: query.page + 1 })} disabled={!data.next}>
              {t('processes.next')}
            </Button>
            <Select
              label={t('processes.rowsPerPage')}
              value={String(query.pageSize)}
              onChange={(e) => go({ ...query, pageSize: Number(e.target.value) as ProcessQuery['pageSize'], page: 1 })}
            >
              {PAGE_SIZES.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </Select>
          </nav>
        </>
      )}

      {pid && (
        <ProcessDetail
          pid={pid}
          process={data?.items.find((p) => String(p.pid) === pid)}
          loading={!data}
          onClose={() => go(query)}
        />
      )}
    </div>
  );
}
