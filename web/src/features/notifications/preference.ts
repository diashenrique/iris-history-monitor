// Spec 005 FR-001: notifications on or off, per browser. Storage can be unavailable; then it is off.

const KEY = 'hm.notifications';

export function readPreference(): boolean {
  try {
    return localStorage.getItem(KEY) === 'on';
  } catch {
    return false;
  }
}

export function savePreference(on: boolean): void {
  try {
    if (on) localStorage.setItem(KEY, 'on');
    else localStorage.removeItem(KEY);
  } catch {
    // Not remembered; the choice still applies until the page is reloaded.
  }
}
