import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Status } from '../../api/types';
import { StatusIcon, ToggleButton } from '../../design/components';
import { formatTime, zoneName } from '../../i18n/format';
import { ErrorScreen } from '../../shell/screens';
import { AttentionCard, HealthyRow } from './MetricCard';
import { attentionOrder, countByStatus, healthyByGroup } from './metrics';
import { useOverview } from './useOverview';

// User story 1: the health of the instance at a glance, following the approved mock-up (research R10).

const chip: Record<Status, string> = {
  critical: 'bg-critical-soft text-critical',
  unavailable: 'bg-unavailable-soft text-unavailable',
  warning: 'bg-warning-soft text-warning',
  ok: 'bg-ok-soft text-ok',
};

/** Announces status changes (not every refresh) to screen readers. */
function useStatusAnnouncement(metrics: { name: string; status: Status }[] | undefined) {
  const { t } = useTranslation();
  const previous = useRef<Map<string, Status> | null>(null);
  const [message, setMessage] = useState('');
  useEffect(() => {
    if (!metrics) return;
    const before = previous.current;
    previous.current = new Map(metrics.map((m) => [m.name, m.status]));
    if (!before) return;
    const changed = metrics.filter((m) => before.get(m.name) !== undefined && before.get(m.name) !== m.status);
    if (changed.length)
      setMessage(
        changed
          .map((m) => t('overview.statusChanged', { metric: t(`overview.metrics.${m.name}`), status: t(`status.${m.status}`) }))
          .join('. '),
      );
  }, [metrics, t]);
  return message;
}

export function OverviewPage() {
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const { snapshot, lastSuccessAt, stale, failedFirst, error, retry, paused, setPaused, trend } = useOverview();
  const announcement = useStatusAnnouncement(snapshot?.metrics);

  const heading = (
    <h1 tabIndex={-1} className="m-0 text-[1.75rem] font-semibold leading-tight tracking-tight outline-none max-sm:text-[1.4rem]">
      {t('overview.title')}
    </h1>
  );

  if (failedFirst) {
    return <ErrorScreen message={error instanceof Error ? error.message : t('error.network')} onRetry={retry} />;
  }

  const metrics = snapshot?.metrics ?? [];
  const attention = attentionOrder(metrics);
  const healthy = healthyByGroup(metrics);
  const counts = countByStatus(metrics);
  const time = lastSuccessAt ? formatTime(lastSuccessAt, lang) : '';

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 pb-[18px] pt-7">
        {heading}
        {snapshot && (
          <div className="flex items-center gap-2.5 text-muted">
            <span
              aria-hidden="true"
              className={`size-[9px] rounded-full ${paused ? 'bg-control' : 'bg-ok shadow-[0_0_0_3px_color-mix(in_srgb,var(--color-ok)_25%,transparent)]'}`}
            />
            <span>
              {paused ? t('overview.pausedNote') : t('overview.updated')}{' '}
              <time data-updated="" dateTime={lastSuccessAt?.toISOString()} className="tabular-nums">
                {time}
              </time>{' '}
              {zoneName(lang)}
            </span>
            <ToggleButton pressed={paused} onPressedChange={setPaused}>
              {paused ? t('overview.resume') : t('overview.pause')}
            </ToggleButton>
          </div>
        )}
      </div>

      {!snapshot && (
        <p role="status" className="text-muted">
          {t('overview.loading')}
        </p>
      )}

      {stale && (
        <div
          role="status"
          className="mb-[18px] flex items-start gap-2.5 rounded-[10px] border border-warning/35 bg-warning-soft px-3.5 py-3 text-warning"
        >
          <StatusIcon status="warning" size={20} />
          <p className="m-0">
            <strong>{t('overview.staleTitle')}</strong> {t('overview.staleBody', { time })}
          </p>
        </div>
      )}

      <div className="sr-only" aria-live="polite">
        {announcement}
      </div>

      {snapshot && (
        <>
          <div role="group" aria-label={t('summary.label')} className="mb-[22px] flex flex-wrap gap-2">
            {(['critical', 'unavailable', 'warning', 'ok'] as const)
              .filter((s) => counts[s] > 0)
              .map((s) => (
                <span key={s} className={`inline-flex items-center gap-1.5 rounded-full py-1 pl-2 pr-2.5 text-sm font-semibold ${chip[s]}`}>
                  <StatusIcon status={s} />
                  {t(`summary.${s}`, { count: counts[s] })}
                </span>
              ))}
          </div>

          {attention.length > 0 ? (
            <section aria-labelledby="attention-h">
              <h2 id="attention-h" className="mb-2.5 text-[0.8125rem] font-semibold uppercase tracking-[0.08em] text-muted">
                {t('overview.attention')}
              </h2>
              <ul aria-label={t('overview.attention')} className="m-0 grid list-none grid-cols-[repeat(auto-fill,minmax(260px,1fr))] gap-3 p-0">
                {attention.map((m) => (
                  <AttentionCard key={m.name} metric={m} />
                ))}
              </ul>
            </section>
          ) : (
            <p className="mb-2 flex items-center gap-2 font-medium text-ok">
              <StatusIcon status="ok" /> {t('overview.allHealthy')}
            </p>
          )}

          <section aria-labelledby="healthy-h" className="mt-7">
            <h2 id="healthy-h" className="mb-2.5 text-[0.8125rem] font-semibold uppercase tracking-[0.08em] text-muted">
              {t('overview.healthy')}
            </h2>
            <div className="grid grid-cols-[repeat(auto-fit,minmax(min(300px,100%),1fr))] gap-3">
              {healthy.map(([group, list]) => {
                const name = t(`overview.groups.${group}`);
                return (
                  <div key={group} className="min-w-0 rounded-[10px] border border-divider bg-surface py-1.5 shadow-sm">
                    <h3 className="mx-4 mb-1 mt-2 text-[0.9375rem] font-semibold">{name}</h3>
                    <ul aria-label={`${t('overview.healthy')}: ${name}`} className="m-0 list-none p-0">
                      {list.map((m) => (
                        <HealthyRow key={m.name} metric={m} trend={trend[m.name]} />
                      ))}
                    </ul>
                  </div>
                );
              })}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
