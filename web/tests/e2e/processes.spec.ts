import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';
import { env, outsidePrefix, recordRequests, signIn } from './support';

// User story 3 against a real instance (spec 002 US3 scenarios 1 to 3, SC-003, SC-006).

test('a filtered, sorted page equals the API', async ({ page, baseURL }) => {
  const requests = recordRequests(page);
  await signIn(page, env.viewer, '#/processes?namespace=%25SYS&sort=job&pageSize=25');
  const rows = page.getByRole('table').getByRole('row');
  await expect(rows.nth(1)).toBeVisible();
  const api = await (await page.request.get('./api/v1/processes?namespace=%25SYS&sort=job&page=1&pageSize=25')).json();
  // Long-lived system processes keep their place; compare the first ones by pid.
  const shownPids = await page.locator('[data-pid]').evaluateAll((els) => els.slice(0, 5).map((e) => e.getAttribute('data-pid')));
  expect(shownPids).toEqual(api.items.slice(0, 5).map((p: { pid: number }) => String(p.pid)));
  await expect(page.getByText(new RegExp(`${api.total} processes`))).toBeVisible();
  expect(outsidePrefix(requests, baseURL!), 'every request goes to /historymonitor/ (SC-006)').toEqual([]);
});

test('open one process', async ({ page }) => {
  await signIn(page, env.viewer, '#/processes?sort=job');
  const first = page.locator('[data-pid]').first();
  const pid = await first.getAttribute('data-pid');
  await page.getByRole('button', { name: `Details of process ${pid}` }).click();
  await expect(page.getByRole('dialog', { name: `Process ${pid}` })).toBeVisible();
  await expect(page).toHaveURL(new RegExp(`#/processes/${pid}`));
});

test('export the shown page', async ({ page }) => {
  await signIn(page, env.viewer, '#/processes?pageSize=25');
  await expect(page.locator('[data-pid]').first()).toBeVisible();
  const [download] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Export CSV' }).click()]);
  expect(download.suggestedFilename()).toMatch(/\.csv$/);
});

test('no serious accessibility issue', async ({ page }) => {
  await signIn(page, env.viewer, '#/processes');
  await expect(page.locator('[data-pid]').first()).toBeVisible();
  const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']).analyze();
  const serious = result.violations.filter((v) => v.impact === 'critical' || v.impact === 'serious');
  expect(serious.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`)).toEqual([]);
});

test('no page-level horizontal scroll', async ({ page }) => {
  await signIn(page, env.viewer, '#/processes');
  await expect(page.locator('[data-pid]').first()).toBeVisible();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
