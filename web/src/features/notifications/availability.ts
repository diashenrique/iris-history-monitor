// Spec 005 FR-003, research R7: whether this browser, on this address, can show notifications.

export type Availability = 'insecure' | 'unsupported' | 'denied' | 'default' | 'granted';

interface Env {
  isSecureContext?: boolean;
  Notification?: { permission: NotificationPermission | string };
}

export function availability(env: Env = globalThis as unknown as Env): Availability {
  if (!env.isSecureContext) return 'insecure';
  if (!env.Notification) return 'unsupported';
  const p = env.Notification.permission;
  return p === 'granted' || p === 'denied' ? p : 'default';
}
