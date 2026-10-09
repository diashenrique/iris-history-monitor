import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './en.json';
import es from './es.json';
import ptBR from './pt-BR.json';

// Languages of the interface (FR-017). The first visit follows the browser, falling back to English;
// a choice is remembered per browser.
export const LANGUAGES = ['en', 'pt-BR', 'es'] as const;
export type Language = (typeof LANGUAGES)[number];

const STORAGE_KEY = 'hm.language';

export const catalogues: Record<Language, object> = { en, 'pt-BR': ptBR, es };

/** Maps a browser language tag to a supported language, or undefined. */
export function matchLanguage(tag: string | undefined): Language | undefined {
  if (!tag) return undefined;
  const lower = tag.toLowerCase();
  if (lower.startsWith('pt')) return 'pt-BR';
  if (lower.startsWith('es')) return 'es';
  if (lower.startsWith('en')) return 'en';
  return undefined;
}

export function detectLanguage(
  storage: Pick<Storage, 'getItem'> | undefined = globalThis.localStorage,
  browser: readonly string[] = globalThis.navigator?.languages ?? [],
): Language {
  try {
    const stored = storage?.getItem(STORAGE_KEY);
    if (stored && (LANGUAGES as readonly string[]).includes(stored)) return stored as Language;
  } catch {
    // Storage can be blocked; fall through to the browser languages.
  }
  for (const tag of browser) {
    const lang = matchLanguage(tag);
    if (lang) return lang;
  }
  return 'en';
}

export function saveLanguage(lang: Language, storage: Pick<Storage, 'setItem'> | undefined = globalThis.localStorage) {
  try {
    storage?.setItem(STORAGE_KEY, lang);
  } catch {
    // The choice then lasts for this page only.
  }
}

export async function setLanguage(lang: Language): Promise<void> {
  saveLanguage(lang);
  document.documentElement.lang = lang;
  await i18n.changeLanguage(lang);
}

export function initI18n(lang: Language = detectLanguage()) {
  if (!i18n.isInitialized) {
    void i18n.use(initReactI18next).init({
      resources: {
        en: { translation: en },
        'pt-BR': { translation: ptBR },
        es: { translation: es },
      },
      lng: lang,
      fallbackLng: 'en',
      interpolation: { escapeValue: false },
      returnNull: false,
    });
  }
  if (typeof document !== 'undefined') document.documentElement.lang = lang;
  return i18n;
}

export default i18n;
