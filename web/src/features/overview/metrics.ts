import type { Metric, Status } from '../../api/types';
import { formatNumber } from '../../i18n/format';

// How the Overview arranges and shows the API's metrics (approved mock-up, research R10).

export const STATUS_ORDER: Record<Status, number> = { critical: 0, unavailable: 1, warning: 2, ok: 3 };

export const GROUPS = ['System', 'Journal', 'ECP', 'Licenses', 'Activity'] as const;
export type Group = (typeof GROUPS)[number];

const GROUP_OF: Record<string, Group> = {
  systemUpTime: 'System',
  lastBackup: 'System',
  lockTable: 'System',
  writeDaemon: 'System',
  journalSpace: 'Journal',
  journalStatus: 'Journal',
  ecpAppServer: 'ECP',
  ecpDataServer: 'ECP',
  licenseCurrent: 'Licenses',
  licenseCurrentPct: 'Licenses',
  licenseHigh: 'Licenses',
  licenseHighPct: 'Licenses',
  licenseLimit: 'Licenses',
  applicationErrors: 'Activity',
  cspSessions: 'Activity',
  cacheEfficiency: 'Activity',
  processes: 'Activity',
  seriousAlerts: 'Activity',
};

export function groupOf(name: string): Group {
  return GROUP_OF[name] ?? 'Activity';
}

/** Metrics that need attention, critical first, then unavailable, then warning; API order inside. */
export function attentionOrder(metrics: Metric[]): Metric[] {
  return metrics
    .map((m, i) => ({ m, i }))
    .filter(({ m }) => m.status !== 'ok')
    .sort((a, b) => STATUS_ORDER[a.m.status] - STATUS_ORDER[b.m.status] || a.i - b.i)
    .map(({ m }) => m);
}

export function healthyByGroup(metrics: Metric[]): [Group, Metric[]][] {
  return GROUPS.map((g) => [g, metrics.filter((m) => m.status === 'ok' && groupOf(m.name) === g)] as [Group, Metric[]]).filter(
    ([, list]) => list.length > 0,
  );
}

export function countByStatus(metrics: Metric[]): Record<Status, number> {
  const counts: Record<Status, number> = { critical: 0, unavailable: 0, warning: 0, ok: 0 };
  for (const m of metrics) counts[m.status]++;
  return counts;
}

type T = (key: string, options?: Record<string, unknown>) => string;

export function displayValue(m: Metric, t: T, lang: string): string {
  if (m.value === null) return m.name === 'lastBackup' ? t('overview.never') : t('overview.noValue');
  if (typeof m.value === 'number') return formatNumber(m.value, lang);
  return m.value.replace(/\s+/g, ' ').trim();
}

export function displayUnit(m: Metric, t: T): string {
  if (m.value === null) return '';
  return m.unit === 'percent' || m.unit === 'ratio' ? t(`overview.units.${m.unit}`) : '';
}
