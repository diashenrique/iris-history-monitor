import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { NavLink } from 'react-router';
import { Select } from '../design/components';
import { applyTheme, readAppearance, resolveTheme, saveAppearance, type Appearance } from '../design/theme';
import { LANGUAGES, setLanguage, type Language } from '../i18n';
import { SCREENS } from './routes';

export function Header() {
  const { t, i18n } = useTranslation();
  const [appearance, setAppearanceState] = useState<Appearance>(() => readAppearance());

  function changeAppearance(value: Appearance) {
    setAppearanceState(value);
    saveAppearance(value);
    applyTheme(resolveTheme(value));
  }

  return (
    <header className="sticky top-[env(safe-area-inset-top,0px)] z-10 border-b border-divider bg-raised">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-5 gap-y-2 px-4 py-2.5">
        <div className="flex items-center gap-2.5 font-semibold tracking-tight">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true" className="text-accent">
            <path d="M3 12h4l2.5-6 4 12 2.5-6H21" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span>
            {t('app.name')} <small className="font-medium text-muted">{t('app.product')}</small>
          </span>
        </div>
        <nav aria-label={t('nav.main')} className="max-sm:w-full">
          <ul className="flex gap-1">
            {SCREENS.filter((s) => s.available).map((s) => (
              <li key={s.path}>
                <NavLink
                  to={s.path}
                  end={s.path === '/'}
                  className={({ isActive }) =>
                    `block rounded-lg px-3 py-1.5 font-medium no-underline ${
                      isActive ? 'bg-accent/15 text-accent' : 'text-muted hover:text-text'
                    }`
                  }
                >
                  {t(s.label)}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>
        <div className="ml-auto flex items-center gap-2 max-sm:ml-0 max-sm:w-full max-sm:justify-between">
          <Select
            label={t('language.label')}
            hideLabel
            value={i18n.language}
            onChange={(e) => void setLanguage(e.target.value as Language)}
          >
            {LANGUAGES.map((l) => (
              <option key={l} value={l}>
                {t(`language.${l}`)}
              </option>
            ))}
          </Select>
          <Select
            label={t('appearance.label')}
            hideLabel
            value={appearance}
            onChange={(e) => changeAppearance(e.target.value as Appearance)}
          >
            {(['system', 'light', 'dark'] as const).map((a) => (
              <option key={a} value={a}>
                {t(`appearance.${a}`)}
              </option>
            ))}
          </Select>
        </div>
      </div>
    </header>
  );
}
