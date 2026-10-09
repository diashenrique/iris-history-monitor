import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Series } from '../../api/types';
import { Button } from '../../design/components';
import { formatNumber, zoneName } from '../../i18n/format';

// The same points as the chart, as a table: the text alternative of the chart (FR-008, FR-019). Times
// are local with the zone abbreviation on every row, so a daylight-saving change never shows the same
// time twice (spec edge cases). Long series are paged so the page stays responsive.

export const ROWS_PER_PAGE = 100;

export function seriesLabel(name: string, t: (k: string, o?: Record<string, unknown>) => string): string {
  return ['Avg', 'Max', 'value'].includes(name) ? t(`history.series.${name}`) : name;
}

export function HistoryTable({ series, caption, timeZone }: { series: Series[]; caption?: string; timeZone?: string }) {
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const [page, setPage] = useState(0);

  const rows = useMemo(() => {
    const times = [...new Set(series.flatMap((s) => s.points.map((p) => p.t)))].sort();
    const maps = series.map((s) => new Map(s.points.map((p) => [p.t, p.v])));
    return times.map((time) => ({ time, values: maps.map((m) => m.get(time)) }));
  }, [series]);

  const fmt = useMemo(
    () =>
      new Intl.DateTimeFormat(lang, {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        timeZone,
        timeZoneName: 'short',
      }),
    [lang, timeZone],
  );
  const pages = Math.max(1, Math.ceil(rows.length / ROWS_PER_PAGE));
  const current = Math.min(page, pages - 1);
  const shown = rows.slice(current * ROWS_PER_PAGE, (current + 1) * ROWS_PER_PAGE);

  return (
    <div className="grid gap-2">
      {/* Focusable so keyboard users can scroll it sideways on narrow screens (WCAG 2.1.1). */}
      <div
        className="overflow-x-auto rounded-[10px] border border-divider bg-surface"
        tabIndex={0}
        role="region"
        aria-label={caption ?? t('history.title')}
      >
        <table className="w-full border-collapse text-sm tabular-nums">
          {caption && <caption className="sr-only">{caption}</caption>}
          <thead>
            <tr className="border-b border-divider text-left text-muted">
              <th scope="col" className="px-3 py-2 font-semibold">
                {t('history.time', { zone: zoneName(lang, new Date(), timeZone) })}
              </th>
              {series.map((s) => (
                <th key={s.name} scope="col" className="px-3 py-2 text-right font-semibold">
                  {seriesLabel(s.name, t)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {shown.map((r) => (
              <tr key={r.time} className="border-b border-divider last:border-b-0">
                <th scope="row" className="whitespace-nowrap px-3 py-1.5 text-left font-normal">
                  <time dateTime={r.time}>{fmt.format(new Date(r.time))}</time>
                </th>
                {r.values.map((v, i) => (
                  <td key={series[i]!.name} className="px-3 py-1.5 text-right">
                    {v === undefined ? '' : formatNumber(v, lang)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {pages > 1 && (
        <div className="flex flex-wrap items-center gap-3 text-sm text-muted">
          <Button onClick={() => setPage(current - 1)} disabled={current === 0}>
            {t('history.previous')}
          </Button>
          <span>
            {t('history.rows', {
              from: current * ROWS_PER_PAGE + 1,
              to: Math.min(rows.length, (current + 1) * ROWS_PER_PAGE),
              total: rows.length,
            })}
          </span>
          <Button onClick={() => setPage(current + 1)} disabled={current >= pages - 1}>
            {t('history.next')}
          </Button>
        </div>
      )}
    </div>
  );
}
