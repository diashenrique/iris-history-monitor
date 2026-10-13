import type { Metric, Status } from '../../api/types';

// Spec 005 FR-005, research R3: which changes between two readings notify.

export interface Transition {
  metric: string;
  from: Status;
  to: Status;
}

const RANK: Partial<Record<Status, number>> = { ok: 0, warning: 1, critical: 2 };

/** True for OK→warning, OK→critical and warning→critical. Unavailable on either side never notifies. */
export function isWorse(from: Status | undefined, to: Status): boolean {
  if (from !== 'ok' && from !== 'warning') return false;
  const next = RANK[to];
  return next !== undefined && next > RANK[from]!;
}

/**
 * The worse transitions from `before` (the last known states, null on the first reading) to `metrics`.
 * The first reading and metrics not seen before only set the baseline.
 */
export function worseTransitions(before: Map<string, Status> | null, metrics: Metric[]): Transition[] {
  if (!before) return [];
  return metrics.filter((m) => isWorse(before.get(m.name), m.status)).map((m) => ({ metric: m.name, from: before.get(m.name)!, to: m.status }));
}

export function statesOf(metrics: Metric[]): Map<string, Status> {
  return new Map(metrics.map((m) => [m.name, m.status]));
}
