import type { Series } from '../api/types';

// CSV export of what the screen shows (FR-012): UTF-8 with a BOM so spreadsheets read accents, RFC 4180
// quoting, CRLF line ends.

function cell(value: string | number | null | undefined): string {
  const s = value === null || value === undefined ? '' : String(value);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCsv(rows: (string | number | null | undefined)[][]): string {
  return '﻿' + rows.map((r) => r.map(cell).join(',')).join('\r\n') + '\r\n';
}

/** "YYYY-MM-DD hh:mm:ss" in the given (or the browser's) time zone. */
function localStamp(iso: string, timeZone?: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date(iso));
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')} ${get('hour')}:${get('minute')}:${get('second')}`;
}

/** One row per timestamp present in any series: UTC time, local time, then one column per series. */
export function historyCsv(series: Series[], timeZone?: string): string {
  const times = [...new Set(series.flatMap((s) => s.points.map((p) => p.t)))].sort();
  const byName = series.map((s) => new Map(s.points.map((p) => [p.t, p.v])));
  return toCsv([
    ['time_utc', 'time_local', ...series.map((s) => s.name)],
    ...times.map((t) => [t, localStamp(t, timeZone), ...byName.map((m) => m.get(t))]),
  ]);
}

export function rowsCsv(rows: Record<string, string | number>[], columns: string[]): string {
  return toCsv([columns, ...rows.map((r) => columns.map((c) => r[c]))]);
}

/** Saves text as a file through a temporary link. */
export function download(filename: string, text: string, type = 'text/csv;charset=utf-8'): void {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}
