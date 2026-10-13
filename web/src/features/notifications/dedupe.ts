import type { Status } from '../../api/types';

// Spec 005 FR-006, research R5: several tabs of one browser show one notification per transition.
// localStorage is shared by the tabs of an origin; a repeat of the same metric and state within the window
// is dropped.

export const DEDUPE_MS = 10 * 60_000;

const key = (metric: string) => `hm.notified.${metric}`;

export function shouldNotify(metric: string, state: Status, now = Date.now()): boolean {
  try {
    const [last, at] = (localStorage.getItem(key(metric)) ?? '').split('|');
    return !(last === state && now - Number(at) <= DEDUPE_MS);
  } catch {
    return true;
  }
}

export function markNotified(metric: string, state: Status, now = Date.now()): void {
  try {
    localStorage.setItem(key(metric), `${state}|${now}`);
  } catch {
    // Without storage each tab may notify; the notification tag still replaces identical ones.
  }
}
