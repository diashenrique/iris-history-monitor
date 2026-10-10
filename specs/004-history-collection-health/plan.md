# Implementation Plan: History collection health

**Branch**: `004-history-collection-health` | **Date**: 2026-10-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-history-collection-health/spec.md`

## Summary

A new read-only route `GET /history-collection` in API v1 reports the state of the history collector
(recording, stale or off), the time of the last system-usage sample, whether the collector process is
running, the sample interval, and the retention of each granularity. A new `service.Collection` class
builds it by reading the instance in `%SYS`, without writing anything (research R1–R3). The History
screen reads it: a notice for "off" or "stale", and the retention limit next to the granularity choice.
The README gets "Turning on history collection", including the `%ZSTART` step that makes collection
resume after a restart (R4). The container image runs those same steps for itself (FR-010, R5).

## Technical Context

**Language/Version**: ObjectScript on IRIS 2026.1; TypeScript 5 / React 19.

**Primary Dependencies**: IPM 0.10.9, `%CSP.REST`; TanStack Query in the interface. Nothing new.

**Storage**: none. Read only: `%Monitor.ItemGroup` (activation, interval), `SYS_History.SysData`
(last sample), `%SYS.ProcessQuery` (`%MONAPP`), `SYS.History.PerfData.SetPurge("")` and
`SYS.History.Hourly.SetPurge("")` (retention; with `""` they read and do not change, per their
documentation).

**Testing**:
- `%UnitTest`: the state decision as a pure function, the response against the contract, the route over
  HTTP as the viewer, and a check that the module leaves the collector settings unchanged.
- Vitest: the notice, the retention labels, the fixtures against the contract.
- Playwright: History with collection off and on.
- CI `ipm-install`: settings identical before and after the install.

**Target Platform**: IRIS 2026.1 (Community and full), container image.

**Project Type**: IPM module (REST API and static interface).

**Performance Goals**: the route answers in the same time class as `/settings`: a handful of reads, no
table scan beyond `MAX` on an indexed key.

**Constraints**: option A, so no write to monitoring configuration from the module (FR-006). API v1
changes only additively (constitution III). A viewer with `HistoryMonitorViewer` must be able to read
it.

**Scale/Scope**: 1 route, 1 service class, 1 interface notice, 3 retention labels, README section,
image setup.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Secure by Default | The route takes no input, uses fixed SQL with no request value, makes no outbound call, and reads `%SYS` only through the service layer. | Pass |
| II. Tests Gate Every Merge | Unit, contract, HTTP-as-viewer, e2e and an "unchanged settings" check are planned before the code. | Pass |
| III. Contract First, Versioned | The new path and schema are added to `openapi.yaml` first, with a contract test. No existing response changes (additive, so v1 stays). | Pass |
| IV. No Shared Scratch State | Nothing is written. | Pass |
| V. Small, Reversible Increments | No own rollups (measured retention). No dependency. The module does not touch the collector (option A). | Pass |

Post-design re-check: unchanged, all pass.

## Project Structure

### Documentation (this feature)

```text
specs/004-history-collection-health/
├── plan.md
├── research.md          # R1-R6 (measurements of 2026-10-10)
├── data-model.md        # collection state, retention
├── quickstart.md
├── contracts/
│   └── history-collection.md   # the route; the schema goes into specs/001-api-v1/contracts/openapi.yaml
└── tasks.md
```

### Source Code (repository root)

```text
src/cls/diashenrique/historymonitor/
├── service/Collection.cls              # NEW: state, last sample, running, interval, retention
├── api/Dispatch.cls                    # + GET /history-collection
└── test/api/CollectionTest.cls         # NEW; HttpAuthTest routes + /history-collection
specs/001-api-v1/contracts/openapi.{yaml,json}   # + path, HistoryCollection schema (version 1.2.0)
web/src/
├── api/{client.ts,types.ts}            # historyCollection()
├── features/history/                   # CollectionNotice, retention labels
└── i18n/{en,pt-BR,es}.json
web/tests/{unit,fixtures,e2e}/          # notice, labels, fixtures, e2e with collection off/on
.github/ci/InstallCheck.cls, ci.yml     # settings unchanged by the install
Dockerfile                              # image turns collection on for itself (FR-010)
README.md, CHANGELOG.md, CLAUDE.md
module.xml                              # 2.1.0 (new feature, additive)
```

**Structure Decision**: the new service sits in `service/`, beside History, Overview and Processes. The
route goes in the existing dispatch class and the notice in the History feature folder.

## Complexity Tracking

No violations.
