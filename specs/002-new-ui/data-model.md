# Data Model: New Monitor Interface

The interface stores nothing on the server except the instance switch. Response shapes come from the API
contract (`specs/001-api-v1/contracts/openapi.yaml` plus `contracts/api-v1-changes.md`); this file
describes the client-side state built from them.

## InterfaceSettings (server, the only new stored value)
| Field | Type | Rule |
| --- | --- | --- |
| interfaceEnabled | boolean | default false; changed only by an administrator (`%Admin_Manage:USE`) |

Read by every viewer through `GET /settings`. Written by `util.Settings.SetInterfaceEnabled`.

## OverviewState (client, memory only)
| Field | Type | Rule |
| --- | --- | --- |
| snapshot | OverviewSnapshot | last successful response |
| lastSuccessAt | timestamp | time of that response |
| stale | boolean | true after a failed refresh, false after the next success |
| paused | boolean | user choice; polling also stops while the tab is hidden |
| trend | map metric name → list of (time, value) | numeric metrics only, last 60 values, cleared on reload |

Display order: status `critical`, `unavailable`, `warning`, then `ok`; inside a status, the API order.

## HistoryQuery (client, in the address)
| Field | Type | Rule |
| --- | --- | --- |
| metric | enum | `license`, `csp-sessions`, `database-size` |
| granularity | enum | `5min`, `hourly`, `daily` |
| preset | enum or empty | `24h`, `7d`, `30d`, `90d`; empty when a custom range is used |
| from, to | UTC timestamps | required for a custom range; computed from the preset otherwise |
| databases | list of names | only for `database-size`; empty means all |

Validation mirrors the API (001 data-model): from ≤ to, the same enums, database names matching the
contract pattern. Invalid address values fall back to the defaults (license, hourly, 7d) with a notice.

## HistoryResult (client, memory)
| Field | Type | Rule |
| --- | --- | --- |
| series | list of Series | merged across pages, ordered by time |
| coverage, partial | from the first page | shown as a notice when partial |
| complete | boolean | false when the page cap (R8) stopped the paging |

## ProcessQuery (client, in the address)
| Field | Type | Rule |
| --- | --- | --- |
| namespace, user, state | text | optional exact filters |
| q | text | optional, at most 100 characters |
| sort | field name with optional `-` | one of the API's process fields |
| page, pageSize | integers | pageSize one of 25, 50, 100 (default 50) |
| autoRefresh | boolean | default on, every 15 s; not stored in the address |

## Preferences (client, browser storage)
| Field | Type | Rule |
| --- | --- | --- |
| language | `en`, `pt-BR`, `es` | first visit: browser language if supported, else `en` |
| appearance | `system`, `light`, `dark` | default `system` |

## Session states (client)
`signed-in` → (API 401) → reload → IRIS login → `signed-in` on the same address.
`signed-in` → (API 403) → `no-access` screen. `/settings` false → `not-enabled` screen.
