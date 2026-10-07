# Research: Versioned Read API (v1)

## R1. Where does the API live and how is it protected?
- **Decision**: a new web application `/api/historymonitor/v1` with dispatch class
  `diashenrique.historymonitor.api.Dispatch`, password authentication enabled, unauthenticated
  access disabled, and access limited to a new role holding a new resource.
- **Rationale**: a separate application keeps static files and the API apart, follows the `/api/<name>`
  convention, and lets the version live in the application path.
- **Alternatives**: routes inside the existing `/csp/irismonitor` application (mixes file serving and
  REST, harder to secure separately); reusing the Management Portal resources (too broad).
- **Open point**: authentication beyond the platform default is unanswered (see spec Clarifications).
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
