import { expect, type Page } from '@playwright/test';

// Environment of the end-to-end run (set by the CI e2e job or by hand; .github/ci/e2e-setup.sh creates
// the users).
/** Session of the viewer, signed in once by global-setup and reused by every test. */
export const VIEWER_STATE = 'tests/e2e/.auth/viewer.json';

export const env = {
  viewer: { user: 'e2eviewer', password: process.env.HM_VIEWER_PASSWORD ?? '' },
  noRole: { user: 'e2enorole', password: process.env.HM_NOROLE_PASSWORD ?? '' },
};

/**
 * Opens the interface at `route`. A page in the viewer's saved session goes straight in; otherwise (or for
 * another user, in a fresh context) it signs in through the IRIS login form (research R5).
 */
export async function signIn(page: Page, who: { user: string; password: string }, route = '#/'): Promise<void> {
  await page.goto(`./index.html${route}`);
  const username = page.locator('input[name="IRISUsername"]');
  const main = page.locator('#main');
  await expect(username.or(main).first()).toBeVisible({ timeout: 15_000 });
  if (await username.isVisible()) {
    await username.fill(who.user);
    await page.locator('input[name="IRISPassword"]').fill(who.password);
    await page.locator('input[name="IRISLogin"]').click();
  }
  await expect(main).toBeVisible({ timeout: 15_000 });
}

/** Collects every request the page makes, to prove the interface reads only its own prefix (SC-006). */
export function recordRequests(page: Page): string[] {
  const urls: string[] = [];
  page.on('request', (r) => urls.push(r.url()));
  return urls;
}

export function outsidePrefix(urls: string[], base: string): string[] {
  const prefix = new URL(base).pathname;
  return urls.filter((u) => {
    const url = new URL(u);
    return url.protocol !== 'data:' && !(url.origin === new URL(base).origin && url.pathname.startsWith(prefix));
  });
}
