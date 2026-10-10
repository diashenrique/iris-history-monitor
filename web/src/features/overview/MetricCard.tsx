import { useTranslation } from 'react-i18next';
import type { Metric, Status } from '../../api/types';
import { StatusBadge } from '../../design/components';
import { displayUnit, displayValue } from './metrics';
import { Sparkline } from './Sparkline';

// One metric, in the two forms of the approved mock-up: a large card in the attention band and a
// compact row among the healthy metrics.

const stripe: Record<Status, string> = {
  critical: 'border-t-critical',
  unavailable: 'border-t-unavailable',
  warning: 'border-t-warning',
  ok: 'border-t-ok',
};

export function AttentionCard({ metric }: { metric: Metric }) {
  const { t, i18n } = useTranslation();
  const unit = displayUnit(metric, t);
  return (
    <li
      data-metric={metric.name}
      data-status={metric.status}
      className={`grid min-w-0 gap-1.5 rounded-[10px] border border-t-4 border-divider bg-surface px-4 py-3.5 shadow-sm ${stripe[metric.status]}`}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="font-semibold">{t(`overview.metrics.${metric.name}`)}</span>
        <StatusBadge status={metric.status} />
      </div>
      <div className="text-2xl font-semibold tracking-tight tabular-nums">
        {displayValue(metric, t, i18n.language)}
        {unit && <span className="ml-1 text-sm font-medium text-muted">{unit}</span>}
      </div>
      {metric.reason && <p className="m-0 text-sm text-muted">{metric.reason}</p>}
    </li>
  );
}

export function HealthyRow({ metric, trend }: { metric: Metric; trend?: number[] }) {
  const { t, i18n } = useTranslation();
  const label = t(`overview.metrics.${metric.name}`);
  const unit = displayUnit(metric, t);
  const isMeter = metric.unit === 'percent' && typeof metric.value === 'number';
  return (
    <li
      data-metric={metric.name}
      data-status={metric.status}
      className="grid grid-cols-[minmax(0,1fr)_auto] items-baseline gap-x-3 gap-y-0.5 border-t border-divider px-4 py-2 first:border-t-0"
    >
      <span className="text-muted">{label}</span>
      <span className="text-right font-semibold tabular-nums">
        {displayValue(metric, t, i18n.language)}
        {unit && <span className="ml-1 text-[0.8125rem] font-medium text-muted">{unit}</span>}
      </span>
      {isMeter ? (
        <div
          role="meter"
          aria-label={label}
          aria-valuenow={metric.value as number}
          aria-valuemin={0}
          aria-valuemax={100}
          className="col-span-2 mt-1 h-2 overflow-hidden rounded bg-divider"
        >
          <span className="block h-full rounded bg-accent" style={{ width: `${Math.min(100, metric.value as number)}%` }} />
        </div>
      ) : (
        trend && (
          <div className="col-span-2">
            <Sparkline values={trend} />
          </div>
        )
      )}
    </li>
  );
}
