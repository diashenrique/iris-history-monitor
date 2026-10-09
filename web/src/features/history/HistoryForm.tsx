import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import type { Granularity, HistoryMetric } from '../../api/types';
import { Select } from '../../design/components';
import { PRESETS, type HistoryQuery, type Preset } from '../../lib/url-state';

// Metric, granularity and period (FR-007). A custom range is typed in local time and kept in UTC.

const METRICS: HistoryMetric[] = ['license', 'csp-sessions', 'database-size'];
const GRANULARITIES: Granularity[] = ['5min', 'hourly', 'daily'];

/** UTC ISO → value of a datetime-local input, in the browser's zone. */
export function toLocalInput(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** Value of a datetime-local input (local time) → UTC ISO without milliseconds, or null. */
export function fromLocalInput(value: string): string | null {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export function HistoryForm({
  query,
  range,
  onChange,
}: {
  query: HistoryQuery;
  range: { from: string; to: string };
  onChange: (q: HistoryQuery) => void;
}) {
  const { t } = useTranslation();
  const fromId = useId();
  const toId = useId();
  const custom = query.preset === null;

  function setPeriod(value: string) {
    if (value === 'custom') onChange({ ...query, preset: null, from: range.from, to: range.to });
    else onChange({ ...query, preset: value as Preset, from: null, to: null });
  }

  function setBound(which: 'from' | 'to', value: string) {
    const iso = fromLocalInput(value);
    if (!iso) return;
    const next = { ...query, preset: null, from: query.from ?? range.from, to: query.to ?? range.to, [which]: iso };
    if (next.from! <= next.to!) onChange(next);
  }

  const input = 'min-h-9 rounded-lg border border-control bg-surface px-3 text-text hover:border-text';

  return (
    <div className="flex flex-wrap items-end gap-x-4 gap-y-3">
      <Select label={t('history.metric')} value={query.metric} onChange={(e) => onChange({ ...query, metric: e.target.value as HistoryMetric, databases: [] })}>
        {METRICS.map((m) => (
          <option key={m} value={m}>
            {t(`history.metrics.${m}`)}
          </option>
        ))}
      </Select>
      <Select label={t('history.granularity')} value={query.granularity} onChange={(e) => onChange({ ...query, granularity: e.target.value as Granularity })}>
        {GRANULARITIES.map((g) => (
          <option key={g} value={g}>
            {t(`history.granularities.${g}`)}
          </option>
        ))}
      </Select>
      <Select label={t('history.period')} value={custom ? 'custom' : query.preset!} onChange={(e) => setPeriod(e.target.value)}>
        {PRESETS.map((p) => (
          <option key={p} value={p}>
            {t(`history.presets.${p}`)}
          </option>
        ))}
        <option value="custom">{t('history.presets.custom')}</option>
      </Select>
      {custom && (
        <>
          <span className="inline-flex items-center gap-2">
            <label htmlFor={fromId} className="text-sm text-muted">
              {t('history.from')}
            </label>
            <input id={fromId} type="datetime-local" className={input} value={toLocalInput(query.from)} onChange={(e) => setBound('from', e.target.value)} />
          </span>
          <span className="inline-flex items-center gap-2">
            <label htmlFor={toId} className="text-sm text-muted">
              {t('history.to')}
            </label>
            <input id={toId} type="datetime-local" className={input} value={toLocalInput(query.to)} onChange={(e) => setBound('to', e.target.value)} />
          </span>
        </>
      )}
    </div>
  );
}
