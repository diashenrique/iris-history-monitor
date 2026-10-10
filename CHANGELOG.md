# Changelog

Versions follow [SemVer](https://semver.org/); the version is the one in `module.xml`.

## 1.9.3 (unreleased)

The first release since 1.2.4. Everything below 1.9.3 was built in that cycle and is released together.

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
