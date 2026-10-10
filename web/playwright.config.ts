import { defineConfig, devices } from '@playwright/test';

// End-to-end tests run against an IRIS instance with the module installed (research R13).
// HM_BASE_URL points at the interface, for example http://localhost:52773/historymonitor/
const baseURL = process.env.HM_BASE_URL ?? 'http://localhost:52773/historymonitor/';

export default defineConfig({
  testDir: './tests/e2e',
  globalSetup: './tests/e2e/global-setup.ts',
  // One worker and one saved session: IRIS Community has few license units (see global-setup).
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: { baseURL, trace: 'retain-on-failure', storageState: 'tests/e2e/.auth/viewer.json' },
  projects: [
    { name: 'desktop-light', use: { ...devices['Desktop Chrome'], colorScheme: 'light' } },
    { name: 'desktop-dark', use: { ...devices['Desktop Chrome'], colorScheme: 'dark' } },
    { name: 'phone-360', use: { ...devices['Desktop Chrome'], viewport: { width: 360, height: 780 } } },
  ],
});
