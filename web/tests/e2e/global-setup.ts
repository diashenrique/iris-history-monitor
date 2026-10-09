import type { FullConfig } from '@playwright/test';

// The IRIS side is prepared by .github/ci/e2e-setup.sh; here we only check it answers and that the
// passwords of the test users were given.
export default async function globalSetup(config: FullConfig) {
  const base = config.projects[0]?.use.baseURL;
  if (!base) throw new Error('HM_BASE_URL is not set');
  if (!process.env.HM_VIEWER_PASSWORD || !process.env.HM_NOROLE_PASSWORD) {
    throw new Error('Set HM_VIEWER_PASSWORD and HM_NOROLE_PASSWORD (see .github/ci/e2e-setup.sh)');
  }
  const response = await fetch(new URL('index.html', base));
  if (!response.ok) throw new Error(`${base}index.html answered ${response.status}`);
}
