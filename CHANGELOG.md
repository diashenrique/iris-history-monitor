# Changelog

Versions follow [SemVer](https://semver.org/); the version is the one in `module.xml`. Every push to `master`
publishes a patch version automatically (`docs/releasing.md`); minor and major versions have a section here.

## 2.1.0 (2026-10-10)

The first release since 1.2.4. It includes everything listed under 2.0.0 and 1.9.3 below; those
versions were steps on the way and were never published on their own.

History collection health (spec 004). On a standard IRIS install the System Monitor records no history,
and the History page used to stay empty with no reason given.

### New
- API v1 `GET /history-collection` reports:
  - whether the instance is recording history (`recording`, `stale` or `off`);
  - the last sample;
  - whether the collector is running;
  - how many days each granularity is kept.

  The change is additive, and the contract goes to 1.2.0.
- History shows a notice when nothing is being recorded or recording stopped, with the time of the last
  sample and a link to the administrator steps. It also shows how long the chosen granularity is kept,
  and the partial-period notice names the retention limit when that is the reason.
- README: "Turning on history collection". It covers turning collection on, keeping it on after a
  restart through `%ZSTART` (IRIS does not restart the Application Monitor by itself), and changing
  retention.
- The container image turns history collection on for itself.

### Unchanged on purpose
- The module never changes the instance's history collection or retention settings. CI checks that an
  install leaves them as they were.
- No own copies of history. The instance keeps 5-minute detail for 7 days and hourly summaries for 60
  days, and never purges daily summaries, which is enough.

## 2.0.0 (not released separately; part of 2.1.0)

Major version: the old pages are gone, and addresses that served them in 1.x now forward (spec 003).

### Removed
- The old pages (`/csp/irismonitor/*.csp`), their static files (including the DevExtreme 18.2.3 grid
  library) and the classes only they used: `diashenrique.historymonitor.dashboard.*`, `util.metrics`
  (with its server-side metrics proxy) and `util.Dispatcher`.
- The switch that turned the new monitor on (`util.Settings`, `SetInterfaceEnabled`). The monitor is on for
  everyone with the `HistoryMonitorViewer` role.
- The old pages' scratch data `^IRISMonitor`: no code writes shared per-request data any more.

### Changed
- Every address under `/csp/irismonitor/` forwards (302) to the new monitor, and does so for all of 2.x:

  | Old address | New screen |
  | --- | --- |
  | `dashboard.csp` | Overview |
  | `historylicense.csp` | History, license use |
  | `historycspsessions.csp` | History, CSP sessions |
  | `historydatabase.csp` | History, database size |
  | `systemprocesses.csp` | Processes |
  | anything else | Overview |

- API v1: `GET /settings` stays; `interfaceEnabled` is always `true` and marked deprecated.
- Constitution 1.1.0: requests go through `%CSP.REST` URL maps, and no server-side call goes to a host
  taken from a request.

### Upgrade
- Installing 2.0.0 over 1.x removes, in the module's namespace, the old classes, the six compiled pages,
  the `${cspdir}irismonitor/` folder, `^IRISMonitor` and the switch value. Uninstalling removes them too.
  No namespace or database is deleted.

## 1.9.3 (not released separately; part of 2.1.0)

Everything below 1.9.3 was built in the same cycle and is released together in 2.1.0.

### New
- **New monitor** at `/historymonitor/index.html`: Overview (live, metrics that need attention first),
  History (license use, CSP sessions, database size; 5 minutes, hourly or daily; chart and table; CSV),
  Processes (filters, sorting, paging, details, CSV). English, Portuguese (Brazil) and Spanish; light,
  dark or system theme; WCAG 2.2 AA. Switched on by an administrator with
  `##class(diashenrique.historymonitor.util.Settings).SetInterfaceEnabled(1)` (spec 002).
- **REST API v1** at `/historymonitor/api/v1`: `GET /overview`, `/history/{metric}`, `/processes`,
  `/settings`; errors as `application/problem+json`. Contract in `specs/001-api-v1/contracts/` (spec 001).
- Role **`HistoryMonitorViewer`**: reads the monitor and nothing else. One sign-in covers the interface
  and the API.
- Docker image on IRIS Community 2026.1 that installs the module with IPM.

### Changed
- The old pages (`/csp/irismonitor/*.csp`) are **obsolete**: they show a banner that links to the new
  monitor and are out of the menu. They will be removed in 2.0.0.
- The Management Portal favourite opens the new monitor.
- Requires IPM 0.10.9 or later; tested on IRIS 2026.1.
- The web applications are `<WebApplication>` (IPM deprecates `<CSPApplication>`) (1.9.2).
- The process details dialog is the native `<dialog>`; the interface runs under the strict
  Content-Security-Policy in the README (1.9.3).

### Security
- No `Xecute` with request data; SQL takes parameters; server-side HTTP calls are checked against an
  allow list.
- The install no longer gives public read access to `%DB_IRISSYS`.

### Fixed
- The old pages answered 404 on a fresh install: they are compiled after their files are copied, and are
  not recompiled on request (`AutoCompile=0`) (1.9.1).
- History times are read as UTC and shown in the viewer's time zone.
