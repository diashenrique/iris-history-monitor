# Research: History collection health

Measured on IRIS 2026.1 Community (`intersystemsdc/iris-community:2026.1`) with IPM 0.10.9, on
2026-10-10. Containers: `iris-hm` (dev) and `hm-docker-test` (this repository's image).

## R1. Retention, and why no own rollups
- **Facts** (class documentation and values read with `SetPurge("")`):
  - `SYS.History.SysData`/`PerfData` detail is kept 7 days, the system default, set with
    `SYS.History.PerfData.SetPurge(n)`;
  - `SYS.History.Hourly` is kept 60 days, set with `SYS.History.Hourly.SetPurge(n)`;
  - `SYS.History.Daily` is never purged automatically, only by `Daily.Purge(date)`.
  - Volume per day: 288 SysData rows, 24 hourly, 1 daily.
- **Decision**: no own rollups or copies (spec Assumptions). The History screen's granularities map 1:1
  to these: 5-minute → detail, hourly → Hourly, daily → Daily.
- **Note**: purging runs from the collector classes "at the start of each day". With the collector off,
  nothing is purged: 90 days of demo detail stayed although the limit is 7.

## R2. Collection state: how to read it
- **Decision**:
  - **Configured**: `%Monitor.ItemGroup` row `%Monitor||%Monitor.System.HistorySys` gives `Activated`
    (1 or 0) and `SampInterval` (seconds; 300 by default). It is opened as an object in `%SYS` (no SQL
    privilege needed).
  - **Running**: a process whose routine is `%MONAPP` exists (`%SYS.ProcessQuery`, already used by the
    processes service).
  - **Last sample**: `MAX` of the (ZDATE, ZTIME) key of `SYS_History.SysData`, UTC (spec 001 rule).
  - **State**: `off` when not Activated; `stale` when Activated and there is no sample, or the last is
    older than 3 × `SampInterval`; `recording` otherwise. `running` is reported beside it so the screen
    can name the cause.
- **Why HistorySys**: the three History metrics (license, CSP sessions, database size) are system-usage
  data (`SysData`, `SysDataDB`). `HistoryPerf` (30 s performance counters) is not needed for them.
- **Measured**: on a standard instance no class is active (`%Monitor.Manager.IsActive()` = 0) and there is
  no `%MONAPP`. After `Activate("%Monitor.System.HistoryPerf")`, `Activate("%Monitor.System.HistorySys")`
  and `StartApp()`, the first SysData sample arrived 5 minutes later.
- **Alternatives**: `%Monitor.Manager.IsActive()` (instance-wide summary only); asking an administrator
  to say (not observable).

## R3. Can a viewer read it?
- **Decision**: the service runs inside the API request (role `HistoryMonitorViewer`, which holds
  `%DB_IRISSYS:R` and SELECT on the history tables) and switches to `%SYS` like `service.History`. The
  `HttpAuthTest`-style test must prove, as the viewer, that the route answers 200 with every field. If
  `SetPurge("")` or the object open is refused, that field is reported `unknown`/null (spec edge case),
  and the result is recorded here.
- **Note**: a terminal session as the viewer is refused ("Access Denied", no console service), so it
  cannot stand in for the API test.

## R4. Why collection does not resume after a restart, and the fix
- **Measured**:
  - After a container restart, the two classes are still `Activated`, the System Monitor starts
    (`[SYSTEM MONITOR] System Monitor started in %SYS` in `messages.log`) and no `%MONAPP` appears
    within 5 minutes.
  - `%Monitor.Manager.Halt()` followed by `Start()` (System Monitor) does not start it either. The
    Application Monitor starts only on `%Monitor.Manager.StartApp()`.
  - The `[Monitor]` section of `iris.cpf` has no setting for it.
- **Fix**: an administrator adds a `SYSTEM` entry to the `%ZSTART` routine in `%SYS` that calls
  `##class(%Monitor.Manager).StartApp()`. Measured: after a restart with that entry, `%MONAPP` runs.
  `%ZSTART` is IRIS's documented user startup hook. The README gives the routine. It warns that an
  existing `%ZSTART` must be extended, not replaced. Option A: the module never writes `%ZSTART`.
- **Alternatives**: a task-manager task at startup (more steps, same effect); `^%SYSMONMGR` menus
  (interactive, and they do not persist the Application Monitor start either, as measured).

## R5. The container image
- **Decision**: the Dockerfile runs, at build time, the same steps the README gives: activate
  `HistoryPerf` and `HistorySys`, and write the `%ZSTART` `SYSTEM` entry. This is allowed by FR-010: the
  image is a demonstration environment, and without it History stays empty in the image. The module's
  install does not do it (FR-006), and `InstallCheck` proves that on a plain IPM install.
- **Rationale**: SC-003 asks that the README steps work on the image too. Running them in the
  Dockerfile is the check.

## R6. API shape
- **Decision**: `GET /history-collection`, a new path. `/history/{metric}` would read "collection" as a
  metric and answer 400, and `/settings` is about the interface. The schema is `HistoryCollection`
  (see [contracts/history-collection.md](contracts/history-collection.md)). Contract version 1.1.0 →
  1.2.0 (additive). Module 2.0.0 → 2.1.0 (new feature).
