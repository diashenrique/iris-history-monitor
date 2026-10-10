// Response shapes of the monitor API v1 (specs/001-api-v1/contracts/openapi.yaml, version 1.1.0).
// The fixtures test checks sample responses against that contract, so these types cannot drift unseen.

export type Status = 'ok' | 'warning' | 'critical' | 'unavailable';

export interface Settings {
  /** @deprecated Always true since 2.0.0; the switch was removed (spec 003). */
  interfaceEnabled: boolean;
}

export interface Metric {
  name: string;
  value: string | number | null;
  unit: string;
  status: Status;
  reason?: string;
}

export interface OverviewSnapshot {
  generatedAt: string;
  metrics: Metric[];
}

export interface Point {
  t: string;
  v: number;
}

export interface Series {
  name: string;
  points: Point[];
}

export type HistoryMetric = 'license' | 'csp-sessions' | 'database-size';
export type Granularity = '5min' | 'hourly' | 'daily';

export interface HistorySeries {
  metric: HistoryMetric;
  granularity: Granularity;
  from: string;
  to: string;
  coverage: { first: string; last: string } | null;
  partial: boolean;
  truncated: boolean;
  next?: string;
  series: Series[];
}

export type Process = Record<string, string | number>;

export interface ProcessPage {
  items: Process[];
  total: number;
  page: number;
  pageSize: number;
  next?: string;
}

export interface Problem {
  type: string;
  title: string;
  status: number;
  detail: string;
  errors?: { parameter: string; message: string }[];
}
