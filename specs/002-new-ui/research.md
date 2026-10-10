# Research: New Monitor Interface

Each entry: decision, rationale, alternatives. References to "001 Rn" point to `specs/001-api-v1/research.md`.

## R1. Front-end stack
- **Decision**: React with TypeScript, built with Vite into static files (the constitution's "Technical
  Constraints" fix these three). Node 24 LTS for the build only; nothing runs on Node in production.
- **Rationale**: required by the constitution; static output is what an IRIS web application can serve.
- **Alternatives**: none considered; a different stack would need a constitution amendment.

## R2. Libraries, each tied to a requirement
The constitution forbids dependencies a spec does not require, so every runtime library maps to a requirement:

| Need | Choice | Requirement | Why not the alternative |
| --- | --- | --- | --- |
| Interactive history charts with zoom, tooltips, dark theme and an accessibility mode | Apache ECharts (Apache-2.0), imported module by module, loaded only by the history screen | FR-008, FR-019, "modern and dynamic" | Highcharts (the old pages) needs a commercial licence for many users of an open-source tool; Recharts lacks built-in zoom and an ARIA description mode |
| Polling, pause, retry, "last success" time, paging through `next` | TanStack Query | FR-005, FR-009, FR-011 | Hand-written polling would re-implement retry, focus refetch and cache rules |
| Process table with server-side sort and paging | TanStack Table (headless) | FR-011 | A grid product (DevExtreme, the old pages) brings its own styling, licence and weight |
| Routes and view state in the address | React Router, hash routes | FR-013 | History-API routes need server rewrites that IRIS static serving does not do (R6) |
| Accessible dialogs, menus, selects, switches | Radix UI primitives | FR-019 | Building focus traps and ARIA patterns by hand is error-prone |
| Styling with light and dark tokens | Tailwind CSS with CSS variables | FR-020, FR-021 | Component kits with fixed themes fight the custom design |
| Translations with plurals | i18next + react-i18next; numbers and dates through the browser's Intl | FR-017, FR-018 | Intl alone has no message catalogues |

Sparklines on the Overview are a small inline SVG component, not a chart library, so the first screen
stays light (R11). Fonts and icons are bundled; nothing is loaded from a CDN (SC-006).

## R3. One address prefix for interface and API (FR-025)
- **Decision**: serve everything under **`/historymonitor/`**:
  - `/historymonitor/` → static web application with the built interface (password authentication,
    no anonymous access, session cookie path `/historymonitor/`);
  - `/historymonitor/api/v1` → the REST application of spec 001 (same dispatch class and checks), session
    cookie path `/historymonitor/`.
  IRIS routes a request to the web application with the longest matching path, so the API keeps its own
  application inside the prefix. Both share the session cookie because they share the cookie path
  (measured in 001 R12 with path `/`; the narrower path is verified by the first implementation task, before any screen work).
- **Measured (task T014, 2026-10-09)**: a static file of the interface application is served without a
  sign-in and **does not open a CSP session**, so it cannot start the shared session. A class page inside the
  same application does: unauthenticated it shows the IRIS login form; after sign-in it sets the session
  cookie with path `/historymonitor/...` (not `/`), and the API accepts that cookie (200), while a client
  without it gets 401. The interface therefore signs in through `web.Login` (R5). Serving `index.html`
  without a sign-in exposes no data: every figure comes from the API, which requires the session.
- **Measured (task T023)**: IRIS web applications have no default document, so `/historymonitor/` answers
  404; only named files are served. The entry address is therefore `/historymonitor/index.html` (the login
  page already returns there, and the Management Portal favourite of T058 points there).
  The old address `/api/historymonitor/v1` is removed: nothing has been released with it (spec 001 lives
  in unmerged pull requests), and keeping two addresses would keep two sessions.
- **Rationale**: owner's answer to FR-025; the session is visible only to these two applications.
- **Alternatives**: cookie path `/` (rejected by the owner); keeping the API at `/api/...` with a proxy
  (adds a hop and a component the constitution does not need).

## R4. The instance-wide switch (FR-002)
- **Decision**: a single setting `interfaceEnabled` (default false), stored in a namespace global owned by
  a new class `util.Settings`, changed only by `util.Settings.SetInterfaceEnabled(flag)`, which requires
  `%Admin_Manage:USE`. The access decision is a pure method, `CanChange(hasAdmin)`, so the refusal can be
  tested although the suite runs as a superuser (the pattern of `Dispatch.Authorize` in spec 001). The API gains one read-only route, `GET /settings`, returning
  `{"interfaceEnabled": bool}` to any monitor viewer (contract change in `contracts/api-v1-changes.md`).
  The interface shell always loads, reads `/settings` first, and shows a "not enabled" page with a link to
  the old pages when the switch is off. The overview, history and process routes stay available either
  way, because they are the API, not the interface.
- **Rationale**: the web application's own Enabled flag would turn the address into a bare 404, which
  cannot explain anything (FR-002). A setting written only by an administrator is configuration, not the
  per-request scratch state Principle IV forbids.
- **Alternatives**: a build-time flag (needs a rebuild to switch); a per-user flag (not required, spec
  Assumptions); disabling the web application (no explanation shown).

## R5. Sign-in, session expiry, no access (FR-014 to FR-016)
- **Decision** (revised after the T014 measurement in R3): the interface signs in through a small class
  page, `web.Login`, in the interface application. On a 401 from the API (empty body, 001 R11), and on the
  first load without a session, the interface goes to
  `diashenrique.historymonitor.web.Login.cls?return=<current hash route>`. IRIS shows its login form; after
  sign-in the page redirects to `index.html` plus the route, so the user returns to the same view. The
  route is kept only when it is a plain hash route of URL-safe characters (no open redirect). A 403 problem from the API
  shows the "no access" screen naming the role `HistoryMonitorViewer`.
- **Rationale**: reuses the instance's accounts and login (FR-014) with no new authentication code.
- **Known gap**: the login page is IRIS's standard page, not part of this interface; its languages and
  accessibility are IRIS's. Recorded so it is not mistaken for a tested part of this feature.
- **Alternatives**: a custom login form posting credentials (more code, handles passwords itself).

## R6. Routing and address state (FR-013)
- **Decision**: hash routes, for example `#/history?metric=license&granularity=hourly&from=...&to=...`.
  The full view state (screen, metric, granularity, period, databases, process filters, sort, page) is in
  the hash; preferences (language, appearance) are in browser storage.
- **Rationale**: IRIS static serving has no fallback to `index.html` for unknown paths; hash routes always
  request `index.html`. Reloading the address restores the view, which R5 relies on.
- **Alternatives**: path routes plus a CSP page that returns `index.html` (extra server code for no user gain).

## R7. Live Overview and its trend (FR-005, FR-006)
- **Decision**: poll `GET /overview` every 10 s (pausable). Keep the last 60 numeric values per metric in
  memory (10 minutes) for the sparkline. A failed refresh keeps the last figures, marks them stale with the
  last success time, and retries with back-off; polling also pauses while the browser tab is hidden.
- **Rationale**: the API returns snapshots only; a short in-memory trend gives the "dynamic" feel without
  new server state (spec Assumptions).

## R8. Complete history series (FR-009)
- **Decision**: request with `limit=5000` and follow `next` until the series is complete, up to 20 pages
  (100,000 timestamps); past that the screen shows what it has and says it is incomplete with a "load
  more" action. Show the API's `coverage` and `partial` as a notice when the period is not fully covered.
- **Rationale**: 90 days hourly is 2,160 timestamps and 90 days of 5-minute data is 25,920 (001 R13), so
  one or six pages cover the presets; the cap protects the browser on custom ranges.

## R9. Time zones and DST (FR-018)
- **Decision**: the API returns UTC; the interface formats with the browser's time zone through Intl,
  showing the zone name. The custom range picker converts the user's local times to UTC before calling.
  Points are ordered by their UTC time, so a DST change never reorders or duplicates them.

## R10. Visual design
- **Decision**: a token-based design (colour, spacing, radius, type scale) with light and dark themes,
  one accent colour plus status colours checked for 4.5:1 text contrast and 3:1 non-text contrast in both
  themes, Inter as the bundled typeface, and status shown as icon + label + colour. Before any screen is
  built, a static mock-up of the Overview (light and dark, desktop and phone) is reviewed by the owner
  (task in Phase 1 of tasks). Motion respects "reduce motion".
- **Rationale**: the spec asks for an attractive, modern look but leaves the exact design to the plan
  with an owner review (spec Assumptions).
- **Approved** by the owner on 2026-10-09: the Overview mock-up `web/mockup/overview.html` (attention band
  of non-ok cards first, healthy metrics grouped by area with sparklines and a license meter, live
  indicator with pause, out-of-date banner, light/dark/system). Screens follow it.

## R11. Performance budget (SC-002)
- **Decision**: the first screen's JavaScript stays under 200 KB gzipped; ECharts loads only with the
  history screen (code splitting). Measured in CI from the build output.
- **Rationale**: SC-002 asks for the Overview in 2 s; the API answers in milliseconds (001 R13), so the
  bundle is the main cost.

## R12. How the built interface is shipped
- **Decision**: the source lives in `web/`; the build writes to `src/web/historymonitor/`, which is
  committed and installed by IPM as the static application's files. A CI job rebuilds and fails if the
  committed files differ from a fresh build (the same pattern as `openapi.json` in spec 001).
- **Rationale**: users install with IPM and do not run Node; IPM copies a source folder into the CSP
  directory. Committing the build keeps `zpm install` working with no build step.
- **Alternatives**: building during IPM install (needs Node on every server); a separate release artefact
  (the IPM package would no longer be self-contained).

## R13. Testing
- **Decision**:
  - Unit and component tests (Vitest, Testing Library) with API responses mocked by fixtures that are
    themselves checked against `specs/001-api-v1/contracts/openapi.json`, so a mock cannot drift from the
    contract; axe checks on every rendered screen.
  - A translation test fails when a key is missing in any of the three catalogues (SC-005).
  - End-to-end tests (Playwright) in CI against an IRIS container with the module installed by IPM and
    demo history (`SYS.History.SysData.Demo`), signed in as a monitor viewer: every story's acceptance
    scenarios, axe in both themes, keyboard-only paths, phone width, and a network log check that every
    request goes to `/historymonitor/` (SC-006).
  - The ObjectScript side (settings route, new addresses) keeps the `%UnitTest` and HTTP tests of spec 001.
- **Rationale**: Principle II; the HTTP and IPM checks of spec 001 already proved the value of testing
  through the real server.
- **Not automatable**: SC-001 and SC-008 need a moderated test with operators; the plan records them as
  owner-run checks.

## R14. Old pages after delivery (FR-024)
- **Decision**: when the three screens are done, the Management Portal favourite added at install points
  to `/historymonitor/` instead of the old dashboard, each old page shows a banner "This page is obsolete;
  use the new monitor" with a link, and the old pages stay installed and reachable by address.
- **Rationale**: owner's answer to FR-024.

## R15. Delivery results and findings (tasks T053 to T061)
- **Sign-in (US4)**: the end-to-end tests passed on first run, because the mechanics landed in the
  foundation (T014, T019, T022): one sign-in covers the three screens and two tabs; after the IRIS session
  is ended (`IRISLogout=end`), the next refresh leads to the IRIS login and back to the same route
  (`#/processes?namespace=%25SYS`); an account without the role sees no-access naming
  `HistoryMonitorViewer`. No gap to fix (T054).
- **Languages, keyboard, focus (US5)**: pt-BR and es on every screen with local numbers and the choice
  kept across a reload; the main task of each screen done by keyboard with a visible focus outline; the
  skip link moves focus to the content. axe runs on every screen in light, dark and 360 px in the other
  specs. The only issue found during the screens was the table scroll region at 360 px (fixed in T044).
- **Management Portal favourite (T058)**: version 1.x stored the favourite as an object of
  `util.Favorite`, a class that does not exist in `%SYS`, so the Management Portal could not open, change
  or delete it (SQLCODE -415 on delete). `%AddFavorite` now writes plain `%SYS.Portal.Users` rows and
  replaces the 1.x rows, pointing to `/historymonitor/index.html`; `FavoriteTest` covers creation, the
  upgrade of a 1.x row and idempotence.
- **Old pages (T059)**: each shows an "obsolete" banner linking to the new monitor. Found: IRIS compiles a
  `.csp` page on its first request, and that fails with 404 for a user without development rights, so a
  viewer could not open an old page until an administrator had. The install now compiles them
  (`%SYSTEM.CSP.LoadPageDir`), and the install check asserts it.
- **CI holes closed**: a class that does not compile never ran, and the unit-test job only checked the
  totals; it now fails on any `ERROR` line of the load. (Found when a new test did not compile.)
- **IRIS Community licences**: every fresh sign-in holds a licence unit for a while. The e2e suite signs
  the viewer in once (R13 note in global-setup), and the tests that need their own sign-in run in one
  project and end their session afterwards. A long local session still exhausted the licences once;
  restarting the container frees them.
- **Quickstart (T061)**: the CI e2e job is the quickstart on a fresh container installed by IPM 0.10.9
  with 90 days of demo history, and it passes; locally the same suite (67 tests) passes against a
  container installed the same way. Measured in the browser: the complete Overview in about 0.6 s, a
  90-day hourly history view in about 0.7 s (SC-002: 2 s and 3 s). First screen 143.7 KB gzipped; the
  chart (190 KB) loads only with History.
- **Security headers (analysis finding S1)**: IRIS static web applications cannot set response headers
  such as `Content-Security-Policy` per application; that is web-server configuration. Not set here.
  React escapes output and the interface loads nothing from other hosts, which keeps the risk low.
- **Not done here**: SC-001 and SC-008 need operators (`usability-test.md`, for the owner to run).
