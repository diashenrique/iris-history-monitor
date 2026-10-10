import { applyTheme, readAppearance, resolveTheme, saveAppearance } from '../../src/design/theme';
import { palettes } from '../../src/design/tokens';

function memoryStorage(initial: Record<string, string> = {}) {
  const data = { ...initial };
  return {
    getItem: (k: string) => data[k] ?? null,
    setItem: (k: string, v: string) => {
      data[k] = v;
    },
  };
}

describe('appearance preference', () => {
  it('defaults to system and ignores unknown stored values', () => {
    expect(readAppearance(memoryStorage())).toBe('system');
    expect(readAppearance(memoryStorage({ 'hm.appearance': 'purple' }))).toBe('system');
  });

  it('remembers the choice', () => {
    const s = memoryStorage();
    saveAppearance('dark', s);
    expect(readAppearance(s)).toBe('dark');
  });

  it('survives storage that throws', () => {
    const broken = {
      getItem: () => {
        throw new Error('blocked');
      },
      setItem: () => {
        throw new Error('blocked');
      },
    };
    expect(readAppearance(broken)).toBe('system');
    expect(() => saveAppearance('light', broken)).not.toThrow();
  });

  it('resolves explicit choices without asking the system', () => {
    expect(resolveTheme('light')).toBe('light');
    expect(resolveTheme('dark')).toBe('dark');
  });
});

describe('applyTheme', () => {
  it('writes the palette as CSS variables and marks the theme', () => {
    const root = document.createElement('html');
    applyTheme('dark', root);
    expect(root.dataset.theme).toBe('dark');
    expect(root.style.getPropertyValue('--color-surface')).toBe(palettes.dark.surface);
    expect(root.style.getPropertyValue('--color-ok-soft')).toBe(palettes.dark.okSoft);
    expect(root.style.getPropertyValue('--color-series-1')).toBe(palettes.dark.series[0]);
  });
});
