import { cssVar, palettes, type Palette, type ThemeName } from './tokens';

// Appearance preference (FR-020): follows the operating system by default, remembered per browser.
export type Appearance = 'system' | ThemeName;

const STORAGE_KEY = 'hm.appearance';

export function readAppearance(storage: Pick<Storage, 'getItem'> = localStorage): Appearance {
  try {
    const v = storage.getItem(STORAGE_KEY);
    return v === 'light' || v === 'dark' || v === 'system' ? v : 'system';
  } catch {
    return 'system';
  }
}

export function saveAppearance(value: Appearance, storage: Pick<Storage, 'setItem'> = localStorage): void {
  try {
    storage.setItem(STORAGE_KEY, value);
  } catch {
    // Private windows can refuse storage; the choice then lasts for this page only.
  }
}

export function systemTheme(): ThemeName {
  return typeof matchMedia === 'function' && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function resolveTheme(appearance: Appearance): ThemeName {
  return appearance === 'system' ? systemTheme() : appearance;
}

/** Writes the palette as CSS variables on <html> and marks the theme for CSS and charts. */
export function applyTheme(theme: ThemeName, root: HTMLElement = document.documentElement): void {
  const p: Palette = palettes[theme];
  for (const key of Object.keys(p) as (keyof Palette)[]) {
    const value = p[key];
    if (typeof value === 'string') root.style.setProperty(cssVar(key), value);
  }
  p.series.forEach((c, i) => root.style.setProperty(`--color-series-${i + 1}`, c));
  root.dataset.theme = theme;
  root.style.colorScheme = theme;
}
