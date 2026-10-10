import { expect, test } from '@playwright/test';
import { env, signIn } from './support';

// User story 4 (FR-014 to FR-016): one sign-in for every screen, a clean return after the session ends,
// and a clear screen for an account without the monitor role. These tests sign in themselves, in fresh
// contexts, so ending a session here never touches the shared viewer session of the other tests.
test.use({ storageState: { cookies: [], origins: [] } });

// Each test here signs in afresh, and IRIS Community has few license units: run them in one project
// only (they do not depend on layout or theme) and end each session afterwards.
// Playwright requires the fixtures argument to be destructured, even when empty.
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop-light', 'sign-in tests run in one project');
});
test.afterEach(async ({ page }) => {
  await page.request.get('./diashenrique.historymonitor.web.Login.cls?IRISLogout=end').catch(() => undefined);
});

const LOGIN_FIELD = 'input[name="IRISUsername"]';

test('one sign-in covers every screen, in two tabs', async ({ page, context }) => {
  await signIn(page, env.viewer, '#/');
  await expect(page.locator('[data-metric]').first()).toBeVisible();
  for (const route of ['#/history?metric=license&granularity=daily&preset=7d', '#/processes']) {
    await page.goto(`./index.html${route}`);
    await expect(page.locator('#main h1')).toBeVisible();
    await expect(page.locator(LOGIN_FIELD)).toHaveCount(0);
  }
  const second = await context.newPage();
  await second.goto('./index.html#/processes');
  await expect(second.locator('[data-pid]').first()).toBeVisible();
  await expect(second.locator(LOGIN_FIELD)).toHaveCount(0);
});

test('after the session ends, the next action asks to sign in and returns to the same view', async ({ page }) => {
  test.setTimeout(90_000);
  const route = '#/processes?namespace=%25SYS';
  await signIn(page, env.viewer, route);
  await expect(page.locator('[data-pid]').first()).toBeVisible();
  // End the IRIS session the way a timeout or a logout would.
  await page.request.get('./diashenrique.historymonitor.web.Login.cls?IRISLogout=end');
  // The process list refreshes every 15 s; that request now gets 401 and the interface goes to sign-in.
  await expect(page.locator(LOGIN_FIELD)).toBeVisible({ timeout: 30_000 });
  await page.locator(LOGIN_FIELD).fill(env.viewer.user);
  await page.locator('input[name="IRISPassword"]').fill(env.viewer.password);
  await page.locator('input[name="IRISLogin"]').click();
  await expect(page.locator('[data-pid]').first()).toBeVisible();
  expect(new URL(page.url()).hash).toBe(route);
});

test('an account without the role sees no-access naming the role, and no data', async ({ page }) => {
  await signIn(page, env.noRole, '#/');
  await expect(page.getByRole('heading', { name: 'You do not have access to the monitor' })).toBeVisible();
  await expect(page.getByText(/HistoryMonitorViewer/)).toBeVisible();
  await expect(page.locator('[data-metric]')).toHaveCount(0);
});
