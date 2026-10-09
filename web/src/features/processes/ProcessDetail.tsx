import { useTranslation } from 'react-i18next';
import type { Process } from '../../api/types';
import { Dialog } from '../../design/components';
import { formatNumber } from '../../i18n/format';
import { PROCESS_FIELDS } from '../../lib/url-state';

// One process with every field the API returns for it; fields it does not have are left out, not shown
// as blanks (US3 scenario 2). A process that ended since the list was read says so.

export function ProcessDetail({
  pid,
  process,
  loading,
  onClose,
}: {
  pid: string;
  process: Process | undefined;
  loading: boolean;
  onClose: () => void;
}) {
  const { t, i18n } = useTranslation();
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()} title={t('processes.detailTitle', { pid })}>
      {process ? (
        <dl className="m-0 grid grid-cols-[auto_minmax(0,1fr)] gap-x-6 gap-y-1.5 text-sm">
          {PROCESS_FIELDS.filter((f) => process[f] !== undefined && process[f] !== '').map((f) => (
            <div key={f} className="contents">
              <dt className="text-muted">{t(`processes.fields.${f}`)}</dt>
              <dd className="m-0 break-words font-medium tabular-nums">
                {typeof process[f] === 'number' ? formatNumber(process[f] as number, i18n.language) : process[f]}
              </dd>
            </div>
          ))}
        </dl>
      ) : (
        <p role="status" className="m-0 text-muted">
          {loading ? t('processes.loading') : t('processes.ended')}
        </p>
      )}
    </Dialog>
  );
}
