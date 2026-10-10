// View state in the address (FR-013), per specs/002-new-ui/contracts/ui-routes.md. Each parser returns
// valid state plus the names of the parameters it had to replace with defaults, so the screen can say so.

import type { Granularity, HistoryMetric } from '../api/types';

export interface Parsed<T> {
  value: T;
  /** Parameters that were present but invalid and were replaced by defaults. */
  invalid: string[];
}

const METRICS: readonly HistoryMetric[] = ['license', 'csp-sessions', 'database-size'];
const GRANULARITIES: readonly Granularity[] = ['5min', 'hourly', 'daily'];
export const PRESETS = ['24h', '7d', '30d', '90d'] as const;
export type Preset = (typeof PRESETS)[number];
const DB_NAME = /^[A-Za-z0-9_.%-]{1,64}$/;
const UTC = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?Z$/;

export interface HistoryQuery {
  metric: HistoryMetric;
  granularity: Granularity;
  preset: Preset | null;
  from: string | null;
  to: string | null;
  databases: string[];
}

export const HISTORY_DEFAULTS: HistoryQuery = {
  metric: 'license',
  granularity: 'hourly',
  preset: '7d',
  from: null,
  to: null,
  databases: [],
};

function isUtc(v: string | null): v is string {
  return !!v && UTC.test(v) && !Number.isNaN(Date.parse(v));
}

export function parseHistory(search: string): Parsed<HistoryQuery> {
  const p = new URLSearchParams(search);
  const invalid: string[] = [];
  const value: HistoryQuery = { ...HISTORY_DEFAULTS, databases: [] };

  const metric = p.get('metric');
  if (metric !== null) {
    if ((METRICS as readonly string[]).includes(metric)) value.metric = metric as HistoryMetric;
    else invalid.push('metric');
  }
  const granularity = p.get('granularity');
  if (granularity !== null) {
    if ((GRANULARITIES as readonly string[]).includes(granularity)) value.granularity = granularity as Granularity;
    else invalid.push('granularity');
  }
  const from = p.get('from');
  const to = p.get('to');
  const preset = p.get('preset');
  if (from !== null || to !== null) {
    if (isUtc(from) && isUtc(to) && Date.parse(from) <= Date.parse(to)) {
      value.preset = null;
      value.from = from;
      value.to = to;
    } else {
      invalid.push('from', 'to');
    }
  } else if (preset !== null) {
    if ((PRESETS as readonly string[]).includes(preset)) value.preset = preset as Preset;
    else invalid.push('preset');
  }
  const dbs = p.getAll('db');
  if (dbs.length) {
    if (value.metric !== 'database-size' || dbs.some((d) => !DB_NAME.test(d))) invalid.push('db');
    else value.databases = [...new Set(dbs)];
  }
  return { value, invalid };
}

export function serializeHistory(q: HistoryQuery): string {
  const p = new URLSearchParams();
  p.set('metric', q.metric);
  p.set('granularity', q.granularity);
  if (q.preset) p.set('preset', q.preset);
  else if (q.from && q.to) {
    p.set('from', q.from);
    p.set('to', q.to);
  }
  if (q.metric === 'database-size') for (const d of q.databases) p.append('db', d);
  return p.toString();
}

/** The UTC range of a preset, ending at `now`. */
export function presetRange(preset: Preset, now: Date = new Date()): { from: string; to: string } {
  const hours = { '24h': 24, '7d': 24 * 7, '30d': 24 * 30, '90d': 24 * 90 }[preset];
  const iso = (d: Date) => d.toISOString().replace(/\.\d{3}Z$/, 'Z');
  return { from: iso(new Date(now.getTime() - hours * 3600_000)), to: iso(now) };
}

export const PROCESS_FIELDS = [
  'job', 'pid', 'displayPid', 'username', 'device', 'namespace', 'routine', 'commands', 'globals', 'state',
  'clientName', 'exeName', 'ipAddress', 'privateGlobalBlocks', 'osUsername', 'cpuTime', 'parentPid', 'elapsedTime',
] as const;
export const PAGE_SIZES = [25, 50, 100] as const;

export interface ProcessQuery {
  namespace: string;
  user: string;
  state: string;
  q: string;
  sort: string;
  page: number;
  pageSize: (typeof PAGE_SIZES)[number];
}

export const PROCESS_DEFAULTS: ProcessQuery = { namespace: '', user: '', state: '', q: '', sort: 'job', page: 1, pageSize: 50 };

// eslint-disable-next-line no-control-regex
const CONTROL = /[\u0000-\u001f\u007f]/;

export function parseProcesses(search: string): Parsed<ProcessQuery> {
  const p = new URLSearchParams(search);
  const invalid: string[] = [];
  const value: ProcessQuery = { ...PROCESS_DEFAULTS };
  for (const [key, max] of [['namespace', 128], ['user', 128], ['state', 128], ['q', 100]] as const) {
    const v = p.get(key);
    if (v === null || v === '') continue;
    if (v.length <= max && !CONTROL.test(v)) value[key] = v;
    else invalid.push(key);
  }
  const sort = p.get('sort');
  if (sort !== null) {
    const field = sort.startsWith('-') ? sort.slice(1) : sort;
    if ((PROCESS_FIELDS as readonly string[]).includes(field)) value.sort = sort;
    else invalid.push('sort');
  }
  const page = p.get('page');
  if (page !== null) {
    if (/^[1-9]\d{0,5}$/.test(page)) value.page = Number(page);
    else invalid.push('page');
  }
  const size = p.get('pageSize');
  if (size !== null) {
    const n = Number(size);
    if ((PAGE_SIZES as readonly number[]).includes(n)) value.pageSize = n as ProcessQuery['pageSize'];
    else invalid.push('pageSize');
  }
  return { value, invalid };
}

export function serializeProcesses(q: ProcessQuery): string {
  const p = new URLSearchParams();
  for (const key of ['namespace', 'user', 'state', 'q'] as const) if (q[key]) p.set(key, q[key]);
  if (q.sort !== PROCESS_DEFAULTS.sort) p.set('sort', q.sort);
  if (q.page !== 1) p.set('page', String(q.page));
  if (q.pageSize !== PROCESS_DEFAULTS.pageSize) p.set('pageSize', String(q.pageSize));
  return p.toString();
}
