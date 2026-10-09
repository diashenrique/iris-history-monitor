# Tasks: New Monitor Interface

**Input**: `specs/002-new-ui/` (spec, plan, research, data-model, contracts, quickstart)

**Prerequisites**: spec 001 merged or stacked below (the API this interface reads).

**Tests**: required. Constitution Principle II: tests come first and must fail before the code that makes
them pass. Nothing counts as verified until CI is green.

**Organization**: grouped by user story; each story is a shippable increment behind the switch.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 to US5 from spec.md
- Paths: interface source in `web/`, committed build in `src/web/historymonitor/`, server code in
  `src/cls/diashenrique/historymonitor/` (plan.md "Project Structure")

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: the `web/` project, its tooling and its CI job.

- [x] T001 Scaffold the Vite + React + TypeScript project in `web/` (`web/package.json`, `web/vite.config.ts` with `base: './'`, `web/tsconfig.json` with `strict: true`, `web/index.html`, `web/src/main.tsx`), Node 24 in `web/.nvmrc`, and add `web/node_modules/` to `.gitignore`
- [x] T002 [P] Add ESLint (with `eslint-plugin-jsx-a11y`) and Prettier with `lint`, `format` and `typecheck` scripts in `web/eslint.config.js` and `web/package.json`
- [x] T003 [P] Configure Vitest with jsdom, Testing Library and `vitest-axe` in `web/vitest.config.ts` and `web/tests/setup.ts`
- [x] T004 [P] Configure Playwright with `@axe-core/playwright`, base URL from `HM_BASE_URL`, desktop and 360 px projects, light and dark color schemes in `web/playwright.config.ts`
- [x] T005 Set the Vite build output to `src/web/historymonitor/` (emptied on build, hashed asset names) and write `web/scripts/check-build.mjs` that rebuilds into a temp folder and fails when it differs from the committed `src/web/historymonitor/` (research R12)
- [x] T006 [P] Write `web/scripts/check-size.mjs` that fails when the JavaScript loaded by the first screen exceeds 200 KB gzipped (research R11)
- [x] T007 Add a `web` job to `.github/workflows/ci.yml`: Node 24, `npm ci`, lint, typecheck, unit tests, `check-build.mjs`, `check-size.mjs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: API changes, shared address, sign-in handling, design system, translations and the shell.
**⚠️ CRITICAL**: no story work starts before this phase is done; T016 (owner design review) gates all styled UI (T017 and every screen).

### API contract and server (contract first)

- [ ] T008 Apply `specs/002-new-ui/contracts/api-v1-changes.md` to `specs/001-api-v1/contracts/openapi.yaml`: `servers.url` `/historymonitor/api/v1`, `GET /settings` with schema `Settings` (`required: [interfaceEnabled]`, `interfaceEnabled: boolean`), `info.version` 1.1.0; regenerate `specs/001-api-v1/contracts/openapi.json` with `python scripts/openapi_to_json.py`
- [ ] T009 [P] Write `src/cls/diashenrique/historymonitor/test/api/SettingsTest.cls` (red): `interfaceEnabled` defaults to false; the `/settings` body matches the `Settings` schema via `ContractHelper`; the pure decision `Settings.CanChange(hasAdmin)` returns 1 only for `hasAdmin=1` (the suite runs as a superuser, so the refusal is tested on this method, like `Dispatch.Authorize` in spec 001); `SetInterfaceEnabled` changes the value for the test's superuser (data-model: "changed only by an administrator (`%Admin_Manage:USE`)"); restores the original value afterwards
- [ ] T010 Implement `src/cls/diashenrique/historymonitor/util/Settings.cls`: `InterfaceEnabled()` reading one namespace global node (default 0), `CanChange(hasAdmin)` as the pure access decision, and `SetInterfaceEnabled(flag)` that calls `CanChange($SYSTEM.Security.Check("%Admin_Manage","USE"))` and returns an error status when it is 0; no other writer (research R4)
- [ ] T011 Add `GET /settings` to `src/cls/diashenrique/historymonitor/api/Dispatch.cls` (route `Call="Settings"`, body from `Settings.InterfaceEnabled()`), so T009 passes
- [ ] T012 Move the web applications in `module.xml` (research R3): new `<CSPApplication Url="/historymonitor" Path="/src/web/historymonitor" ... PasswordAuthEnabled="1" UnauthenticatedEnabled="0" CookiePath="/historymonitor/" MatchRoles=":%DB_${Namespace}">`; `<WebApplication Url="/historymonitor/api/v1" ... AutheEnabled="32" CookiePath="/historymonitor/">` replacing `/api/historymonitor/v1`; **keep the existing `<CSPApplication Url="/csp/irismonitor">` unchanged** (the old pages must keep working, FR-024); version 1.7.0 → 1.8.0
- [ ] T013 Update `src/cls/diashenrique/historymonitor/test/api/HttpAuthTest.cls` (create both applications from `module.xml` under a test prefix; add `/settings` to `Routes()`), `test/api/ContractCoverageTest.cls` (`getSettings` → `SettingsTest`) and `.github/ci/InstallCheck.cls` (new URLs, cookie path `/historymonitor/`, class `util.Settings`, and `/csp/irismonitor` still present with its settings unchanged)
- [ ] T014 Write `src/cls/diashenrique/historymonitor/test/api/HttpSessionTest.cls` and make it pass: sign in once through the static application (request `index.html` with credentials), then call `/historymonitor/api/v1/overview` with only the session cookie → 200; a client without the cookie → 401; the session cookie path is `/historymonitor/` (verifies research R3 before any screen work). If a static file does not establish the session (in spec 001 only a class page was measured), sign in through a minimal class page inside the prefix instead, and record which one works in `specs/002-new-ui/research.md` R3

### Interface foundation

- [ ] T015 [P] Create design tokens and themes in `web/src/design/tokens.css` and `web/src/design/theme.ts` (light, dark, `system` default; bundled Inter font in `web/src/design/fonts/`; reduced-motion handling) and a test `web/tests/unit/contrast.test.ts` that fails when a text pair is below 4.5:1 or a status/non-text pair below 3:1 in either theme
- [ ] T016 Build a static mock-up of the Overview in `web/mockup/overview.html` (light and dark, desktop and 360 px, every status, stale state) from the tokens of T015, and get the owner's approval recorded in `specs/002-new-ui/research.md` R10 — **gate for all screen UI** (research R10)
- [ ] T017 Add accessible base components on Radix primitives in `web/src/design/components/` (Button, Select, Switch, Dialog, Tabs, StatusBadge with icon + label + color per FR-004) with axe tests in `web/tests/unit/components.test.tsx`; after T016 is approved, so their look follows the approved mock-up
- [ ] T018 [P] Set up i18next in `web/src/i18n/` with `en.json`, `pt-BR.json`, `es.json`, browser-language detection with fallback `en`, persistence in browser storage, and Intl helpers for numbers, dates and time zone names in `web/src/i18n/format.ts`; test `web/tests/unit/i18n.test.ts` fails when any key is missing in a catalogue (SC-005)
- [ ] T019 [P] Write the API client in `web/src/api/client.ts` with typed calls for `/settings`, `/overview`, `/history/{metric}`, `/processes` relative to `./api/v1`, same-origin credentials, 401 → reload the current address (research R5), 403 → `no-access` state, other errors → problem title only (FR-022); tests in `web/tests/unit/api-client.test.ts`
- [ ] T020 [P] Add API fixtures in `web/tests/fixtures/` (overview with every status and an unavailable metric, history with `partial`, `truncated` + `next`, database series, an hourly series that crosses a daylight-saving change, processes pages) and `web/tests/unit/fixtures-contract.test.ts` that validates each fixture against `specs/001-api-v1/contracts/openapi.json` (research R13)
- [ ] T021 [P] Write the address-state helper `web/src/lib/url-state.ts` per `contracts/ui-routes.md` (parse and serialize each route's parameters; invalid values fall back to the defaults with a notice) with tests in `web/tests/unit/url-state.test.ts`
- [ ] T022 Build the shell in `web/src/App.tsx` and `web/src/shell/`: providers (TanStack Query, i18n, theme), hash routes `#/`, `#/history`, `#/processes`, `#/processes/:pid`, layout and navigation, skip link, document title and focus on route change, and the `not-enabled` (from `/settings`, read at load and again every 60 s while the interface is open, so turning it off reaches open screens; with a link to the old pages), `no-access` (naming `HistoryMonitorViewer`) and `error` screens; tests in `web/tests/unit/shell.test.tsx`
- [ ] T023 Add an `e2e` job to `.github/workflows/ci.yml` and `web/tests/e2e/global-setup.ts`: IRIS container, IPM 0.10.9 install of the repository, `SYS.History.SysData.Demo(90)`, a viewer and a user without the role, `SetInterfaceEnabled(1)`, then `npx playwright test`; plus `web/tests/e2e/not-enabled.spec.ts` for the switch-off page and for switching off while a screen is open (the screen changes to `not-enabled` within 60 s)

**Checkpoint**: the shell loads at `/historymonitor/`, one sign-in reaches the API, the switch works, design approved.

---

## Phase 3: User Story 1 - Overview at a glance (Priority: P1) 🎯 MVP

**Goal**: the live Overview with every metric, status order, trend and stale handling.
**Independent Test**: switch on, sign in as a viewer, compare every figure with `GET /overview` (spec US1).

### Tests (write first, must fail)

- [ ] T024 [P] [US1] Component tests in `web/tests/unit/overview.test.tsx`: all 18 metrics with value, unit and status; display order `critical`, `unavailable`, `warning`, `ok` and API order inside a status (data-model OverviewState); unavailable shows the API reason; status has icon and label; axe passes
- [ ] T025 [P] [US1] Live-behaviour tests with fake timers in `web/tests/unit/overview-live.test.tsx`: refresh every 10 s, pause stops it, a hidden tab stops it, a failed refresh keeps figures and marks them stale with the last success time, the next success clears stale, the trend keeps the last 60 values per numeric metric
- [ ] T026 [P] [US1] End-to-end `web/tests/e2e/overview.spec.ts`: spec US1 scenarios 1 to 4, every figure equals `GET /overview` read in the same test, the complete Overview appears within 2 s of opening (SC-002), axe in light and dark, 360 px, every request under `/historymonitor/` (SC-006)

### Implementation

- [ ] T027 [US1] Implement `web/src/features/overview/useOverview.ts` (TanStack Query, `refetchInterval` 10 s, pause, hidden-tab pause, `lastSuccessAt`, `stale`, trend buffer of 60 values cleared on reload) so T025 passes
- [ ] T028 [P] [US1] Implement `web/src/features/overview/Sparkline.tsx` (inline SVG, no chart library, text alternative "from X to Y over N minutes")
- [ ] T029 [P] [US1] Implement `web/src/features/overview/MetricCard.tsx` (value and unit through `format.ts`, `StatusBadge`, reason for unavailable, sparkline for numeric metrics)
- [ ] T030 [US1] Implement `web/src/features/overview/OverviewPage.tsx` (ordered grid per the approved mock-up, last-updated time, stale banner, pause switch, polite live region for status changes only) so T024 passes
- [ ] T031 [US1] Add the Overview strings to `en.json`, `pt-BR.json`, `es.json` in `web/src/i18n/`
- [ ] T032 [US1] Rebuild into `src/web/historymonitor/`, commit, and run quickstart steps 1 to 3 on a local IRIS container; T026 green in CI

**Checkpoint**: US1 shippable on its own (switch on → Overview).

---

## Phase 4: User Story 2 - History (Priority: P1)

**Goal**: one history screen for license, CSP sessions and database size with chart, table and coverage.
**Independent Test**: each metric and granularity over a known period equals the API (spec US2).

### Tests (write first, must fail)

- [ ] T033 [P] [US2] Form and address tests in `web/tests/unit/history-form.test.tsx`: presets `24h`, `7d`, `30d`, `90d` and custom range; local times converted to UTC; `databases` only for `database-size`; the address round-trips (FR-013); invalid address values fall back to `metric=license`, `granularity=hourly`, `preset=7d` with a notice
- [ ] T034 [P] [US2] Paging tests in `web/tests/unit/history-data.test.ts`: `limit=5000`, follows `next` until complete, stops after 20 pages with `complete=false` and a "load more" action (research R8), merges pages in time order, keeps the first page's `coverage` and `partial`
- [ ] T035 [P] [US2] View tests in `web/tests/unit/history-view.test.tsx`: chart and table show the same points; times in the local zone with its name; across a daylight-saving change the points stay in time order and no time is shown twice or skipped (spec Edge Cases); partial notice states first and last time present; no-data message; database picker; axe passes
- [ ] T036 [P] [US2] End-to-end `web/tests/e2e/history.spec.ts`: spec US2 scenarios 1 to 6 on demo data, points equal the API, 90-day view within 3 s (SC-002), every request under `/historymonitor/` (SC-006), axe light and dark, 360 px

### Implementation

- [ ] T037 [US2] Implement `web/src/features/history/useHistory.ts` (query from address state, paging per research R8) so T034 passes
- [ ] T038 [P] [US2] Implement `web/src/features/history/HistoryForm.tsx` (metric, granularity, presets, custom range, database multi-select)
- [ ] T039 [P] [US2] Implement `web/src/features/history/HistoryChart.tsx` lazily loaded, with modular ECharts (line chart, tooltip, data zoom, legend), light and dark themes, ARIA description enabled, reduced motion respected
- [ ] T040 [P] [US2] Implement `web/src/features/history/HistoryTable.tsx` and the coverage, partial and no-data notices
- [ ] T041 [P] [US2] Implement CSV export in `web/src/lib/csv.ts` (UTF-8 with BOM, ISO UTC times plus a local-time column) with tests in `web/tests/unit/csv.test.ts`
- [ ] T042 [US2] Implement `web/src/features/history/HistoryPage.tsx` wiring form, chart, table and export to the address so T033 and T035 pass
- [ ] T043 [US2] Add the History strings to the three catalogues in `web/src/i18n/`
- [ ] T044 [US2] Rebuild, commit `src/web/historymonitor/`, quickstart step 4; T036 green in CI and the first-screen size check still under 200 KB

**Checkpoint**: US1 and US2 work independently.

---

## Phase 5: User Story 3 - Processes (Priority: P2)

**Goal**: find, sort, page and inspect processes with server-side filtering.
**Independent Test**: a filtered, sorted page equals the API (spec US3).

### Tests (write first, must fail)

- [ ] T045 [P] [US3] Component tests in `web/tests/unit/processes.test.tsx`: filters `namespace`, `user`, `state`, `q` (at most 100 characters), sort by any column with `-` for descending, `pageSize` one of 25, 50, 100 (default 50), total shown, detail shows only the fields present, refresh every 15 s pausable, a process that disappears does not raise an error; axe passes
- [ ] T046 [P] [US3] End-to-end `web/tests/e2e/processes.spec.ts`: spec US3 scenarios 1 to 3, rows and total equal the API, CSV export downloads the shown page, every request under `/historymonitor/` (SC-006), axe, 360 px

### Implementation

- [ ] T047 [US3] Implement `web/src/features/processes/useProcesses.ts` (query from address, previous data kept while loading, 15 s refresh with pause)
- [ ] T048 [P] [US3] Implement `web/src/features/processes/ProcessFilters.tsx`
- [ ] T049 [P] [US3] Implement `web/src/features/processes/ProcessTable.tsx` with TanStack Table in manual sorting and paging mode, horizontal scroll inside the table at narrow widths
- [ ] T050 [P] [US3] Implement `web/src/features/processes/ProcessDetail.tsx` as a dialog on `#/processes/:pid`
- [ ] T051 [US3] Implement `web/src/features/processes/ProcessesPage.tsx` with CSV export of the shown page so T045 passes
- [ ] T052 [US3] Add the Processes strings to the three catalogues; rebuild and commit; quickstart step 5; T046 green in CI

**Checkpoint**: three screens work independently.

---

## Phase 6: User Story 4 - Sign in once (Priority: P2)

**Goal**: one sign-in for every screen, clean expiry and a clear no-access screen (the mechanics landed in T014, T019, T022).
**Independent Test**: spec US4 scenarios on the three screens.

- [ ] T053 [P] [US4] End-to-end `web/tests/e2e/session.spec.ts`: move across all screens without a credentials prompt; end the session (IRIS logout parameter) and act: sign-in page, then back to the same address; two tabs share the sign-in; the user without the role sees `no-access` naming `HistoryMonitorViewer` and no data
- [ ] T054 [US4] Fix any gap T053 finds in `web/src/api/client.ts` or `web/src/shell/`; record the IRIS login page gap (research R5) in the pull request

**Checkpoint**: US1 to US4 complete.

---

## Phase 7: User Story 5 - Language, accessibility, screen size (Priority: P3)

**Goal**: en, pt-BR, es; light and dark; keyboard and screen reader; 360 px.
**Independent Test**: every screen in each language and theme, keyboard only, screen reader, phone width, audit.

- [ ] T055 [P] [US5] End-to-end `web/tests/e2e/a11y-i18n.spec.ts`: each screen in the three languages (numbers, dates and zone names change without reload, the choice survives a reload), keyboard-only main task per screen with visible focus, axe with no critical or serious issue in both themes (SC-004), no page-level horizontal scroll at 360 px (SC-007)
- [ ] T056 [US5] Add the language and appearance switchers to the shell header in `web/src/shell/Header.tsx` (appearance `system`, `light`, `dark`; stored per browser)
- [ ] T057 [US5] Fix the issues T055 reports in the affected components; rebuild and commit; quickstart step 7

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T058 Point the Management Portal favourite in `module.xml` (`util.Favorite` invoke) to `/historymonitor/` (FR-024, research R14)
- [ ] T059 [P] Add the obsolete banner with a link to `/historymonitor/` to `src/csp/dashboard.csp`, `dashboardapi.csp`, `historylicense.csp`, `historycspsessions.csp`, `historydatabase.csp`, `systemprocesses.csp`; confirm their old URLs still answer
- [ ] T060 [P] Write the moderated test guide for SC-001 and SC-008 (five operators, tasks, timing, rating question) in `specs/002-new-ui/usability-test.md` for the owner to run
- [ ] T061 Walk through `quickstart.md` on a fresh IPM-installed container, measure SC-002 in a browser, record results and differences in `specs/002-new-ui/research.md`
- [ ] T062 Update `CLAUDE.md` (Phase 4 status, `web/` workflow), `module.xml` version, and open the pull request stating what was and was not verified (including SC-001 and SC-008 as owner-run)

---

## Dependencies & Execution Order

- **Setup (T001–T007)** first. **Foundational (T008–T023)** blocks every story; inside it, the server
  tasks run in order T008 → T009 → T010 → T011 → T012 → T013 → T014, and the order
  T015 (tokens) → T016 (mock-up approved by the owner) → T017 (components) gates all styled UI
  (T022 may scaffold routes and logic before approval, but no styling).
- **US1 (P1)** after Foundational: the MVP. **US2 (P1)** and **US3 (P2)** depend only on Foundational
  and can run in parallel with US1 once the shell exists. **US4** verifies across screens, so it needs at
  least US1 and is completed after US3. **US5** checks every screen, so it runs after US1 to US3.
- **Polish (T058–T062)** after all stories; T058 and T059 only once all three screens are done (FR-024).
- Inside each story: tests → hooks/data → components → page → strings → build and quickstart.

## Parallel Examples

- Setup: T002, T003, T004, T006 together after T001.
- Foundational: T015, T018, T019, T020, T021 together; T009 alongside them; T017 after T016.
- US1: T024, T025, T026 together; then T028 and T029 together.
- US2: T033 to T036 together; then T038 to T041 together.
- US3: T045 and T046 together; then T048 to T050 together.

## Implementation Strategy

1. **MVP**: Setup + Foundational + US1. Switch on at one test instance; the Overview replaces the two old
   dashboards. Stop and validate with the owner (quickstart 1–3).
2. **Increment 2**: US2 History. **Increment 3**: US3 Processes. Each ships behind the same switch.
3. **Increment 4**: US4 and US5 across all screens, then Polish (old pages obsolete, favourite moved).
4. Every increment is a pull request with green CI (`unit-tests`, `ipm-install`, `web`, `e2e`).
