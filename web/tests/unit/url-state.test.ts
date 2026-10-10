import {
  HISTORY_DEFAULTS,
  parseHistory,
  parseProcesses,
  presetRange,
  PROCESS_DEFAULTS,
  serializeHistory,
  serializeProcesses,
} from '../../src/lib/url-state';

describe('history address state (FR-013, contracts/ui-routes.md)', () => {
  it('has the documented defaults', () => {
    expect(parseHistory('')).toEqual({ value: HISTORY_DEFAULTS, invalid: [] });
    expect(HISTORY_DEFAULTS).toMatchObject({ metric: 'license', granularity: 'hourly', preset: '7d' });
  });

  it('round-trips a preset view and a custom range', () => {
    const preset = parseHistory('metric=csp-sessions&granularity=daily&preset=90d').value;
    expect(parseHistory(serializeHistory(preset)).value).toEqual(preset);
    const custom = parseHistory('metric=license&granularity=5min&from=2026-10-01T00:00:00Z&to=2026-10-02T12:30Z').value;
    expect(custom).toMatchObject({ preset: null, from: '2026-10-01T00:00:00Z', to: '2026-10-02T12:30Z' });
    expect(parseHistory(serializeHistory(custom)).value).toEqual(custom);
  });

  it('keeps databases only for database size, without duplicates', () => {
    const q = parseHistory('metric=database-size&db=USER&db=IRISLIB&db=USER').value;
    expect(q.databases).toEqual(['USER', 'IRISLIB']);
    expect(parseHistory(serializeHistory(q)).value.databases).toEqual(['USER', 'IRISLIB']);
    expect(parseHistory('metric=license&db=USER')).toMatchObject({ value: { databases: [] }, invalid: ['db'] });
  });

  it('replaces invalid values with defaults and names them', () => {
    const r = parseHistory('metric=cpu&granularity=weekly&preset=1y');
    expect(r.value).toEqual(HISTORY_DEFAULTS);
    expect(r.invalid).toEqual(['metric', 'granularity', 'preset']);
    expect(parseHistory('from=2026-10-02T00:00:00Z&to=2026-10-01T00:00:00Z').invalid).toEqual(['from', 'to']);
    expect(parseHistory('from=yesterday&to=today').value.preset).toBe('7d');
    expect(parseHistory('metric=database-size&db=bad%20name').invalid).toEqual(['db']);
  });

  it('computes preset ranges in UTC', () => {
    const now = new Date('2026-10-09T12:00:00Z');
    expect(presetRange('24h', now)).toEqual({ from: '2026-10-08T12:00:00Z', to: '2026-10-09T12:00:00Z' });
    expect(presetRange('90d', now).from).toBe('2026-07-11T12:00:00Z');
  });
});

describe('process address state', () => {
  it('has the documented defaults and keeps the address short', () => {
    expect(parseProcesses('')).toEqual({ value: PROCESS_DEFAULTS, invalid: [] });
    expect(serializeProcesses(PROCESS_DEFAULTS)).toBe('');
  });

  it('round-trips filters, sort and paging', () => {
    const q = parseProcesses('namespace=%25SYS&user=alice&q=Orders&sort=-cpuTime&page=3&pageSize=25').value;
    expect(q).toEqual({ namespace: '%SYS', user: 'alice', state: '', q: 'Orders', sort: '-cpuTime', page: 3, pageSize: 25 });
    expect(parseProcesses(serializeProcesses(q)).value).toEqual(q);
  });

  it('rejects values the API would refuse', () => {
    const long = 'x'.repeat(101);
    const r = parseProcesses(`q=${long}&sort=password&page=0&pageSize=500&namespace=US%0AER`);
    expect(r.value).toEqual(PROCESS_DEFAULTS);
    expect(r.invalid.sort()).toEqual(['namespace', 'page', 'pageSize', 'q', 'sort']);
  });
});
