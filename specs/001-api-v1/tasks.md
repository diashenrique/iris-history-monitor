# Tasks: Versioned Read API (v1)

**Input**: `specs/001-api-v1/` (spec, plan, research, data-model, contracts)
**Format**: `- [ ] ID [P] [Story] Description with file path`. `[P]` means it can run in parallel with other `[P]` tasks.
**Rule**: tests come first and must fail before the code that makes them pass.
Nothing counts as verified until the CI run is green (T001).

## Phase 1: Setup and gate

- [x] T001 Repair the CI so IRIS stays up and `%UnitTest` runs: `.github/workflows/ci.yml`, `src/cls/diashenrique/historymonitor/test/Runner.cls` (branch `fix/ci-diagnostics` has an attempt; read `docker logs` first)
- [x] T002 [P] Create the empty class skeletons and the `test/api/` folder: `src/cls/diashenrique/historymonitor/{api,service}/`, `test/api/`
- [x] T003 [P] Add `util/Security.cls` that creates the monitor resource and a role holding it: `src/cls/diashenrique/historymonitor/util/Security.cls`

## Phase 2: Foundation (blocks every story)

- [x] T004 [P] Write tests for `Problem` (shape, content type, status) in `test/api/ProblemTest.cls`
- [x] T005 [P] Write tests for `Validate` (dates, range order, enums, limit bounds, database name pattern, injection strings) in `test/api/ValidateTest.cls`
- [x] T006 Measure System Monitor retention for 5-minute, hourly and daily tables on the reference image and record it in `research.md` under R2
- [x] T007 Implement `service/Validate.cls` and `api/Problem.cls` so T004 and T005 pass
- [x] T008 Implement `api/Dispatch.cls` with the URL map, authentication check, and error mapping to `Problem`; add the web application and version bump to `module.xml`
- [x] T009 [P] Write the authorization test (no credentials 401, no role 403, role 200) in `test/api/AuthTest.cls`
- [x] T010 Add the contract-test helper that compares a response with the contract in `test/api/ContractHelper.cls` (reads `contracts/openapi.json`, generated from the YAML by `scripts/openapi_to_json.py`; CI checks they match)

## Phase 3: User Story 1 - Overview (P1)

- [x] T011 [P] [US1] Contract test for `GET /overview` including the unavailable-metric and never-backed-up cases in `test/api/OverviewTest.cls`
- [x] T012 [US1] Implement `service/Overview.cls` from `SYS.Stats.Dashboard.Sample()` and the SAM sensors; set `status` per metric
- [x] T013 [US1] Add the `/overview` route in `api/Dispatch.cls`

## Phase 4: User Story 2 - History (P1)

- [x] T014 [P] [US2] Contract tests for `GET /history/{metric}`: each metric and granularity, ascending order, empty range, bad dates, unknown metric, truncation with cursor, coverage and `partial` in `test/api/HistoryTest.cls`
- [x] T015 [P] [US2] Concurrency test: two overlapping requests with different ranges return only their own data in `test/api/ConcurrencyTest.cls`
- [x] T016 [US2] Implement `service/History.cls` with parameterized SQL on the four history tables, timestamp cursor and coverage
- [x] T017 [US2] Add the `/history/{metric}` route in `api/Dispatch.cls`

## Phase 5: User Story 3 - Processes (P2)

- [x] T018 [P] [US3] Contract tests for `GET /processes`: filter, sort allow-list, paging, total, ended-process page, empty fields omitted in `test/api/ProcessesTest.cls`
- [x] T019 [US3] Implement `service/Processes.cls` over `%SYS.ProcessQuery` `CONTROLPANEL`
- [x] T020 [US3] Add the `/processes` route in `api/Dispatch.cls`

## Phase 6: User Story 4 - Errors and access (P2)

- [x] T021 [US4] Run `AuthTest` and `ProblemTest` against every route and fix gaps in `api/Dispatch.cls` (done over real HTTP in `test/api/HttpAuthTest.cls`; research.md R11)
- [x] T022 [P] [US4] Check that no route response differs from `contracts/openapi.yaml` and no route lacks a test

## Phase 7: User Story 5 - Existing pages read the API (P3)

- [ ] T023 [P] [US5] Write the `api.js` helper with the response mappers for each page shape in `src/csp/resources/js/api.js`
- [ ] T024 [P] [US5] Record before-and-after figures of the six pages for comparison in `specs/001-api-v1/page-comparison.md`
- [ ] T025 [US5] Switch the request calls in `src/csp/dashboard.csp`, `dashboardapi.csp`, `historylicense.csp`, `historycspsessions.csp`, `historydatabase.csp`, `systemprocesses.csp` to `api.js`
- [ ] T026 [US5] Mark the old `dashboard/` and `util/metrics` classes deprecated in their class comments and confirm their URLs still respond

## Phase 8: Polish

- [ ] T027 [P] Re-run the Phase 1 security tests and the whole suite; confirm green CI
- [ ] T028 [P] Walk through `quickstart.md` on a fresh instance and note any difference
- [ ] T029 Update `CLAUDE.md` phase backlog and `module.xml` version, and open the pull request describing what was and was not verified

## Dependencies

- T001 gates every claim of "verified". Phase 2 blocks all stories. US1, US2 and US3 can proceed in parallel after Phase 2.
- US4 needs at least one route. US5 needs US1 to US3.
- Inside each story: test, then service, then route.
