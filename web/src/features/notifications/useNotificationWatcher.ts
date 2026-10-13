import { useQuery } from '@tanstack/react-query';
import { useEffect, useRef } from 'react';
import { useLocation } from 'react-router';
import { useApi } from '../../api/context';
import type { Status } from '../../api/types';
import i18n from '../../i18n';
import { availability } from './availability';
import { notificationBody } from './body';
import { markNotified, shouldNotify } from './dedupe';
import { notificationsStore, useNotificationsState } from './store';
import { statesOf, worseTransitions } from './transitions';

// Spec 005 user story 1 and FR-008 (research R2 to R6). Mounted once in the shell, on every screen.
// While notifications are on and allowed, it reads the overview also with the tab hidden (the browser
// slows hidden tabs to about once a minute), compares each reading with the last one, and shows one
// notification for the metrics that got worse. After 8 hours without interaction it stops reading, so a
// forgotten tab does not hold the session and a license unit; using the monitor resumes it.

export const WATCH_MS = 30_000;
export const IDLE_MS = 8 * 60 * 60_000;

function show(body: string, tag: string) {
  const n = new Notification(i18n.t('notifications.title'), { body, tag });
  n.onclick = () => {
    window.focus();
    window.location.hash = '#/';
    n.close();
  };
}

export function useNotificationWatcher() {
  const api = useApi();
  const { pathname } = useLocation();
  const { on, idle } = useNotificationsState();
  const active = on && !idle && availability() === 'granted';

  const query = useQuery({
    // Its own cache entry: sharing the Overview's would keep changing a paused Overview (research R2).
    queryKey: ['overview', 'notifications'],
    queryFn: () => api.overview(),
    enabled: active,
    refetchInterval: active ? WATCH_MS : false,
    refetchIntervalInBackground: true,
    retry: false,
  });

  // Last known states; null until the first reading after the watcher becomes active.
  const before = useRef<Map<string, Status> | null>(null);
  const seen = useRef(0);

  useEffect(() => {
    if (!active) {
      before.current = null;
      return;
    }
    if (!query.data || query.dataUpdatedAt === seen.current) return;
    seen.current = query.dataUpdatedAt;
    const changes = worseTransitions(before.current, query.data.metrics);
    before.current = statesOf(query.data.metrics);
    // On the visible Overview the change is already on screen and announced (FR-007a).
    if (!changes.length || (document.visibilityState === 'visible' && pathname === '/')) return;
    const fresh = changes.filter((c) => shouldNotify(c.metric, c.to));
    if (!fresh.length) return;
    fresh.forEach((c) => markNotified(c.metric, c.to));
    show(notificationBody(fresh), `hm-${fresh.map((c) => `${c.metric}:${c.to}`).join(',')}`);
  }, [active, query.data, query.dataUpdatedAt, pathname]);

  // Idle stop (FR-008): any interaction, or bringing the tab to the front, counts as activity.
  const lastActivity = useRef(0);
  useEffect(() => {
    if (!on) return;
    lastActivity.current = Date.now();
    const touch = () => {
      lastActivity.current = Date.now();
      notificationsStore.setIdle(false);
    };
    const onVisibility = () => {
      if (document.visibilityState === 'visible') touch();
    };
    window.addEventListener('keydown', touch);
    window.addEventListener('pointerdown', touch);
    document.addEventListener('visibilitychange', onVisibility);
    const timer = window.setInterval(() => {
      if (notificationsStore.get().idle || Date.now() - lastActivity.current < IDLE_MS) return;
      notificationsStore.setIdle(true);
      if (availability() === 'granted') show(i18n.t('notifications.pausedBody'), 'hm-paused');
    }, 60_000);
    return () => {
      window.removeEventListener('keydown', touch);
      window.removeEventListener('pointerdown', touch);
      document.removeEventListener('visibilitychange', onVisibility);
      window.clearInterval(timer);
    };
  }, [on]);
}
