import i18n from '../../i18n';
import type { Transition } from './transitions';

// Spec 005 FR-006 and contracts/ui-notifications.md: the text of a notification, in the interface language.

const name = (t: Transition) => i18n.t(`overview.metrics.${t.metric}`, { defaultValue: t.metric });
const state = (t: Transition) => i18n.t(`status.${t.to}`);

export function notificationBody(transitions: Transition[]): string {
  const [only] = transitions;
  if (transitions.length === 1 && only) return i18n.t('overview.statusChanged', { metric: name(only), status: state(only) });
  return i18n.t('notifications.several', {
    count: transitions.length,
    list: transitions.map((t) => `${name(t)} (${state(t)})`).join(', '),
  });
}
