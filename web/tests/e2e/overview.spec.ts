import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';
import { env, outsidePrefix, recordRequests, signIn } from './support';

// User story 1 against a real instance (spec 002 US1 scenarios 1 to 4, SC-002, SC-003, SC-006).

const STATUS_LABEL: Record<string, string> = { ok: 'OK', warning: 'Warning', critical: 'Critical', unavailable: 'Unavailable' };

test('every metric with its status, matching the API, within 2 seconds', async ({ page, baseURL }) => {
  await signIn(page, env.viewer);
  const requests = recordRequests(page);
  const started = Date.now();
  await page.goto('./index.html#/');
  const items = page.locator('[data-metric]');
  await expect(items).toHaveCount(18, { timeout: 2_000 });
  expect(Date.now() - started, 'complete Overview within 2 s (SC-002)').toBeLessThan(2_000);

  const api = await (await page.request.get('./api/v1/overview')).json();
  for (const m of api.metrics as { name: string; status: string; value: unknown; unit: string }[]) {
    const item = page.locator(`[data-metric="${m.name}"]`);
    await expect(item, m.name).toHaveCount(1);
    await expect(item, `${m.name} status`).toHaveAttribute('data-status', m.status);
    if (m.unit === 'text' && typeof m.value === 'string') await expect(item, `${m.name} value`).toContainText(m.value.replace(/\s+/g, ' ').trim());
    if (m.status !== 'ok') await expect(item).toContainText(STATUS_LABEL[m.status]!);
  }
  expect(outsidePrefix(requests, baseURL!), 'every request goes to /historymonitor/ (SC-006)').toEqual([]);
});

test('figures update on their own and show when they were last updated', async ({ page }) => {
  test.setTimeout(60_000);
  await signIn(page, env.viewer);
  const time = page.locator('time[data-updated]');
  const first = await time.getAttribute('dateTime');
  await expect(time).not.toHaveAttribute('dateTime', first!, { timeout: 25_000 });
});

test('a failed refresh keeps the figures, marks them out of date, and recovers', async ({ page }) => {
  test.setTimeout(60_000);
  await signIn(page, env.viewer);
  await expect(page.locator('[data-metric]')).toHaveCount(18);
  await page.route('**/api/v1/overview', (route) => route.abort());
  await expect(page.getByText('Figures out of date.')).toBeVisible({ timeout: 25_000 });
  await expect(page.locator('[data-metric]')).toHaveCount(18);
  await page.unroute('**/api/v1/overview');
  await expect(page.getByText('Figures out of date.')).toBeHidden({ timeout: 25_000 });
});

test('no serious accessibility issue', async ({ page }) => {
  await signIn(page, env.viewer);
  await expect(page.locator('[data-metric]')).toHaveCount(18);
  const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']).analyze();
  const serious = result.violations.filter((v) => v.impact === 'critical' || v.impact === 'serious');
  expect(serious.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`)).toEqual([]);
});

test('no page-level horizontal scroll', async ({ page }) => {
  await signIn(page, env.viewer);
  await expect(page.locator('[data-metric]')).toHaveCount(18);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
