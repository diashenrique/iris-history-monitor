import { useSyncExternalStore } from 'react';
import { readPreference, savePreference } from './preference';

// Spec 005: the notification state shared by the header control and the watcher. `on` is the browser's
// preference (FR-001); `idle` is set after 8 hours without interaction (FR-008).

export interface NotificationsState {
  on: boolean;
  idle: boolean;
}

let state: NotificationsState = { on: readPreference(), idle: false };
const listeners = new Set<() => void>();

function set(next: Partial<NotificationsState>) {
  state = { ...state, ...next };
  listeners.forEach((l) => l());
}

export const notificationsStore = {
  get: () => state,
  subscribe(listener: () => void) {
    listeners.add(listener);
    return () => listeners.delete(listener);
  },
  setOn(on: boolean) {
    savePreference(on);
    set({ on, idle: false });
  },
  setIdle(idle: boolean) {
    if (state.idle !== idle) set({ idle });
  },
  /** For tests: start from a known state. */
  reset(next: Partial<NotificationsState> = {}) {
    state = { on: false, idle: false, ...next };
    listeners.forEach((l) => l());
  },
};

export function useNotificationsState(): NotificationsState {
  return useSyncExternalStore(notificationsStore.subscribe, notificationsStore.get);
}
