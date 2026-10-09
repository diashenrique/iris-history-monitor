import { expect, test } from '@playwright/test';
import { env, signIn } from './support';

// The Content-Security-Policy the README recommends for the interface's static files (index.html and
// assets/). IRIS does not send it; a web server in front of IRIS does. This test serves the files with the
// header and fails on any violation, so the interface keeps working under it.
// The IRIS sign-in page (web.Login.cls) is not covered: the IRIS login form uses inline script and style.
export const RECOMMENDED_CSP = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data:",
  "font-src 'self'",
  "connect-src 'self'",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
].join('; ');

test('every screen works under the recommended Content-Security-Policy', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop-light', 'one browser is enough; the policy does not depend on theme or size');
  await page.route(/\/historymonitor\/(index\.html|assets\/)/, async (route) => {
    const response = await route.fetch();
    await route.fulfill({ response, headers: { ...response.headers(), 'content-security-policy': RECOMMENDED_CSP } });
  });
  await page.addInitScript(() => {
    (window as unknown as { cspViolations: string[] }).cspViolations = [];
    document.addEventListener('securitypolicyviolation', (e) =>
      (window as unknown as { cspViolations: string[] }).cspViolations.push(`${e.violatedDirective} ${e.blockedURI}`),
    );
  });
  const violations = () => page.evaluate(() => (window as unknown as { cspViolations: string[] }).cspViolations);
  const all: string[] = [];

  await signIn(page, env.viewer, '#/');
  await expect(page.locator('[data-metric]').first()).toBeVisible();
  await page.getByLabel('Appearance', { exact: true }).selectOption('dark');
  await page.getByLabel('Appearance', { exact: true }).selectOption('system');
  all.push(...(await violations()).map((v) => `${page.url().split("#")[1]} ${v}`));

  await page.goto('./index.html#/history?metric=license&granularity=hourly&preset=7d');
  await page.reload();
  await expect(page.locator('[data-chart] svg').first()).toBeVisible({ timeout: 15_000 });
  all.push(...(await violations()).map((v) => `${page.url().split("#")[1]} ${v}`));

  await page.goto('./index.html#/processes?sort=job');
  await page.reload();
  const pid = await page.locator('[data-pid]').first().getAttribute('data-pid');
  await page.getByRole('button', { name: `Details of process ${pid}` }).click();
  await expect(page.getByRole('dialog', { name: `Process ${pid}` })).toBeVisible();
  all.push(...(await violations()).map((v) => `${page.url().split("#")[1]} ${v}`));

  expect(all, 'Content-Security-Policy violations').toEqual([]);
});
