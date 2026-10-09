import { expect, test } from '@playwright/test';
import { env, setInterfaceEnabled, signIn } from './support';

// FR-002 and the spec edge case "turned off while a user has it open". These tests change the
// instance-wide switch, so they run one at a time and leave it on.
test.describe.configure({ mode: 'serial' });

test.afterAll(() => setInterfaceEnabled(true));

test('switched off: explains it and links to the old pages', async ({ page }) => {
  setInterfaceEnabled(false);
  await signIn(page, env.viewer);
  await expect(page.getByRole('heading', { name: 'The new monitor is not turned on' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Open the existing pages' })).toHaveAttribute(
    'href',
    '/csp/irismonitor/dashboard.csp',
  );
});

test('switched off while open: the open screen changes within a minute', async ({ page }) => {
  test.setTimeout(120_000);
  setInterfaceEnabled(true);
  await signIn(page, env.viewer);
  await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
  setInterfaceEnabled(false);
  await expect(page.getByRole('heading', { name: 'The new monitor is not turned on' })).toBeVisible({
    timeout: 70_000,
  });
});
