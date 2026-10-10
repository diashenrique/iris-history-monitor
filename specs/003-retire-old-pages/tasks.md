---
description: "Tasks for spec 003, retire the old pages"
---

# Tasks: Retire the old pages

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/forwarding.md](contracts/forwarding.md), [quickstart.md](quickstart.md)

**Tests**: required (constitution II; spec FR-011). Test tasks come before the code they cover.

Paths: `HM` = `src/cls/diashenrique/historymonitor`.

## Phase 1: Setup

- [x] T001 Set the version to 2.0.0 in `module.xml` and open a `## 2.0.0 (unreleased)` section at the top of `CHANGELOG.md` (FR-008)
- [x] T002 Amend constitution Principle I to 1.1.0 as research R6 words it, then update the matching code rules in `CLAUDE.md` (no `util.Dispatcher`, no `metrics.IsAllowedTarget`; requests through `%CSP.REST` URL maps; no outbound call to a request-derived host) in `.specify/memory/constitution.md` and `CLAUDE.md`

## Phase 2: Foundational

- [x] T003 Write `HM/test/api/RetireTest.cls` (fails first). The targets of `util.Retire` are class parameters (packages, classes, folder, globals). The test uses a subclass `HM/test/api/RetireFixture.cls` that points them at test-only names, so it never touches the real classes while they still exist (analysis F2). The real target names are checked by `InstallCheck` (T012) and the upgrade job (T013). It seeds every kind of leftover in the [data-model.md](data-model.md) table under test names:
  - a stub class in a test package standing in for `diashenrique.historymonitor.dashboard`;
  - stub classes standing in for `util.metrics`, `util.Dispatcher` and `util.Settings`;
  - stub classes standing in for the six `csp.*` pages;
  - a test-only folder standing in for `${cspdir}irismonitor/`;
  - test globals standing in for `^IRISMonitor` and `^diashenrique.historymonitor.Settings`;
  - plus one unrelated class and one unrelated global that must survive.

  Then it asserts that `util.Retire.Run()` removes the leftovers and keeps `csp.KeepMe`, `^HMRetireKeep`, `HistoryMonitorViewer` and the namespace, that a second `Run()` removes nothing, and that it returns `$$$OK`.
- [x] T004 Implement `HM/util/Retire.cls`: `Run()` deletes, if present and only in the current namespace:
  - the classes `diashenrique.historymonitor.dashboard.*`, `util.metrics`, `util.Dispatcher` and `util.Settings`;
  - the six compiled page classes `csp.dashboard`, `csp.dashboardapi`, `csp.historycspsessions`, `csp.historydatabase`, `csp.historylicense` and `csp.systemprocesses`;
  - the folder `$SYSTEM.Util.InstallDirectory()_"csp/irismonitor/"` (check on `iris-hm` that it is the folder IPM's `${cspdir}irismonitor/` resolves to; analysis L1);
  - `^IRISMonitor` and `^diashenrique.historymonitor.Settings`.

  All targets are class parameters (T003). It writes one line per removal and touches no namespace or database (R3, FR-005, FR-006). T003 must pass.

**Checkpoint**: the cleanup exists and is proven on seeded leftovers.

## Phase 3: User Story 1 - An old address leads to the new monitor (P1) MVP

**Goal**: every address under `/csp/irismonitor` answers 302 to the matching screen ([contracts/forwarding.md](contracts/forwarding.md)).

**Independent test**: `curl -si` each row of the contract; follow each in a browser.

- [x] T005 [P] [US1] Write `HM/test/api/ForwardTest.cls` (fails first):
  - `Target(path)` returns the contract target for each of the five named pages, matching case-insensitively and ignoring the query string;
  - `dashboardapi.csp`, `/`, `resources/x.css`, `diashenrique.historymonitor.dashboard.license.cls`, a path with `../`, and a value with `#`, CR/LF or `javascript:` all map to `/historymonitor/index.html#/`;
  - every result is one of the six fixed strings. This is the regression test for the amended Principle I rule "a request never selects which code runs" (analysis C2).

  Over HTTP, a test copy of the forwarding app under `/csp/irismonitor-test` built from `module.xml` (like HttpAuthTest) is checked for each row, with no credentials, for GET, HEAD and POST. It must answer `302`, the exact `Location`, `Cache-Control: no-store`, and no set-cookie of `/historymonitor/` (R2: UnknownUser can run it).
- [x] T006 [US1] Implement `HM/web/Forward.cls` (`%CSP.REST`): override `DispatchRequest` so every method and path answers per the contract through `ClassMethod Target(path As %String) As %String`, with a fixed map from the lowercased last path segment and the Overview by default. Set `%response.Status = "302 Found"`, `Location` and `Cache-Control: no-store`, and write no body. T005 must pass.
- [x] T007 [US1] In `module.xml`:
  - replace the old-pages `<WebApplication Url="/csp/irismonitor" ...>` with `Url="/csp/irismonitor" DispatchClass="diashenrique.historymonitor.web.Forward" AutheEnabled="64" MatchRoles="" CookiePath="/csp/irismonitor/"`, and set `ServeFiles` and `AutoCompile` to 0;
  - drop the `<FileCopy Name="src/csp/" ...>`, the `LoadPageDir` invoke and the `dashboard.PKG` resource;
  - add the `web.Forward` class to the `web` package (already a resource);
  - add a comment that the forwarding stays for all of 2.x (FR-003);
  - make `HttpAuthTest.ReadWebApplication` in `HM/test/api/HttpAuthTest.cls` pick the element with `Url="/historymonitor/api/v1"`, not the first one with a `DispatchClass`, because the forwarding app now has one and comes first (analysis F1).

  If the T005 HTTP check shows that UnknownUser cannot run the class, use `MatchRoles=":%DB_${Namespace}"` instead and record it in research R2.
- [x] T008 [P] [US1] Write `web/tests/e2e/forwarding.spec.ts`. Signed in (saved session), opening each of the five old page addresses lands on the matching screen: the Overview heading, History with the metric select on license, CSP sessions or database size, and the Processes heading. An unknown old address lands on the Overview. Signed out (fresh context), `/csp/irismonitor/historylicense.csp` shows the sign-in form, and after sign-in History is on license. Replaces `web/tests/e2e/old-pages.spec.ts` (delete it).

**Checkpoint**: US1 works on an install that still has the old code (the forwarding app replaces the page app).

## Phase 4: User Story 2 - An upgrade leaves nothing of the old pages behind (P1)

**Goal**: install, upgrade and uninstall leave no 1.x leftovers; everything else is unchanged.

**Independent test**: [quickstart.md](quickstart.md) steps 1, 2 and 6.

- [x] T009 [US2] Delete the old code and its test:
  - `src/csp/` (pages and `resources/`, 1,400 files);
  - `HM/dashboard/` (5 classes);
  - `HM/util/Dispatcher.cls` and `HM/util/metrics.cls`;
  - `HM/test/SecurityTest.cls` (it tests only these).

  Then confirm with a grep that no remaining class or file under `src/`, `web/` or `.github/` names them.
- [x] T010 [US2] Remove the switch:
  - delete `HM/util/Settings.cls` and `HM/test/api/SettingsTest.cls`;
  - make `Dispatch.SettingsResponse()` in `HM/api/Dispatch.cls` return `interfaceEnabled: true` always (R5);
  - in `specs/001-api-v1/contracts/openapi.yaml` (and the generated `openapi.json`, via `scripts/openapi_to_json.py`), mark `interfaceEnabled` `deprecated: true` with the description "Always true since 2.0.0; the switch was removed".

  Update any test that calls `Settings` (`HttpAuthTest`, `HttpSessionTest`, `ContractHelper` users) to stop doing so.
- [x] T011 [US2] In `module.xml`, invoke `diashenrique.historymonitor.util.Retire:Run` after Activate, and before Unconfigure (R3, R4). Verify on `iris-hm`:
  - `load` 1.9.3, use `historylicense.csp` once, then `load` this branch;
  - expect every leftover gone and the new monitor working;
  - then `zpm "uninstall iris-history-monitor"` and check that nothing remains.

  If the Unconfigure invoke does not run on IPM 0.10.9, document the manual `Retire.Run()` step in `README.md` and update research R4.
- [x] T012 [US2] Update `.github/ci/InstallCheck.cls`:
  - drop the old-page checks (`AutoCompile`, `csp.dashboard` compiled, the old cookie path);
  - add checks that `/csp/irismonitor` has `DispatchClass=diashenrique.historymonitor.web.Forward` and `AutheEnabled=64`;
  - check that no class of `diashenrique.historymonitor.dashboard`, `util.metrics`, `util.Dispatcher`, `util.Settings` or the six `csp.*` pages exists, and that `^IRISMonitor` and `^diashenrique.historymonitor.Settings` are not defined;
  - keep every API and interface check.
- [x] T013 [US2] Add an upgrade path to the `ipm-install` job in `.github/workflows/ci.yml`: install `master`'s module first (the last 1.x on `master`, through `git worktree` or `git show`), request one old page so it writes `^IRISMonitor`, then `load` the PR's module, then run `InstallCheck`. Keep the fresh-install run as it is.

**Checkpoint**: SC-002 and SC-003 are proven in CI.

## Phase 5: User Story 3 - The new monitor no longer depends on the old one (P2)

**Goal**: no screen, document or image refers to or offers the old pages or the switch.

**Independent test**: grep the shipped product and docs; `npm test`; e2e.

- [x] T014 [P] [US3] Update the Vitest tests first in `web/tests/unit/shell.test.tsx` (and any other test that uses `NotEnabledScreen` or an `interfaceEnabled: false` fixture):
  - with `/settings` answering `interfaceEnabled: false` or `true`, the shell shows the app;
  - no rendered text links to `/csp/irismonitor`.
- [x] T015 [US3] In the interface:
  - remove `NotEnabledScreen` and its `notEnabled.*` strings in all three languages, from `web/src/shell/screens.tsx` and `web/src/i18n/{en,pt-BR,es}.json`;
  - remove the `interfaceEnabled` gate in `web/src/App.tsx` (keep the `/settings` call as the sign-in and role check);
  - in `web/src/api/types.ts`, mark `interfaceEnabled` `@deprecated`.

  Rebuild with `npm run build` (committed to `src/web/historymonitor/`). T014 must pass, and `check-build` and `check-size` must pass.
- [x] T016 [P] [US3] E2E:
  - delete `web/tests/e2e/not-enabled.spec.ts`;
  - remove `setInterfaceEnabled` from `web/tests/e2e/support.ts` and its callers;
  - in `.github/ci/e2e-setup.sh`, stop calling `SetInterfaceEnabled`;
  - add to `web/tests/e2e/a11y-i18n.spec.ts` (or `forwarding.spec.ts`) a check that no link on any screen has an `href` containing `/csp/irismonitor`.
- [x] T017 [P] [US3] Container image:
  - in `Dockerfile`, stop calling `SetInterfaceEnabled`, and in its comment drop "where the old pages keep their scratch data";
  - fix the same comment in `Installer.cls`;
  - keep `zn "IRISMONITOR"` (R7);
  - in `.github/workflows/ci.yml` (`docker` job), replace the banner check with `curl -si /csp/irismonitor/dashboard.csp` → `302` and `Location: /historymonitor/index.html#/`, and drop the `/settings` interfaceEnabled check or expect `true`.
- [x] T018 [P] [US3] Docs:
  - in `README.md`, drop "The old pages", the switch step and the DevExtreme note, and add "Upgrading from 1.x" (old addresses forward, what the upgrade removes, major version);
  - in `CHANGELOG.md`, fill 2.0.0: removed, forwarding table and that it stays for all of 2.x (FR-003), cleanup, switch removed, `interfaceEnabled` deprecated (FR-009);
  - in `docs/releasing.md`, drop the switch step;
  - in `specs/002-new-ui/usability-test.md`, drop the switch step, task 4 (old pages comparison) and the SC-008 question, and mark SC-008 withdrawn in `specs/002-new-ui/spec.md`. Add a research entry in `specs/002-new-ui/research.md` giving the reason: the old pages no longer exist to compare against (analysis A1).

## Phase 6: Polish & Cross-Cutting

- [x] T019 Run everything:
  - the ObjectScript suite on `iris-hm` (`test.Runner`), all methods passing;
  - `npm run lint`, `npm test`, `npm run build`, `check-build` and `check-size`;
  - the full e2e suite against `iris-hm`;
  - a Docker image build and a smoke test.

  Record the numbers in research (new entry R8, "Delivery results").
- [x] T020 Update `CLAUDE.md`:
  - Code location, now `api`, `service`, `util` and `web`, with no `dashboard` and no `src/csp`;
  - Phase backlog: Phase 2 done, scratch globals gone; Phase 4 done, old pages removed;
  - "Open specs" with spec 003 status.

  Tick T001 to T020 in this file.

## Dependencies & Execution Order

- T001 and T002 first. T003 → T004 (Foundational) blocks US2's T011.
- US1: T005 → T006 → T007. T008 can be written alongside and needs T007 installed.
- US2: T009 needs T007, which stops serving the pages first. T010, then T011 (needs T004 and T009), then T012 → T013.
- US3: T014 → T015. T016, T017 and T018 are parallel after T010.
- T019 and T020 last.

## Parallel examples

- After T004: T005 (ForwardTest) and T014 (shell tests) touch different files.
- After T010: T016, T017 and T018 in parallel.

## Implementation strategy

MVP is US1. The forwarding alone, on top of 1.9.3, already makes the old addresses safe. US2 then deletes the code and cleans up. US3 removes the last references. Everything ships together as 2.0.0, because removing the pages is the breaking change.
