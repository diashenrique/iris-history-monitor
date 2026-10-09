import { chromium, type FullConfig } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { env, VIEWER_STATE } from './support';

// The IRIS side is prepared by .github/ci/e2e-setup.sh. Here: check it answers, then sign the viewer in
// once and keep the session for every test. IRIS Community has few license units, and a new sign-in per
// test made it answer "Service Unavailable".
export default async function globalSetup(config: FullConfig) {
  const base = config.projects[0]?.use.baseURL;
  if (!base) throw new Error('HM_BASE_URL is not set');
  if (!process.env.HM_VIEWER_PASSWORD || !process.env.HM_NOROLE_PASSWORD) {
    throw new Error('Set HM_VIEWER_PASSWORD and HM_NOROLE_PASSWORD (see .github/ci/e2e-setup.sh)');
  }
  const response = await fetch(new URL('index.html', base));
  if (!response.ok) throw new Error(`${base}index.html answered ${response.status}`);

  const browser = await chromium.launch();
  const page = await browser.newPage({ baseURL: base });
  await page.goto('./index.html#/');
  await page.locator('input[name="IRISUsername"]').fill(env.viewer.user);
  await page.locator('input[name="IRISPassword"]').fill(env.viewer.password);
  await page.locator('input[name="IRISLogin"]').click();
  await page.locator('#main').waitFor();
  mkdirSync(dirname(VIEWER_STATE), { recursive: true });
  await page.context().storageState({ path: VIEWER_STATE });
  await browser.close();
}
