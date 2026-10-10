---
description: "Tasks for spec 004, history collection health"
---

# Tasks: History collection health

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/history-collection.md](contracts/history-collection.md), [quickstart.md](quickstart.md)

**Tests**: required (constitution II). Paths: `HM` = `src/cls/diashenrique/historymonitor`.

## Phase 1: Setup

- [ ] T001 Set `module.xml` to 2.1.0 and open `## 2.1.0 (unreleased)` in `CHANGELOG.md`
- [ ] T002 Contract first:
  - add path `/history-collection` (GET; 200 `HistoryCollection`; 401/403 as the other routes) and schema `HistoryCollection` to `specs/001-api-v1/contracts/openapi.yaml`, exactly as [contracts/history-collection.md](contracts/history-collection.md): `state` enum `[recording, stale, off]`, `running` boolean|null, `lastSample` date-time|null, `intervalSeconds` integer|null, and `retention` with required `5min`, `hourly` and `daily`, each `{kind: enum [days, indefinite, unknown], days: integer|null}`;
  - bump `info.version` to 1.2.0;
  - regenerate `openapi.json` with `python scripts/openapi_to_json.py`.

## Phase 2: Foundational

- [ ] T003 Write `HM/test/api/CollectionTest.cls` (fails first). It covers:
  - `service.Collection.Decide(configured, lastKey, nowKey, interval)` for every branch: `off` when not configured; `stale` with no sample, or with a sample older than 3 × interval; `recording` at exactly 3 × interval and below;
  - `Response()` matches `HistoryCollection` (ContractHelper), with `retention.daily.kind = "indefinite"`;
  - `retention.5min.days` and `hourly.days` equal `SYS.History.PerfData.SetPurge("")` and `SYS.History.Hourly.SetPurge("")`;
  - after a temporary `Hourly.SetPurge(90)`, the response says 90 (restore the old value in a `Try`/finally) (SC-002);
  - calling `Response()` leaves `Activated`/`SampInterval` of HistorySys and HistoryPerf and both purge settings unchanged (FR-006);
  - the `/history-collection` route is mapped.
- [ ] T004 Implement `HM/service/Collection.cls` per [data-model.md](data-model.md) and research R2:
  - `Decide()` is pure;
  - `Response()` reads in `%SYS` (`New $Namespace`):
    - the `%Monitor.ItemGroup` object `%Monitor||%Monitor.System.HistorySys`;
    - `%MONAPP` presence through `%SYS.ProcessQuery`;
    - the last `SysData` key with fixed SQL (no request value) and the UTC keys of `service.History`;
    - retention with `SetPurge("")`;
  - each read is in its own `Try`, and a failure gives null or `unknown` (spec edge case).

  T003 must pass.
- [ ] T005 Add `<Route Url="/history-collection" Method="GET" Call="HistoryCollection"/>` and `HistoryCollection()` to `HM/api/Dispatch.cls` (writes `service.Collection.Response()`). Add `/history-collection` to `Routes()` in `HM/test/api/HttpAuthTest.cls`, so it is checked as viewer (200 + contract), without credentials (401) and without the role (403). This proves research R3; record the result there.

**Checkpoint**: the API reports the state; ContractCoverageTest and HttpAuthTest pass.

## Phase 3: User Story 1 - Know whether history is being recorded (P1) MVP

- [ ] T006 [P] [US1] Add fixtures `web/tests/fixtures/collection-off.json`, `collection-stale.json` and `collection-recording.json`, valid against the schema (checked by `fixtures-contract.test.ts`). Add `historyCollection()` to `web/src/api/client.ts` and type `HistoryCollection` to `web/src/api/types.ts`, plus the fake in `web/tests/support/fake-api.ts`.
- [ ] T007 [US1] Write Vitest tests first in `web/tests/unit/history-collection.test.tsx`:
  - off with no data: the notice replaces the empty chart (FR-004, SC-001);
  - off or stale with data: the chart plus a notice naming the last sample time in the viewer's zone;
  - stale with `running: false`: the notice names the stopped collector as the likely cause;
  - recording: no notice;
  - the notice links to the README section, `https://github.com/diashenrique/iris-history-monitor#turning-on-history-collection`, and is labeled as administrator steps;
  - axe has no serious issues;
  - in pt-BR and es, the strings are translated.
- [ ] T008 [US1] Implement `web/src/features/history/CollectionNotice.tsx` and use it in `HistoryPage.tsx`:
  - query `['history-collection']` with `refetchInterval` 60 s (SC-005);
  - strings in `web/src/i18n/{en,pt-BR,es}.json` (`history.collection.*`);
  - the notice is a `role="status"` region, not an alert.

  T007 must pass.
- [ ] T009 [US1] E2E in `web/tests/e2e/history.spec.ts`: read `/history-collection` and check that History shows the matching notice:
  - "stopped" or "not recorded" for `off`/`stale`, no notice for `recording`;
  - axe in both themes and the 360 px layout, as the other History tests do.

  The test does not assume a state: CI has collection off, and a dev instance may have it on (analysis F1).

## Phase 4: User Story 2 - Know how far back each view can go (P2)

- [ ] T010 [US2] Tests first in `web/tests/unit/history-form.test.tsx`: each granularity option shows its limit ("last 7 days", "last 60 days", "kept indefinitely"; unknown shows no limit), and the partial notice in `history-view.test.tsx` names the retention limit when the requested start is before `now − days`.
- [ ] T011 [US2] Implement the labels in `HistoryForm.tsx` (help text under the Granularity select, linked by `aria-describedby`) and the partial-notice reason in `HistoryPage.tsx`; add strings in all three languages. T010 must pass.

## Phase 5: User Story 3 - An administrator can turn collection on, and keep it on (P2)

- [ ] T012 [US3] Write the README section "Turning on history collection". It covers, as an administrator in `%SYS`:
  - activate the two classes and start the Application Monitor;
  - the `%ZSTART` `SYSTEM` entry, with a warning to extend an existing `%ZSTART`;
  - how to check (the route or History);
  - how to change retention (`PerfData.SetPurge`, `Hourly.SetPurge`).

  Run every step on a fresh container and record the times (first sample within 10 minutes; again after a restart) in research R7 (SC-003).
- [ ] T013 [US3] In the `Dockerfile`, after the module load, run the same steps for the image (research R5, FR-010), with a comment that this is the image's own setup, not the module's. In the CI `docker` job, wait up to 10 minutes for `state` `recording` from `/history-collection`.
- [ ] T014 [US3] In `.github/ci/InstallCheck.cls`, before `load` record and after `load` compare `Activated` and `SampInterval` of both History classes, `PerfData.SetPurge("")`, `Hourly.SetPurge("")` and whether `%ZSTART` exists. Any difference fails (FR-006, SC-004). The `ipm-install` job runs the recording step before `load`, through a `Snapshot()` class method that writes to a CI-only global.

## Phase 6: Polish

- [ ] T015 Run everything:
  - the ObjectScript suite;
  - `npm run lint`, `npm test`, build, `check-build` and `check-size`;
  - the full e2e suite;
  - the Docker build and the wait for `recording`.

  Record the numbers in research R8.
- [ ] T016 Docs:
  - fill `CHANGELOG.md` 2.1.0;
  - in `CLAUDE.md`, the open specs line and the Phase 3 line (done as "collection health; no own rollups, retention measured").

  Tick T001–T016.

## Dependencies & Execution Order

- T001, T002 → T003 → T004 → T005.
- US1: T006 → T007 → T008 → T009 (needs T005).
- US2: T010 → T011, after T006.
- US3: T012 any time after T005. T013 needs T012. T014 is independent.
- T015 and T016 last.

## Parallel examples

- After T005: T006 (web fixtures) and T012 (README run-through) and T014 (InstallCheck).

## Implementation strategy

MVP is US1. The route and the History notice already end the "empty screen with no reason" problem. US2 adds the limits. US3 makes the guidance proven and the image useful.
