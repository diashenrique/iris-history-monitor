import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';
import { env, outsidePrefix, recordRequests, signIn } from './support';

// User story 2 against a real instance with 90 days of demo history (spec 002 US2 scenarios 1 to 6,
// SC-002, SC-003, SC-006).

test('90 days hourly license: chart and table appear within 3 s and the points equal the API', async ({ page, baseURL }) => {
  await signIn(page, env.viewer, '#/');
  const requests = recordRequests(page);
  const started = Date.now();
  await page.goto('./index.html#/history?metric=license&granularity=hourly&preset=90d');
  await expect(page.locator('[data-chart] canvas, [data-chart] svg').first()).toBeVisible({ timeout: 3_000 });
  await expect(page.getByRole('table')).toBeVisible({ timeout: 3_000 });
  expect(Date.now() - started, '90-day view within 3 s (SC-002)').toBeLessThan(3_000);

  const total = await page.locator('[data-points]').getAttribute('data-points');
  const from = new URL(page.url()).hash;
  expect(from).toContain('preset=90d');
  const range = await page.locator('[data-range]').getAttribute('data-range');
  const [f, t] = range!.split('/');
  const api = await (await page.request.get(`./api/v1/history/license?granularity=hourly&from=${f}&to=${t}&limit=5000`)).json();
  expect(Number(total)).toBe(api.series[0].points.length);
  expect(outsidePrefix(requests, baseURL!), 'every request goes to /historymonitor/ (SC-006)').toEqual([]);
});

test('the address restores the view', async ({ page }) => {
  await signIn(page, env.viewer, '#/history?metric=csp-sessions&granularity=daily&preset=30d');
  await expect(page.getByLabel('Metric')).toHaveValue('csp-sessions');
  await expect(page.getByLabel('Granularity')).toHaveValue('daily');
  await expect(page.getByLabel('Period')).toHaveValue('30d');
});

test('database size: choose databases', async ({ page }) => {
  await signIn(page, env.viewer, '#/history?metric=database-size&granularity=daily&preset=30d');
  const user = page.getByRole('checkbox', { name: 'USER' });
  await expect(user).toBeVisible();
  await user.check();
  await expect(page).toHaveURL(/db=USER/);
  await expect(page.getByRole('table').getByRole('columnheader')).toHaveCount(2);
});

test('a period without data says so', async ({ page }) => {
  await signIn(page, env.viewer, '#/history?metric=license&granularity=daily&from=2001-01-01T00:00:00Z&to=2001-01-31T00:00:00Z');
  await expect(page.getByText('No data for this period.')).toBeVisible();
});

test('no serious accessibility issue', async ({ page }) => {
  await signIn(page, env.viewer, '#/history?metric=license&granularity=daily&preset=30d');
  await expect(page.getByRole('table')).toBeVisible();
  const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']).analyze();
  const serious = result.violations.filter((v) => v.impact === 'critical' || v.impact === 'serious');
  expect(serious.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`)).toEqual([]);
});

test('no page-level horizontal scroll', async ({ page }) => {
  await signIn(page, env.viewer, '#/history?metric=database-size&granularity=daily&preset=30d');
  await expect(page.getByRole('table')).toBeVisible();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
