# Data model: History collection health

Nothing is stored. Two read-only values, built per request by `service.Collection`.

## Collection state
| Field | Source (research R2) | Rule |
| --- | --- | --- |
| configured | `%Monitor.ItemGroup` `%Monitor||%Monitor.System.HistorySys`.`Activated` | 1 or 0 |
| intervalSeconds | same row, `SampInterval` | default 300 |
| running | a `%MONAPP` process exists | boolean |
| lastSample | `MAX(ZDATE, ZTIME)` of `SYS_History.SysData` | UTC |
| state | derived | `off` if not configured; else `stale` if lastSample is null or older than 3 × interval; else `recording` |

`Decide(configured, lastKey, nowKey, interval)` is a pure class method so every branch is unit-tested.

## Retention
| Granularity | Source | Value |
| --- | --- | --- |
| `5min` | `SYS.History.PerfData.SetPurge("")` | days (default 7) |
| `hourly` | `SYS.History.Hourly.SetPurge("")` | days (default 60) |
| `daily` | none (never purged automatically) | `indefinite` |

A read that fails gives `kind: unknown`.
