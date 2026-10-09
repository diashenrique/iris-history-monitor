import { expect, test } from '@playwright/test';
import { env } from './support';

// FR-024: the old pages are obsolete but still answer at their address, with a banner pointing to the
// new interface. They live in their own web application, so they ask for their own sign-in.
test.use({ storageState: { cookies: [], origins: [] } });

// Each test here signs in afresh, and IRIS Community has few license units: run them in one project
// only (they do not depend on layout or theme) and end each session afterwards.
// Playwright requires the fixtures argument to be destructured, even when empty.
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop-light', 'sign-in tests run in one project');
});
test.afterEach(async ({ page }) => {
  await page.request.get('/csp/irismonitor/dashboard.csp?IRISLogout=end').catch(() => undefined);
});

test('an old page still answers and points to the new monitor', async ({ page }) => {
  await page.goto('/csp/irismonitor/dashboard.csp');
  await page.locator('input[name="IRISUsername"]').fill(env.viewer.user);
  await page.locator('input[name="IRISPassword"]').fill(env.viewer.password);
  await page.locator('input[name="IRISLogin"]').click();
  const banner = page.getByRole('note');
  await expect(banner).toContainText('This page is obsolete');
  await expect(banner.getByRole('link', { name: 'open the new monitor' })).toHaveAttribute('href', '/historymonitor/index.html');
});
