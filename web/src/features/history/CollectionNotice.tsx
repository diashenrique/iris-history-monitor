import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import type { HistoryCollection, Retention } from '../../api/types';
import { StatusIcon } from '../../design/components';
import { formatDateTime } from '../../i18n/format';

// Spec 004 user story 1 (FR-004): whether the instance records history. The module never turns
// collection on (owner's option A); the notice points an administrator to the README steps.

export const COLLECTION_HELP = 'https://github.com/diashenrique/iris-history-monitor#turning-on-history-collection';

/** True when History should warn: nothing is being recorded, or nothing new arrived in a while. */
export function needsNotice(c: HistoryCollection | undefined): boolean {
  return c?.state === 'off' || c?.state === 'stale';
}

/** True when the period starts before the oldest data the instance keeps for that granularity (FR-005). */
export function startsBeforeRetention(from: string, retention: Retention | undefined, now = Date.now()): boolean {
  return retention?.kind === 'days' && retention.days !== null && Date.parse(from) < now - retention.days * 86_400_000;
}

export function CollectionNotice({ collection }: { collection: HistoryCollection }) {
  const { t, i18n } = useTranslation();
  const titleId = useId();
  if (!needsNotice(collection)) return null;
  const never = collection.lastSample === null;
  const title =
    collection.state === 'off' && never
      ? t('history.collection.offTitle')
      : collection.state === 'stale' && never
        ? t('history.collection.noneYetTitle')
        : t('history.collection.stoppedTitle');
  return (
    <section role="status" aria-labelledby={titleId} className="m-0 grid gap-1.5 rounded-[10px] bg-warning-soft px-3.5 py-2.5 text-warning">
      <p id={titleId} className="m-0 flex items-start gap-2 font-semibold">
        <StatusIcon status="warning" size={18} />
        {title}
      </p>
      {!never && (
        <p className="m-0">
          {t('history.collection.lastSample', { time: formatDateTime(new Date(collection.lastSample!), i18n.language) })}
        </p>
      )}
      {collection.state === 'stale' && collection.running === false && <p className="m-0">{t('history.collection.notRunning')}</p>}
      <p className="m-0">
        {t('history.collection.forAdmins')}{' '}
        <a className="font-medium underline underline-offset-2" href={COLLECTION_HELP} target="_blank" rel="noreferrer">
          {t('history.collection.link')}
        </a>
      </p>
    </section>
  );
}
