import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import './index.css';
import { applyTheme, readAppearance, resolveTheme } from './design/theme';
import { initI18n } from './i18n';

// Apply the theme before the first render so the page never flashes the wrong colours.
applyTheme(resolveTheme(readAppearance()));
initI18n();

const root = document.getElementById('root');
if (root) {
  createRoot(root).render(
    <StrictMode>
      <App />
    </StrictMode>,
  );
}
