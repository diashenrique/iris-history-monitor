# Contract: GET /historymonitor/api/v1/history-collection

Read-only, no parameters. Same access as every v1 route: a signed-in user with `HistoryMonitorViewer`
(401/403 problem otherwise). Added to `specs/001-api-v1/contracts/openapi.yaml` as path
`/history-collection` and schema `HistoryCollection` (contract 1.2.0, additive).

```json
{
  "state": "recording",
  "running": true,
  "lastSample": "2026-10-10T02:51:23Z",
  "intervalSeconds": 300,
  "retention": {
    "5min":   { "kind": "days", "days": 7 },
    "hourly": { "kind": "days", "days": 60 },
    "daily":  { "kind": "indefinite", "days": null }
  }
}
```

| Field | Type | Meaning |
| --- | --- | --- |
| `state` | `recording` \| `stale` \| `off` | research R2 |
| `running` | boolean \| null | the collector process exists; null if it cannot be read |
| `lastSample` | ISO 8601 UTC \| null | newest system-usage sample; null when none |
| `intervalSeconds` | integer \| null | system-usage sample interval; null if unknown |
| `retention.<granularity>.kind` | `days` \| `indefinite` \| `unknown` | per granularity of `/history/{metric}` (`5min`, `hourly`, `daily`) |
| `retention.<granularity>.days` | integer \| null | set when kind is `days` |

Rules:
- `stale` when the collector is configured but `lastSample` is null or older than 3 × `intervalSeconds`.
- Nothing is written by this route (FR-006).
