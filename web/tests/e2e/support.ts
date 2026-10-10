import { expect, type Page } from '@playwright/test';
import { execFileSync } from 'node:child_process';

// Environment of the end-to-end run (set by the CI e2e job or by hand; .github/ci/e2e-setup.sh creates
// the users and turns the interface on).
/** Session of the viewer, signed in once by global-setup and reused by every test. */
export const VIEWER_STATE = 'tests/e2e/.auth/viewer.json';

export const env = {
  container: process.env.HM_IRIS_CONTAINER ?? 'iris',
  viewer: { user: 'e2eviewer', password: process.env.HM_VIEWER_PASSWORD ?? '' },
  noRole: { user: 'e2enorole', password: process.env.HM_NOROLE_PASSWORD ?? '' },
};

/** Runs one ObjectScript expression as the instance administrator (docker exec into the container). */
export function iris(expression: string, namespace = 'USER'): string {
  return execFileSync('docker', ['exec', env.container, 'iris', 'session', 'IRIS', '-U', namespace, expression], {
    encoding: 'utf8',
  });
}

export function setInterfaceEnabled(on: boolean): void {
  iris(`##class(diashenrique.historymonitor.util.Settings).SetInterfaceEnabled(${on ? 1 : 0})`);
}

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
