import { catalogues, detectLanguage, LANGUAGES, matchLanguage } from '../../src/i18n';
import { formatNumber, formatTime, zoneName } from '../../src/i18n/format';

/** Every leaf key of a catalogue, with plural suffixes removed (languages have different plural forms). */
function keys(obj: object, prefix = ''): Set<string> {
  const out = new Set<string>();
  for (const [k, v] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object') keys(v, path).forEach((x) => out.add(x));
    else out.add(path.replace(/_(zero|one|two|few|many|other)$/, ''));
  }
  return out;
}

describe('translation catalogues (SC-005)', () => {
  const en = keys(catalogues.en);
  it.each(LANGUAGES.filter((l) => l !== 'en'))('%s has exactly the English keys', (lang) => {
    const other = keys(catalogues[lang]);
    expect([...en].filter((k) => !other.has(k)), 'missing').toEqual([]);
    expect([...other].filter((k) => !en.has(k)), 'extra').toEqual([]);
  });

  it.each([...LANGUAGES])('%s has no empty text except unit blanks', (lang) => {
    const empty: string[] = [];
    const walk = (o: object, p: string) => {
      for (const [k, v] of Object.entries(o)) {
        const path = p ? `${p}.${k}` : k;
        if (v && typeof v === 'object') walk(v, path);
        else if (v === '' && !path.startsWith('overview.units.')) empty.push(path);
      }
    };
    walk(catalogues[lang], '');
    expect(empty).toEqual([]);
  });

  it.each([...LANGUAGES])('%s has every plural form the language needs', (lang) => {
    const rules = new Intl.PluralRules(lang).resolvedOptions().pluralCategories;
    const summary = (catalogues[lang] as { summary: Record<string, string> }).summary;
    for (const status of ['critical', 'unavailable', 'warning', 'ok']) {
      for (const form of rules) expect(summary[`${status}_${form}`], `${status}_${form}`).toBeTruthy();
    }
  });
});

describe('language detection (FR-017)', () => {
  const none = { getItem: () => null };
  it('follows the browser', () => {
    expect(detectLanguage(none, ['pt-PT', 'en'])).toBe('pt-BR');
    expect(detectLanguage(none, ['es-AR'])).toBe('es');
  });
  it('falls back to English', () => {
    expect(detectLanguage(none, ['de-DE', 'fr'])).toBe('en');
    expect(detectLanguage(none, [])).toBe('en');
  });
  it('prefers a stored choice', () => {
    expect(detectLanguage({ getItem: () => 'es' }, ['pt-BR'])).toBe('es');
    expect(detectLanguage({ getItem: () => 'xx' }, ['pt-BR'])).toBe('pt-BR');
  });
  it('maps tags', () => {
    expect(matchLanguage('EN-gb')).toBe('en');
    expect(matchLanguage(undefined)).toBeUndefined();
  });
});

describe('formatting follows the language and the time zone (FR-017, FR-018)', () => {
  const at = new Date('2026-10-09T17:05:09Z');
  it('formats numbers per language', () => {
    expect(formatNumber(1234.5, 'en')).toBe('1,234.5');
    expect(formatNumber(1234.5, 'pt-BR')).toBe('1.234,5');
  });
  it('formats times in the given zone', () => {
    expect(formatTime(at, 'en', 'America/Sao_Paulo')).toMatch(/02:05:09\s?PM/);
    expect(formatTime(at, 'pt-BR', 'America/Sao_Paulo')).toBe('14:05:09');
  });
  it('names the zone', () => {
    expect(zoneName('en', at, 'UTC')).toBe('UTC');
    expect(zoneName('pt-BR', at, 'America/Sao_Paulo')).not.toBe('');
  });
});
