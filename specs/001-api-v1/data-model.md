# Data Model: Versioned Read API (v1)

All entities are transient response shapes. Nothing is stored.

## OverviewSnapshot
| Field | Type | Rule |
| --- | --- | --- |
| generatedAt | timestamp (UTC, ISO 8601) | set when the snapshot is built |
| metrics | list of Metric | one entry per name below, never omitted |

### Metric
| Field | Type | Rule |
| --- | --- | --- |
| name | string | one of the fixed names: systemUpTime, lastBackup, lockTable, journalSpace, journalStatus, ecpAppServer, ecpDataServer, writeDaemon, licenseCurrent, licenseCurrentPct, licenseHigh, licenseHighPct, licenseLimit, applicationErrors, cspSessions, cacheEfficiency, processes, seriousAlerts |
| value | string or number or null | null when unavailable |
| unit | string | for example `percent`, `count`, `bytes`, `seconds`, `text` |
| status | enum | `ok`, `warning`, `critical`, `unavailable` |
| reason | string, optional | present only when status is `unavailable` |

State rules (implemented in `service.Overview`, decisions in research.md R8):
- a backup that never ran has status `warning` and a null value;
- state texts: `Normal` and `OK` are `ok`, `Warning` is `warning`, `Troubled` is `critical`, any other text is `warning`;
- `licenseCurrentPct` and `licenseHighPct`: `warning` from 80, `critical` from 95;
- `seriousAlerts` above 0 is `warning`;
- an empty, missing or non-numeric value is `unavailable` with a reason.

## HistorySeries
| Field | Type | Rule |
| --- | --- | --- |
| metric | enum | `license`, `csp-sessions`, `database-size` |
| granularity | enum | `5min`, `hourly`, `daily` |
| from, to | timestamp | the validated request range |
| coverage | object | `first` and `last` timestamp actually present, or null when empty |
| partial | boolean | true when coverage does not span from..to |
| truncated | boolean | true when more points exist than `limit` |
| next | string, optional | cursor for the next page when truncated |
| series | list of Series | |

### Series
| Field | Type | Rule |
| --- | --- | --- |
| name | string | for license and sessions the statistic (for example `Avg`, `Max`); for database size the database name |
| points | list of Point | ascending by time |

### Point
| Field | Type | Rule |
| --- | --- | --- |
| t | timestamp (UTC) | |
| v | number | |

Validation: `from` <= `to`; both parse as dates or datetimes; `limit` 1..5000; `database` matches a
strict name pattern and is only valid for `database-size`.
`cursor`, when present, is the `next` value of a previous page and is validated like `from` and `to`.

Series names, paging and partial rules are in research.md R9: `value` for 5-minute license and CSP
sessions, `Avg` and `Max` for hourly and daily, the database name for database size (Max, in MB);
`limit` counts timestamps; empty values are left out.

## ProcessPage
| Field | Type | Rule |
| --- | --- | --- |
| items | list of Process | |
| total | integer | matches before paging |
| page, pageSize | integer | pageSize 1..500 |
| next | string, optional | |

### Process
Fields come from the `CONTROLPANEL` query the page uses today. Empty values are omitted. The four
capability flags the page already skips (can be examined, suspended, terminated, receive broadcast)
are not returned.

Filters: `namespace`, `user`, `state` from the observed values; `q` is a text match. Sort keys are an
allow-list of the returned fields.

## Problem
`type` (relative URI), `title`, `status` (HTTP), `detail`, optional `errors` list of
`{parameter, message}` for validation failures.
