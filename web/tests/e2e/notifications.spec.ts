import { expect, test } from '@playwright/test';
import { env, signIn } from './support';

// Spec 005 user stories 1 and 2 against a real instance: turn notifications on from the header, leave the
// Overview, and get one notification when a metric gets worse. The browser's Notification is replaced by a
// recorder (a headless browser shows none), and the overview response is changed after the first reading
// to make one metric critical.

test('turning notifications on and getting one when a metric gets worse', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop-light', 'the behavior does not depend on theme or size');
  test.setTimeout(90_000);

  await page.addInitScript(() => {
    const calls: { title: string; body?: string }[] = [];
    (window as unknown as { recorded: typeof calls }).recorded = calls;
    class RecordingNotification {
      static permission: NotificationPermission = 'default';
      static async requestPermission() {
        RecordingNotification.permission = 'granted';
        return 'granted' as const;
      }
      onclick: (() => void) | null = null;
      constructor(title: string, options?: NotificationOptions) {
        calls.push({ title, body: options?.body });
      }
      close() {}
    }
    (window as unknown as { Notification: unknown }).Notification = RecordingNotification;
  });

  await signIn(page, env.viewer, '#/history?metric=license&granularity=daily&preset=7d');
  await expect(page.locator('#main h1')).toHaveText('History');

  // After the first reading of the watcher, the first metric that is OK becomes critical.
  let readings = 0;
  let changed = '';
  await page.route('**/api/v1/overview', async (route) => {
    const response = await route.fetch();
    const body = await response.json();
    readings += 1;
    if (readings > 1) {
      const target = body.metrics.find((m: { status: string; name: string }) => m.name === changed || m.status === 'ok');
      if (target) {
        changed = target.name;
        target.status = 'critical';
      }
    }
    await route.fulfill({ response, json: body });
  });

  await page.getByRole('button', { name: 'Notifications: off' }).click();
  const dialog = page.getByRole('dialog', { name: 'Notifications' });
  await expect(dialog).toContainText('Hidden tabs are checked about once a minute.');
  await dialog.getByRole('button', { name: 'Turn on' }).click();
  await expect(dialog).toContainText('Notifications are on in this browser.');
  await dialog.getByRole('button', { name: 'Close' }).click();
  await expect(page.getByRole('button', { name: 'Notifications: on' })).toBeVisible();

  const recorded = () => page.evaluate(() => (window as unknown as { recorded: { title: string; body?: string }[] }).recorded);
  await expect.poll(recorded, { timeout: 45_000, intervals: [1000] }).toHaveLength(1);
  const [first] = await recorded();
  expect(first?.title).toBe('IRIS History Monitor');
  expect(first?.body).toMatch(/ is now Critical$/);
});
