import type { Metric, Status } from '../../src/api/types';
import { availability } from '../../src/features/notifications/availability';
import { notificationBody } from '../../src/features/notifications/body';
import { DEDUPE_MS, markNotified, shouldNotify } from '../../src/features/notifications/dedupe';
import { worseTransitions } from '../../src/features/notifications/transitions';
import '../i18n-test';

// Spec 005 FR-003, FR-005, FR-006 and research R3, R5, R7: the rules, without any browser or timer.

const m = (name: string, status: Status): Metric => ({ name, value: null, unit: '', status });
const states = (pairs: [string, Status][]) => new Map<string, Status>(pairs);

describe('worseTransitions (FR-005, R3)', () => {
  it.each([
    ['ok', 'warning'],
    ['ok', 'critical'],
    ['warning', 'critical'],
  ] as [Status, Status][])('%s -> %s notifies', (from, to) => {
    expect(worseTransitions(states([['licenseUse', from]]), [m('licenseUse', to)])).toEqual([{ metric: 'licenseUse', from, to }]);
  });

  it.each([
    ['ok', 'ok'],
    ['warning', 'warning'],
    ['critical', 'critical'],
    ['critical', 'warning'],
    ['warning', 'ok'],
    ['unavailable', 'warning'],
    ['unavailable', 'critical'],
    ['ok', 'unavailable'],
    ['warning', 'unavailable'],
  ] as [Status, Status][])('%s -> %s does not notify', (from, to) => {
    expect(worseTransitions(states([['licenseUse', from]]), [m('licenseUse', to)])).toEqual([]);
  });

  it('the first reading and a new metric only set the baseline', () => {
    expect(worseTransitions(null, [m('licenseUse', 'critical')])).toEqual([]);
    expect(worseTransitions(states([['a', 'ok']]), [m('a', 'ok'), m('b', 'critical')])).toEqual([]);
  });

  it('several worse metrics in one reading are all returned', () => {
    const before = states([['a', 'ok'], ['b', 'warning'], ['c', 'ok']]);
    expect(worseTransitions(before, [m('a', 'warning'), m('b', 'critical'), m('c', 'ok')]).map((t) => t.metric)).toEqual(['a', 'b']);
  });
});

describe('availability (FR-003, R7)', () => {
  it('insecure first, then unsupported, then the permission', () => {
    expect(availability({ isSecureContext: false, Notification: { permission: 'granted' } })).toBe('insecure');
    expect(availability({ isSecureContext: true })).toBe('unsupported');
    expect(availability({ isSecureContext: true, Notification: { permission: 'denied' } })).toBe('denied');
    expect(availability({ isSecureContext: true, Notification: { permission: 'default' } })).toBe('default');
    expect(availability({ isSecureContext: true, Notification: { permission: 'granted' } })).toBe('granted');
  });
});

describe('one notification per transition in a browser (FR-006, R5)', () => {
  beforeEach(() => localStorage.clear());

  it('drops the same metric and state within the window, accepts it after or for another state', () => {
    const t0 = 1_000_000;
    expect(shouldNotify('licenseUse', 'warning', t0)).toBe(true);
    markNotified('licenseUse', 'warning', t0);
    expect(shouldNotify('licenseUse', 'warning', t0 + 1000)).toBe(false);
    expect(shouldNotify('licenseUse', 'critical', t0 + 1000)).toBe(true);
    expect(shouldNotify('licenseUse', 'warning', t0 + DEDUPE_MS + 1)).toBe(true);
  });

  it('works when storage throws', () => {
    const get = vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    const set = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    expect(shouldNotify('a', 'warning', 1)).toBe(true);
    expect(() => markNotified('a', 'warning', 1)).not.toThrow();
    get.mockRestore();
    set.mockRestore();
  });
});

describe('notification text (contract)', () => {
  it('one transition names the metric and its state; several are counted and listed', () => {
    expect(notificationBody([{ metric: 'licenseCurrentPct', from: 'ok', to: 'warning' }])).toBe('License use is now Warning');
    expect(
      notificationBody([
        { metric: 'licenseCurrentPct', from: 'ok', to: 'warning' },
        { metric: 'journalSpace', from: 'warning', to: 'critical' },
      ]),
    ).toBe('2 metrics got worse: License use (Warning), Journal space (Critical)');
  });
});
