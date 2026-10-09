# Research: Versioned Read API (v1)

## R1. Where does the API live and how is it protected?
- **Decision**: a new web application `/api/historymonitor/v1` with dispatch class
  `diashenrique.historymonitor.api.Dispatch`, password authentication enabled, unauthenticated
  access disabled, and access limited to a new role holding a new resource.
- **Rationale**: a separate application keeps static files and the API apart, follows the `/api/<name>`
  convention, and lets the version live in the application path.
- **Alternatives**: routes inside the existing `/csp/irismonitor` application (mixes file serving and
  REST, harder to secure separately); reusing the Management Portal resources (too broad).
- **Confirmed** (2026-10-07): authentication is the web application's own (password, session cookie or HTTP basic).
  Tokens are out of scope for v1.
- **Not verified here**: how `module.xml` should declare the role and resource for IPM. Task T003
  creates them from `util.Security` and is the first thing to try on a real instance.

## R2. Does the System Monitor hold 90 days?
- **Decision**: do not assume 90 days. The default settings keep far less at the fine grains, so the
  history service reads the tables directly and returns `coverage` (first and last timestamp present)
  plus `partial: true` when the window is not fully covered. A 90-day window is answerable at `daily`
  granularity; `hourly` and `5min` need an administrator to raise the retention first.
- **Measured** (task T006, 2026-10-07, a fresh IRIS Community 2026.1 container in CI, by reading the
  `SYS.History.*` classes; the tables themselves were empty, so this is configuration, not data):

  | Table family | Retention setting | Value on a fresh instance | Source |
  | --- | --- | --- | --- |
  | `PerfData`, `SharedMemoryData` (detail samples) | `SYS.History.PerfData.SetPurge("")` and `SYS.History.SharedMemoryData.SetPurge("")` return the current days to keep | **7 days** (returned by the call) | class method docs and a call |
  | `Hourly_*` | `SYS.History.Hourly.SetPurge("")` | **60 days** (returned by the call) | class method docs and a call |
  | `SysData` (the 5-minute system table the history pages read) | `SysData.Purge(Keep)` uses "the current system default for Keep"; there is no `SetPurge` on this class | **not determined** | class method docs only |
  | `Daily_*` | `Daily.Purge(Date)` takes an explicit date; there is no `SetPurge` | **no automatic limit found** | class method docs only |

- **What this means for the spec**:
  - FR-013 (90 days at hourly and daily) holds for daily data only if nothing purges it, which is not confirmed.
    Hourly data is 30 days short of 90 by default.
  - The `coverage` and `partial` fields are required, not optional polish. They are how the UI says
    "this instance keeps 60 days of hourly data" without failing.
  - Do not promise 90-day hourly or 5-minute history in the UI copy. Phase 3 (own rollups) is justified
    only if the daily table turns out to be purged or too coarse.
- **Not verified**: the retention of `SysData` and `Daily_*` on a real, running instance; whether an
  instance's administrator changed the 60 and 7 day defaults; behavior on 2020.2. Verifying means
  running `Hourly.SetPurge("")`, `PerfData.SetPurge("")` and a `MIN`/`MAX` of `DateTime` over each table
  on the target instance. Calling `SetPurge("")` is documented as a read that leaves the setting unchanged.
- **Alternatives**: build own rollup tables now (more code, a purge task and a migration, decided in
  Phase 3 only if measurement shows a gap).

## R3. How to serve the existing pages from the API
- **Decision**: one helper `api.js` calls the API and converts each response to the shape the page's
  grid or chart already expects; each page changes only its request call.
- **Rationale**: the DevExtreme and Highcharts code stays untouched, so risk is small and the change
  is easy to revert. The mapping lives in one file with its own tests.
- **Alternatives**: rewrite the page scripts (large, belongs to Phase 4); keep the old classes as the
  data source (does not meet the clarified requirement).

## R4. Large series and truncation
- **Decision**: cursor-based paging on the timestamp, default 1000 points, maximum 5000, with
  `truncated` and `next` fields. The old `top 1000` cut is not carried over.
- **Rationale**: FR-004 forbids silent truncation; a timestamp cursor is stable while new points arrive.
- **Alternatives**: offset paging (drifts as data arrives), no cap (unbounded responses).

## R5. Errors
- **Decision**: one `Problem` class writes `application/problem+json` with `type`, `title`, `status`,
  `detail`. `type` is a stable relative URI such as `/problems/invalid-parameter`.
- **Rationale**: FR-007; clients branch on `type`, not on text.

## R6. Concurrency
- **Decision**: services build results in local variables and never write globals. A test runs two
  overlapping requests with different ranges and compares each result.
- **Rationale**: the legacy classes `Kill` and rewrite `^IRISMonitor` per request, which lets one user
  affect another (FR-009).

## R7. Compatibility target
- **Decision**: write for the IRIS version in the current `Dockerfile` (2020.2). If the image is updated
  in Phase 5, newer APIs may be adopted then.
- **Rationale**: avoids breaking existing installs; the used classes exist in that version.

## R8. Overview source, statuses and the access it needs (task T012)
- **Decision**: every overview value comes from one call to `SYS.Stats.Dashboard.Sample()`. The SAM
  sensors are not read separately: `util.customSensors` publishes the same dashboard properties, and
  reading `/api/monitor/metrics` would be an outbound HTTP call the plan rules out.
- **Statuses**: the rules are listed in data-model.md. The license thresholds (80 and 95 percent) and
  "serious alerts above 0 is a warning" are product choices made here, because neither dashboard colors
  these values today. They are constants in `service.Overview` and are easy to change.
- **Observed on a fresh IRIS Community 2026.1 container** (2026-10-09): `LastBackup` is empty (so the
  overview reports a warning), `SeriousAlerts` is 1, the state texts are `Normal` and `OK`, and
  `SystemUpTime` is text such as `0d  0h 07m`. The unit is `text`; it is not converted to seconds.
- **Access**: switching to `%SYS` needs Read on `%DB_IRISSYS`. A real HTTP call by a user holding only
  `HistoryMonitorViewer` got `<PROTECT>` and every metric unavailable. `util.Security.Setup` now gives the
  role `%DB_IRISSYS:R` and adds it to a role created by version 1.3.0. With it, the same call returned
  200 with all 18 metrics and no contract mismatch. No administrator privilege is needed.
- **Found for task T021** (resolved there, see R11): a user without the role gets `401` with an HTML body, not `403` with
  problem+json. The web application's `Resource` check rejects the request before `OnPreDispatch` runs,
  so the 403 branch of `Dispatch.Authorize` is never reached over HTTP. Choosing between "web application
  resource as the gate (401, HTML)" and "role check in `OnPreDispatch` only (403, problem+json)" is part
  of T021. `404` and `405` over HTTP already return problem+json.

## R9. History: keys, series, paging and access (tasks T014 to T017)
- **UTC keys**: every `SYS.History` row has `ZDATE` and `ZTIME`, documented as the "UTC date key" and
  "UTC time key", while `DateTime` is local time. Seen in a container with `TZ=America/Sao_Paulo`: a row
  with `DateTime` 00:00 has `ZTIME` 10800 (03:00 UTC). The service filters and reports by these keys, so
  no time zone conversion is done. The legacy pages filter on `ZDATE` but show `DateTime`, mixing the two.
- **Formatting trap**: `$ZDateTime(h, 3, 7)` converts local time to UTC. Applied to a UTC value it shifts
  it by the server offset; this hit both `History.Iso` and the overview `generatedAt`, and was invisible
  on a UTC server. Both now add `T` and `Z` to format 1, and the CI unit-test container runs with
  `TZ=America/Sao_Paulo` so this kind of mistake fails a test.
- **Series**: 5-minute license and CSP sessions give one series named `value`. Hourly and daily give
  `Avg` and `Max` (the statistics the pages show; `StDev` is left out). Database size gives one series per
  database, using the `Max` statistic for hourly and daily, in MB as stored (`DB_FileSize`); the legacy
  page divides by 1024 and hides IRISTEMP and USER, which is left to the page mapping (T023).
- **Empty values**: a null value (for example CSP sessions not collected) is left out of the points, not
  sent as 0 as the legacy `NVL(..., 0)` did.
- **Paging**: `limit` counts timestamps, not points, so every series of a page covers the same instants.
  `next` is the last timestamp of the page; the next request reads after it. Rows are read oldest first
  and reading stops one timestamp past the limit.
- **Partial**: true when coverage is null or data is missing at either end by more than one step
  (5 minutes, 1 hour, 1 day). The end is measured up to now, so a range that ends in the future is not
  partial only because the future has no data. Gaps in the middle are not detected.
- **Access**: a real HTTP call by the viewer failed with `SQLCODE -99`. `util.Security.Setup` now grants
  the role `SELECT` on the eight `SYS_History` tables the service reads (and nothing else: no insert,
  update or delete, no other history table). With it the viewer got 200 for every metric and granularity
  on three days of `SYS.History.SysData.Demo` data, with no contract mismatch.
- **Test data**: the tests write real `SYS.History` rows in February 2001 and delete them afterwards
  (`test.api.HistoryFixture`). On a developer instance this touches the system history tables for the
  length of the test run.

## R10. Processes: source, names and the access decision (tasks T018 to T020)
- **Source**: the values of the `CONTROLPANEL` query of `%SYS.ProcessQuery`, the query the processes page
  uses today. `CONTROLPANEL` refuses to run without `%Admin_Manage:USE` (its Execute method checks it;
  a real HTTP call by the viewer got `SQLCODE -400`, "Operation requires %Admin_Manage:USE privilege",
  after `SQLCODE -99` for the missing EXECUTE grant). The service instead walks `^$JOB` and opens each
  process as a `%SYS.ProcessQuery` object, which needs only the `%DB_IRISSYS:R` the role already has,
  and applies the same adjustments the query makes in `JOBEXAMFetch`: parent pid 0 left out, `@@`
  namespaces shown as `^^`, mirror daemons named by location, TCP and TNT devices shown with the client
  name, elapsed time from `ElapsedTime(StartTimeUTC)`. A test compares the result with `CONTROLPANEL`
  for long-lived system daemons (the tests run as a superuser, who may call it).
- **Access decision to review**: a user holding `HistoryMonitorViewer` can list every process (user
  names, routines, client addresses) without `%Admin_Manage`. That is what the processes page shows, and
  the API is gated by its own resource, but it is a wider grant than the Management Portal makes.
  Restricting it (for example, a second resource for the process list) is a product decision.
- **Names**: the query's column names have spaces and `#` (`Job#`, `Client Name`, `EXE Name`), so the API
  uses camelCase names: job, pid, displayPid, username, device, namespace, routine, commands, globals,
  state, clientName, exeName, ipAddress, privateGlobalBlocks, osUsername, cpuTime, parentPid,
  elapsedTime. The four capability flags are not returned. The legacy page skipped columns 14 to 18,
  which also dropped `PrvGblBlkCnt`; the API keeps it as `privateGlobalBlocks`.
- **Filters and sort**: `namespace`, `user` and `state` are exact matches (an unknown value matches
  nothing); `q` is a case-insensitive substring of pid and the text fields. `sort` is any returned field,
  `-` for descending; a process without the field sorts last either way; ties go by job number.
  Default order is job number. `next` is the following page number; a page past the end is empty, not an
  error, which covers processes ending between requests.

## R11. Errors and access over real HTTP (tasks T021, T022)
- **Measured**: `test.api.HttpAuthTest` creates the web application from the `<WebApplication>` of
  `module.xml` under a test URL, a viewer and a user without the role, and calls every route on the
  instance web server. It runs in CI (the container has a web server on port 52773).
- **403**: with `Resource="HistoryMonitorRead"` on the web application, CSP refused a user without the
  role before `api.Dispatch` ran, with a 401 HTML page; the 403 branch of `Authorize` was unreachable.
  The resource was removed from the web application, so `OnPreDispatch` (which runs on every request)
  is the role check and answers 403 problem+json. Password authentication stays required and
  unauthenticated access stays disabled; the CI install check asserts there is no web application resource.
- **401**: CSP answers a request without valid credentials by calling `Login` on the dispatch class
  before login, as `CSPSystem` with no roles. Overriding `Login` moved that code into the namespace
  database, which that context cannot read: the request failed with `#5916 Illegal Web Request` and came
  back as 404. The only way to send a problem body would be to allow unauthenticated access, which the
  owner ruled out. So 401 is IRIS's own answer: status 401 and an empty body (no `WWW-Authenticate`
  header was observed behind Apache). The contract now describes 401 that way, without a problem body.
- **Shapes**: 200 responses match their schemas over HTTP; 400, 403, 404 and 405 are problem+json.
- **Coverage**: `test.api.ContractCoverageTest` fails when a contract operation has no route, a route is
  missing from the contract, or an operation lacks a contract test class or an HTTP call. A route added
  only to the UrlMap was caught in a trial run.
- **Runner**: a test case whose `OnBeforeAllTests` fails runs no method and was invisible in the totals
  (the HTTP test was silently skipped once). The Runner now reports it as `FAILED_CASE` and counts it.
