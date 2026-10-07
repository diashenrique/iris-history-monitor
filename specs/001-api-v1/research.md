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
- **Decision**: treat retention as unknown. The history service reads the tables directly and returns
  `coverage` (first and last timestamp present) plus `partial: true` when the window is not fully covered.
- **Rationale**: the spec requires 90 days answerable without failing; the real retention is a setting
  of the instance and has not been measured. The tables used today are the 5-minute, hourly and daily ones.
- **Task**: T006 measures retention on the reference image and records the result here.
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
