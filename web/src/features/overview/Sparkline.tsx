import { useTranslation } from 'react-i18next';
import { formatNumber } from '../../i18n/format';
import { REFRESH_MS } from './useOverview';

// The trend of one metric since the screen opened (FR-006), drawn as inline SVG with no chart library
// so the first screen stays light (research R2, R11). Screen readers get the same facts as text.

const W = 300;
const H = 28;

export function Sparkline({ values }: { values: number[] }) {
  const { t, i18n } = useTranslation();
  if (values.length < 2) return null;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const xy = values.map((v, i) => [(i / (values.length - 1)) * (W - 4) + 2, H - 3 - ((v - min) / span) * (H - 8)] as const);
  const line = xy.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
  const last = xy[xy.length - 1]!;
  const area = `${line} L${last[0].toFixed(1)} ${H} L${xy[0]![0].toFixed(1)} ${H} Z`;
  const minutes = Math.max(1, Math.round(((values.length - 1) * REFRESH_MS) / 60_000));
  const label = t('overview.trend', {
    minutes,
    from: formatNumber(values[0]!, i18n.language),
    to: formatNumber(values[values.length - 1]!, i18n.language),
  });
  return (
    <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" role="img" aria-label={label} className="block h-7 w-full">
      <path d={area} fill="var(--color-accent)" fillOpacity={0.1} />
      <path d={line} fill="none" stroke="var(--color-accent)" strokeWidth={1.6} vectorEffect="non-scaling-stroke" />
      <circle cx={last[0]} cy={last[1]} r={2.6} fill="var(--color-accent)" />
    </svg>
  );
}
