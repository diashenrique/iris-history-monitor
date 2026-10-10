// Design tokens: the single source for colours, used by theme.ts (CSS variables) and by the contrast
// test (research R10, FR-019). Every text pair must reach 4.5:1 and every status or control boundary 3:1
// against the surface it sits on, in both themes.

export type ThemeName = 'light' | 'dark';

export interface Palette {
  /** Page background. */
  bg: string;
  /** Cards, panels, table rows. */
  surface: string;
  /** Raised surface: header, menus, dialogs. */
  raised: string;
  /** Main text. */
  text: string;
  /** Secondary text: units, captions, timestamps. */
  muted: string;
  /** Decorative separators (no contrast requirement). */
  divider: string;
  /** Boundaries of inputs, buttons and switches (3:1, WCAG 1.4.11). */
  control: string;
  /** Links, focus ring, selected navigation, primary actions. */
  accent: string;
  /** Text on an accent background. */
  onAccent: string;
  ok: string;
  okSoft: string;
  warning: string;
  warningSoft: string;
  critical: string;
  criticalSoft: string;
  unavailable: string;
  unavailableSoft: string;
  /** Chart series colours, in order. */
  series: readonly string[];
}

export const palettes: Record<ThemeName, Palette> = {
  light: {
    bg: '#f4f6fb',
    surface: '#ffffff',
    raised: '#ffffff',
    text: '#0f172a',
    muted: '#475569',
    divider: '#e2e8f0',
    control: '#64748b',
    accent: '#4338ca',
    onAccent: '#ffffff',
    ok: '#15803d',
    okSoft: '#dcfce7',
    warning: '#854d0e',
    warningSoft: '#fef3c7',
    critical: '#b91c1c',
    criticalSoft: '#fee2e2',
    unavailable: '#57534e',
    unavailableSoft: '#e7e5e4',
    series: ['#4338ca', '#0e7490', '#b45309', '#be185d', '#15803d', '#7c3aed'],
  },
  dark: {
    bg: '#0b1020',
    surface: '#121a2f',
    raised: '#1a2340',
    text: '#e2e8f0',
    muted: '#a3b0c4',
    divider: '#243052',
    control: '#7d8bab',
    accent: '#a5b4fc',
    onAccent: '#0b1020',
    ok: '#4ade80',
    okSoft: '#0f2e1d',
    warning: '#fbbf24',
    warningSoft: '#33260a',
    critical: '#f87171',
    criticalSoft: '#3a1515',
    unavailable: '#c4c0bb',
    unavailableSoft: '#2a2826',
    series: ['#a5b4fc', '#67e8f9', '#fcd34d', '#f9a8d4', '#86efac', '#c4b5fd'],
  },
};

/** CSS custom property name of a palette key: okSoft → --color-ok-soft. */
export function cssVar(key: keyof Palette): string {
  return `--color-${key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`;
}

/** WCAG 2.x relative luminance of a #rrggbb colour. */
export function luminance(hex: string): number {
  const v = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const [r, g, b] = v.map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)) as [
    number,
    number,
    number,
  ];
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG contrast ratio between two #rrggbb colours (1 to 21). */
export function contrast(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x) as [number, number];
  return (hi + 0.05) / (lo + 0.05);
}
