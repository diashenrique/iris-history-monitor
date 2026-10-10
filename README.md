# IRIS History Monitor

A monitor for InterSystems IRIS. It shows, in one place, the state of an instance right now (Overview),
how it changed over time (History, from the System Monitor `^%SYSMONMGR` data in `SYS.History`), and
what its processes are doing (Processes).

![Overview, light theme](images/new-overview-light.png)

## What you get

- **Overview**: every dashboard metric with its state (OK, warning, critical, unavailable). Metrics that
  need attention come first; the page refreshes by itself and can be paused.
- **History**: license use, CSP sessions and database size, every 5 minutes, hourly or daily, as a chart
  with zoom and as a table. Hourly and daily show average and maximum. Export to CSV.
- **Processes**: the process list with filters (namespace, user, state, text), sorting, paging, details
  of one process, and export to CSV.
- English, Portuguese (Brazil) and Spanish; light, dark or system theme; keyboard and screen reader
  friendly (WCAG 2.2 AA).
- A versioned REST API, `/historymonitor/api/v1`, which the interface uses as its only data source.
  Contract: [`specs/001-api-v1/contracts/openapi.yaml`](specs/001-api-v1/contracts/openapi.yaml).

| History | Processes |
| --- | --- |
| ![History](images/new-history.png) | ![Processes](images/new-processes.png) |

![Overview, dark theme](images/new-overview-dark.png)

## Install

Needs IRIS 2026.1 or later (tested on IRIS Community 2026.1) and IPM 0.10.9 or later.

### With IPM, on your instance

```objectscript
zpm "install iris-history-monitor"
```

or, from a clone of this repository:

```objectscript
zpm "load /path/to/iris-history-monitor"
```

### With Docker

```shell
git clone https://github.com/diashenrique/iris-history-monitor.git
cd iris-history-monitor
docker compose up -d --build
```

The image installs the module with IPM in its own namespace, `IRISMONITOR`, and turns history
collection on for itself (the steps in [Turning on history collection](#turning-on-history-collection)).
Ports come from `.env` (`IRIS_PORT=52773`, `IRIS_SUPERSERVER_PORT=1972`).

## Use

Open <http://localhost:52773/historymonitor/index.html> and sign in. In the Docker image the user is
`_SYSTEM` with password `SYS`; **change it** before the container is reachable by anyone else. The
Management Portal also gets a favourite, *History Monitor*, that opens the same page.

To let someone use the monitor without being an administrator, give them the role
`HistoryMonitorViewer` (created by the install). It allows reading the monitor and nothing else.

### Turning on history collection

History shows what the instance's own System Monitor records. **On a standard IRIS install it records
nothing** until an administrator turns it on, and the History page says so. The module never turns it on
by itself.

1. As an administrator, in a terminal (`iris session IRIS -U %SYS`):

   ```objectscript
   do ##class(%Monitor.Manager).Activate("%Monitor.System.HistoryPerf")
   do ##class(%Monitor.Manager).Activate("%Monitor.System.HistorySys")
   do ##class(%Monitor.Manager).StartApp()
   ```

   The first sample arrives within about 5 minutes.

2. Keep it running after a restart. IRIS does not start the Application Monitor again when the instance
   starts, even with the classes active (measured on IRIS 2026.1). Add a `SYSTEM` entry to the `%ZSTART`
   routine in `%SYS`:

   ```objectscript
   %ZSTART ; startup hooks
       quit
   SYSTEM ; runs when the instance starts
       try { do ##class(%Monitor.Manager).StartApp() } catch {}
       quit
   ```

   If the instance already has a `%ZSTART`, add the `StartApp()` line to its `SYSTEM` entry instead of
   replacing the routine.

3. Check. `GET /historymonitor/api/v1/history-collection` answers `"state":"recording"`, and the notice on
   the History page goes away.

How long the instance keeps each granularity (the History page shows it next to the granularity):

| Granularity | Default | Change it (in `%SYS`) |
| --- | --- | --- |
| 5 minutes | 7 days | `do ##class(SYS.History.PerfData).SetPurge(days)` |
| Hourly | 60 days | `do ##class(SYS.History.Hourly).SetPurge(days)` |
| Daily | kept indefinitely | `do ##class(SYS.History.Daily).Purge("YYYY-MM-DD")` removes older days |

To try the History page before real data builds up, load demo history in `%SYS`:

```objectscript
zn "%SYS"
do ##class(SYS.History.SysData).Demo(30)
```

### Upgrading from 1.x

2.0.0 removes the old pages (`/csp/irismonitor/*.csp`) and the switch that turned the new monitor on.
Install it over 1.x as usual (`zpm "install iris-history-monitor"` or `load`):

- Old addresses keep working: each one forwards to the matching screen, and they stay that way for all of
  2.x.

  | Old address | Opens |
  | --- | --- |
  | `dashboard.csp` | Overview |
  | `historylicense.csp`, `historycspsessions.csp`, `historydatabase.csp` | History on that metric |
  | `systemprocesses.csp` | Processes |
  | anything else under `/csp/irismonitor/` | Overview |

- The upgrade removes what the old pages left in the module's namespace: their classes and compiled pages,
  their files, and their scratch data (`^IRISMonitor`). It never deletes a namespace or a database.
- The monitor is on for everyone with the `HistoryMonitorViewer` role. To keep someone out, remove the
  role or disable the `/historymonitor` web application.

## Develop

- ObjectScript lives in `src/cls/diashenrique/historymonitor` (`api`, `service`, `util`, `web`). Tests are in `.../test`; run them in the module's namespace with
  `do ##class(%UnitTest.Manager).RunTest("diashenrique/historymonitor/test","/nodelete")`.
- The interface lives in `web/` (React, TypeScript, Vite). The built files are committed to
  `src/web/historymonitor/`, so IRIS serves them as static files with no build step on the server.

```shell
cd web
npm ci
npm test          # unit and accessibility tests, fixtures checked against the API contract
npm run build     # writes src/web/historymonitor/ (commit the result)
```

End-to-end tests run the interface against a real IRIS. Start a container with this repository mounted
at `/home/irisowner/repo`, prepare it, then run Playwright:

```shell
export HM_VIEWER_PASSWORD=... HM_NOROLE_PASSWORD=...
.github/ci/e2e-setup.sh <container>
cd web && npm run e2e   # HM_BASE_URL, default http://localhost:52773/historymonitor/
```

Changes follow the spec-driven workflow in [`CLAUDE.md`](CLAUDE.md) and
[`.specify/memory/constitution.md`](.specify/memory/constitution.md); specs are in [`specs/`](specs/).
CI runs the ObjectScript tests, an IPM install check, the interface tests, the end-to-end tests and the
Docker image.

## Security notes

- Every API call needs a signed-in user with the `HistoryMonitorViewer` role (or an administrator).
  Errors come back as `application/problem+json`.
- The interface loads nothing from other sites and has no inline script or style, so it runs under a
  strict Content-Security-Policy. IRIS does not send one; set it in the web server in front of IRIS, on
  the interface's static files only (`index.html` and `assets/`). The IRIS sign-in page uses inline script
  and style and would break under it. The end-to-end test
  [`web/tests/e2e/csp.spec.ts`](web/tests/e2e/csp.spec.ts) runs every screen under this policy:

  ```text
  default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'
  ```

  Apache (with the Web Gateway), `mod_headers`:

  ```apache
  <LocationMatch "^/historymonitor/(index\.html|assets/)">
      Header always set Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
  </LocationMatch>
  ```

  Nginx, in the `server` that passes `/historymonitor/` to IRIS (repeat the same gateway or proxy
  directives inside this `location`):

  ```nginx
  location ~ ^/historymonitor/(index\.html|assets/) {
      add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'" always;
      # ... the same proxy_pass / gateway directives as for /historymonitor/
  }
  ```

## Releases

Changes per version: [`CHANGELOG.md`](CHANGELOG.md). How a version is released: [`docs/releasing.md`](docs/releasing.md).

## License

[MIT](LICENSE).
