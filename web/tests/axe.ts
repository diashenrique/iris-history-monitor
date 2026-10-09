import axe from 'axe-core';
import { expect } from 'vitest';

/** Fails the test when axe finds a critical or serious WCAG 2.x A/AA issue in the container. */
export async function expectNoSeriousAxeIssues(container: Element): Promise<void> {
  const result = await axe.run(container, {
    runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] },
    // jsdom does not lay out or paint, so contrast is checked by the contrast test and in e2e.
    rules: { 'color-contrast': { enabled: false } },
  });
  const serious = result.violations.filter((v) => v.impact === 'critical' || v.impact === 'serious');
  expect(serious.map((v) => `${v.id}: ${v.help}`)).toEqual([]);
}
