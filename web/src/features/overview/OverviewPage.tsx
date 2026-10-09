import { useTranslation } from 'react-i18next';

// Replaced by the live Overview in task T030.
export function OverviewPage() {
  const { t } = useTranslation();
  return <h1 tabIndex={-1} className="py-7 outline-none text-[1.75rem] font-semibold tracking-tight">{t('overview.title')}</h1>;
}
