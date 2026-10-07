# Implementation Plan: Versioned Read API (v1)

**Branch**: `001-api-v1` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary

Add a read-only REST API for the overview, history series and process list, built as a thin
`%CSP.REST` layer over a service layer that is the only code touching `%SYS`. Point the six existing
pages at the API through one shared JavaScript helper, and keep the old class URLs responding.
History reads the System Monitor tables directly and reports real coverage; the 90-day window is
served without new tables unless measurement in research task R2 shows the retention is too short.

## Technical Context

**Language/Version**: ObjectScript. Kept compatible with the IRIS 2020.2 image currently pinned in
`Dockerfile`; no API newer than that is used until the image is changed.
**Primary Dependencies**: `%CSP.REST`, `%DynamicObject`/`%DynamicArray`, `%SQL.Statement`. No third-party package.
**Storage**: none new. Reads `SYS_History.SysData`, `Hourly_Sys`, `Daily_Sys`, `Daily_DB`,
`SYS.Stats.Dashboard.Sample()`, `%SYS.ProcessQuery` and the SAM sensors.
**Testing**: `%UnitTest` (contract, authorization, concurrency, regression of Phase 1 rules).
**Target Platform**: IRIS Community and licensed instances, Linux containers.
**Project Type**: IRIS web service plus existing CSP pages.
**Performance Goals**: SC-002, p95 under 2 s for a 90-day daily and hourly series (a target to measure).
**Constraints**: read-only, no shared scratch globals, parameterized SQL, errors as problem+json.
**Scale/Scope**: one instance per deployment; up to 90 days x 24 hourly points x a handful of series.

## Constitution Check

| Principle | Status | How the plan satisfies it |
| --- | --- | --- |
| I. Secure by default | Pass | Inputs pass an allow-list or strict-format validator; SQL uses `?`; no `Xecute`; no outbound call |
| II. Tests gate every merge | Pass, with a known gap | Tasks write tests first. CI is currently red for an unrelated reason (task T001 repairs it); until it is green no task counts as verified |
| III. Contract first, versioned | Pass | `contracts/openapi.yaml` is written before the code; `/v1` in the path; contract test per route |
| IV. One source per fact, no shared scratch | Pass | Services return values; `^IRISMonitor` scratch writes are not carried into the new code |
| V. Small, reversible increments | Pass | Stories are ordered P1 to P3 and each ships alone; page migration is last and reversible |

Re-checked after Phase 1 design: no violations, so the Complexity Tracking table stays empty.

## Project Structure

### Documentation

```text
specs/001-api-v1/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/openapi.yaml
└── tasks.md
```

### Source code

```text
src/cls/diashenrique/historymonitor/
├── api/
│   ├── Dispatch.cls        %CSP.REST UrlMap, routes, error handling
│   └── Problem.cls         builds application/problem+json responses
├── service/
│   ├── Overview.cls        snapshot from Dashboard.Sample() and SAM sensors
│   ├── History.cls         series by metric, granularity and range, with coverage and cursor
│   ├── Processes.cls       filtered, sorted, paged process list
│   └── Validate.cls        allow-lists and strict parsers for every input
├── util/Security.cls       creates the resource and role at install
├── dashboard/, util/       existing classes, kept and marked deprecated
└── test/api/               contract, authorization, concurrency tests
src/csp/resources/js/api.js  shared helper that calls the API and returns the shapes the pages expect
src/csp/*.csp                six pages switched to api.js
module.xml                   new web application, role, version bump
```

**Structure Decision**: a service layer under `service/` and a thin `api/` layer, so the future
interface and the migrated pages share one implementation. Existing classes stay in place.

## Complexity Tracking

No violations to justify.
