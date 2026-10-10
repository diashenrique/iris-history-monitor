# Data model: Retire the old pages

No new stored data. This feature removes data and defines one fixed mapping.

## Old address → screen (fixed table)
See [contracts/forwarding.md](contracts/forwarding.md). Key: last path segment, case-insensitive.
Value: one of six constant target addresses. Not configurable, not stored.

## Leftovers of 1.x (removed by `util.Retire`, research R3)

| Item | Where | Created by | Removal |
| --- | --- | --- | --- |
| Old page classes | `diashenrique.historymonitor.dashboard.*` | module 1.x resources | delete the classes if present |
| Old util classes | `util.metrics`, `util.Dispatcher`, `util.Settings` | module 1.x resources | delete if present |
| Compiled pages | `csp.dashboard`, `csp.dashboardapi`, `csp.historycspsessions`, `csp.historydatabase`, `csp.historylicense`, `csp.systemprocesses` | CSP compiler | delete these six only |
| Page files and resources | `${cspdir}irismonitor/` | `<CSPApplication>` / `<FileCopy>` of 1.x | delete the folder |
| Scratch data | `^IRISMonitor` | old pages, per request | kill |
| Monitor switch | `^diashenrique.historymonitor.Settings` | `SetInterfaceEnabled` (1.4 to 1.9) | kill |

State: present (1.x) → absent (2.0.0). `Run()` is idempotent: absent items are skipped, a second run
removes nothing and reports nothing removed.

Untouched: namespaces, databases, `HistoryMonitorViewer`, `HistoryMonitorRead`, the favourite, SAM
sensors, `SYS.History` data.
