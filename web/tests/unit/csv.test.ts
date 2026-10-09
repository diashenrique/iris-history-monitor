import { historyCsv, toCsv } from '../../src/lib/csv';

describe('CSV export (FR-012)', () => {
  it('starts with a UTF-8 BOM and quotes what needs quoting', () => {
    const text = toCsv([['name', 'note'], ['a,b', 'say "hi"'], ['plain', 'line\nbreak']]);
    expect(text.startsWith('﻿')).toBe(true);
    expect(text.slice(1).split('\r\n')).toEqual(['name,note', '"a,b","say ""hi"""', 'plain,"line\nbreak"', '']);
  });

  it('writes history with a UTC and a local time column and one column per series', () => {
    const text = historyCsv(
      [
        { name: 'Avg', points: [{ t: '2026-10-01T03:00:00Z', v: 1.5 }, { t: '2026-10-01T04:00:00Z', v: 2 }] },
        { name: 'Max', points: [{ t: '2026-10-01T04:00:00Z', v: 3 }] },
      ],
      'America/Sao_Paulo',
    );
    const lines = text.slice(1).split('\r\n');
    expect(lines[0]).toBe('time_utc,time_local,Avg,Max');
    expect(lines[1]).toBe('2026-10-01T03:00:00Z,2026-10-01 00:00:00,1.5,');
    expect(lines[2]).toBe('2026-10-01T04:00:00Z,2026-10-01 01:00:00,2,3');
  });
});
