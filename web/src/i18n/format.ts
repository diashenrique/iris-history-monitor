// Numbers, dates and time zones follow the chosen language through Intl (FR-017, FR-018).
// Times are shown in the browser's time zone with its name; the API sends UTC.

export function formatNumber(value: number, lang: string, maximumFractionDigits = 2): string {
  return new Intl.NumberFormat(lang, { maximumFractionDigits }).format(value);
}

/** Short time zone name of the browser, for example "BRT" or "GMT-3". */
export function zoneName(lang: string, at: Date = new Date(), timeZone?: string): string {
  const parts = new Intl.DateTimeFormat(lang, { timeZoneName: 'short', timeZone }).formatToParts(at);
  return parts.find((p) => p.type === 'timeZoneName')?.value ?? '';
}

/** Time of day with seconds, in the browser's zone (or the given one, for tests). */
export function formatTime(at: Date, lang: string, timeZone?: string): string {
  return new Intl.DateTimeFormat(lang, { hour: '2-digit', minute: '2-digit', second: '2-digit', timeZone }).format(at);
}

/** Date and time, in the browser's zone (or the given one, for tests), with the zone name. */
export function formatDateTime(at: Date, lang: string, timeZone?: string): string {
  return new Intl.DateTimeFormat(lang, {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone,
  }).format(at);
}
