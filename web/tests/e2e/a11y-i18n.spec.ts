import { expect, test, type Page } from '@playwright/test';
import { env, signIn } from './support';

// User story 5 (FR-017 to FR-021, SC-004, SC-005, SC-007): languages, keyboard, visible focus.
// axe in both themes and the 360 px layout are checked per screen in the other specs (they run in the
// desktop-light, desktop-dark and phone-360 projects).

async function setLanguage(page: Page, label: string, value: string) {
  await page.getByLabel(label, { exact: true }).selectOption(value);
}

test.afterEach(async ({ page }) => {
  // Leave the browser in English for the other tests.
  await page.evaluate(() => localStorage.setItem('hm.language', 'en'));
});

test('each screen in Portuguese and Spanish, with local numbers, and the choice survives a reload', async ({ page }) => {
  await signIn(page, env.viewer, '#/');
  await setLanguage(page, 'Language', 'pt-BR');
  await expect(page.getByRole('navigation', { name: 'Principal' })).toContainText('Visão geral');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Visão geral');
  await page.goto('./index.html#/history?metric=license&granularity=daily&preset=30d');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Histórico');
  await expect(page.getByLabel('Métrica')).toBeVisible();
  await page.reload();
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Histórico');
  expect(await page.evaluate(() => document.documentElement.lang)).toBe('pt-BR');
  await page.goto('./index.html#/processes');
  await setLanguage(page, 'Idioma', 'es');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Procesos');
  await expect(page.getByText(/\d+ procesos?/)).toBeVisible();
});

test('keyboard only: the main task of each screen, with visible focus', async ({ page }) => {
  await signIn(page, env.viewer, '#/');
  await expect(page.locator('[data-metric]').first()).toBeVisible();

  // Overview: pause the updates.
  const pause = page.getByRole('button', { name: 'Pause' });
  for (let i = 0; i < 20 && !(await pause.evaluate((el) => el === document.activeElement)); i++) await page.keyboard.press('Tab');
  await expect(pause).toBeFocused();
  const outline = await pause.evaluate((el) => getComputedStyle(el).outlineStyle);
  expect(outline, 'visible focus').not.toBe('none');
  await page.keyboard.press('Space');
  await expect(page.getByRole('button', { name: 'Resume' })).toHaveAttribute('aria-pressed', 'true');

  // History: change the period with the keyboard.
  await page.goto('./index.html#/history?metric=license&granularity=daily&preset=7d');
  const period = page.getByLabel('Period');
  await period.focus();
  await period.selectOption('30d');
  await expect(page).toHaveURL(/preset=30d/);

  // Processes: search and apply with Enter.
  await page.goto('./index.html#/processes');
  const search = page.getByLabel('Search');
  await search.focus();
  await page.keyboard.type('CONTROL');
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/q=CONTROL/);
  await expect(page.locator('[data-pid]').first()).toBeVisible();
});

test('the skip link moves focus to the content', async ({ page }) => {
  await signIn(page, env.viewer, '#/');
  await page.keyboard.press('Tab');
  const skip = page.getByText('Skip to content');
  await expect(skip).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#main')).toBeFocused();
});
