import { expect, test } from '@playwright/test';
import { env } from './support';

// Spec 003 user story 1 (FR-002, SC-001; contracts/forwarding.md): every old address leads to the
// matching screen of the new monitor, signed in or not.

const ROWS: Array<[string, string, string | null]> = [
  ['/csp/irismonitor/dashboard.csp', 'Overview', null],
  ['/csp/irismonitor/historylicense.csp', 'History', 'license'],
  ['/csp/irismonitor/historycspsessions.csp', 'History', 'csp-sessions'],
  ['/csp/irismonitor/historydatabase.csp', 'History', 'database-size'],
  ['/csp/irismonitor/systemprocesses.csp', 'Processes', null],
  ['/csp/irismonitor/no-such-page.csp?x=1', 'Overview', null],
];

test.describe('signed in', () => {
  // The old addresses do not depend on layout or theme.
  // eslint-disable-next-line no-empty-pattern
  test.beforeEach(({}, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop-light', 'one project is enough');
  });

  for (const [from, heading, metric] of ROWS) {
    test(`${from} opens ${heading}${metric ? ` (${metric})` : ''}`, async ({ page }) => {
      await page.goto(from);
      await expect(page).toHaveURL(/\/historymonitor\/index\.html#\//);
      await expect(page.getByRole('heading', { level: 1 })).toHaveText(heading);
      if (metric) await expect(page.getByLabel('Metric')).toHaveValue(metric);
    });
  }

  test('no screen links to the old pages (spec 003 FR-007, SC-004)', async ({ page }) => {
    for (const route of ['#/', '#/history?metric=license&granularity=daily&preset=7d', '#/processes']) {
      await page.goto(`/historymonitor/index.html${route}`);
      await expect(page.locator('#main h1')).toBeVisible();
      const hrefs = await page.locator('a[href]').evaluateAll((links) => links.map((a) => a.getAttribute('href') ?? ''));
      expect(hrefs.filter((h) => h.includes('/csp/irismonitor')), route).toEqual([]);
    }
  });
});

test.describe('signed out', () => {
  test.use({ storageState: { cookies: [], origins: [] } });
  // eslint-disable-next-line no-empty-pattern
  test.beforeEach(({}, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop-light', 'sign-in tests run in one project');
  });
  test.afterEach(async ({ page }) => {
    await page.request
      .get('/historymonitor/diashenrique.historymonitor.web.Login.cls?IRISLogout=end')
      .catch(() => undefined);
  });

  test('an old history address asks to sign in, then shows History on that metric', async ({ page }) => {
    await page.goto('/csp/irismonitor/historylicense.csp');
    await page.locator('input[name="IRISUsername"]').fill(env.viewer.user);
    await page.locator('input[name="IRISPassword"]').fill(env.viewer.password);
    await page.locator('input[name="IRISLogin"]').click();
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('History');
    await expect(page.getByLabel('Metric')).toHaveValue('license');
  });
});
