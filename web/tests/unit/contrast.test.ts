import { contrast, palettes, type Palette, type ThemeName } from '../../src/design/tokens';

// WCAG 2.2 AA: 4.5:1 for text (1.4.3), 3:1 for status marks and control boundaries (1.4.11).
const TEXT = 4.5;
const NON_TEXT = 3;

type Pair = [fg: keyof Palette, bg: keyof Palette, min: number];

const pairs: Pair[] = [
  ['text', 'bg', TEXT],
  ['text', 'surface', TEXT],
  ['text', 'raised', TEXT],
  ['muted', 'bg', TEXT],
  ['muted', 'surface', TEXT],
  ['muted', 'raised', TEXT],
  ['accent', 'surface', TEXT],
  ['accent', 'bg', TEXT],
  ['onAccent', 'accent', TEXT],
  ['control', 'surface', NON_TEXT],
  ['control', 'bg', NON_TEXT],
  // Status labels are text, so they need 4.5:1 on the surface and on their own soft background.
  ['ok', 'surface', TEXT],
  ['ok', 'okSoft', TEXT],
  ['warning', 'surface', TEXT],
  ['warning', 'warningSoft', TEXT],
  ['critical', 'surface', TEXT],
  ['critical', 'criticalSoft', TEXT],
  ['unavailable', 'surface', TEXT],
  ['unavailable', 'unavailableSoft', TEXT],
];

describe.each(['light', 'dark'] as ThemeName[])('%s theme contrast', (theme) => {
  const p = palettes[theme];
  it.each(pairs)('%s on %s reaches %d:1', (fg, bg, min) => {
    const ratio = contrast(p[fg] as string, p[bg] as string);
    expect(ratio, `${fg} ${p[fg]} on ${bg} ${p[bg]} is ${ratio.toFixed(2)}:1`).toBeGreaterThanOrEqual(min);
  });

  it('every chart series is visible on the surface (3:1)', () => {
    for (const c of p.series) expect(contrast(c, p.surface), c).toBeGreaterThanOrEqual(NON_TEXT);
  });
});

it('computes known WCAG ratios', () => {
  expect(contrast('#000000', '#ffffff')).toBeCloseTo(21, 5);
  expect(contrast('#777777', '#ffffff')).toBeCloseTo(4.48, 2);
});
