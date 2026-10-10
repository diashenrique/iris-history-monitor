# IRIS History Monitor

ObjectScript + CSP monitor for InterSystems IRIS, packaged with IPM (`module.xml`).
Code lives in `src/cls/diashenrique/historymonitor/{api,service,util,web}`; the interface source in `web/`,
its build in `src/web/historymonitor/`. The old CSP pages were removed in 2.0.0 (spec 003).

## Rules
- Never use `Xecute` or `$Xecute` with request data. Web requests go through `%CSP.REST` classes with
  explicit URL maps (`api.Dispatch`, `web.Forward`); a request never selects which code runs.
- SQL takes parameters (`?` + `%Execute(args)`). Never concatenate request values into SQL.
- No server-side HTTP call to a host taken from a request; outbound calls use fixed, configured addresses.
- Tests live in `src/cls/diashenrique/historymonitor/test` (not shipped in `module.xml`).
  Run: `do ##class(%UnitTest.Manager).RunTest("diashenrique/historymonitor/test","/nodelete")`.
- Keep the IPM version in `module.xml` in step with behavior changes (SemVer).
- `module.xml` changes are checked by the `ipm-install` CI job. `<WebApplication>` needs an explicit
  `AutheEnabled`; `PasswordAuthEnabled`/`UnauthenticatedEnabled` belong to `<CSPApplication>` only.

## Spec-driven workflow (Spec Kit)
- Principles live in `.specify/memory/constitution.md`; it overrides this file if they conflict.
- A change starts as `specs/NNN-name/spec.md` (`/speckit-specify`), then `/speckit-clarify`, `/speckit-plan`,
  `/speckit-tasks`, `/speckit-analyze` and only then `/speckit-implement`.
- Open specs: none awaiting code. `specs/003-retire-old-pages` (2.0.0) is implemented: the old pages, their classes,
  `^IRISMonitor` and the monitor switch are gone; `/csp/irismonitor/*` forwards (302) through `web.Forward`;
  `util.Retire` cleans up 1.x leftovers on install, upgrade and uninstall; CI `ipm-upgrade` checks 1.9.3 -> this.
- `specs/002-new-ui` (Phase 4, new interface) is implemented: Overview, History,
  Processes at `/historymonitor/index.html`, API at `/historymonitor/api/v1`. Since 2.0.0 it is always on.
  Interface source in `web/` (React + TypeScript + Vite; `npm test`, `npm run build`, `npx playwright test` with
  `.github/ci/e2e-setup.sh`); the build is committed to `src/web/historymonitor/` and CI checks it matches.
  Owner still to run: `specs/002-new-ui/usability-test.md` (SC-001; SC-008 withdrawn in 2.0.0).
- `specs/001-api-v1` (Phase 2) is complete: `GET /overview`, `/history/{metric}`, `/processes`
  (now under `/historymonitor/api/v1`, spec 002). User story 5 (old pages read the API) was withdrawn; the old pages were removed in 2.0.0.
  History rows are keyed in UTC (`ZDATE`/`ZTIME`); never format a UTC value with `$ZDateTime(..., 7)`.
  The role is checked in `Dispatch.OnPreDispatch` (403); the web application has no resource on purpose (research.md R11).

## Phase backlog
- [x] Phase 0: tests + CI
- [x] Phase 1: remove `Xecute`, parameterize SQL, SSRF guard on `readMetrics`
- [x] Phase 2: versioned REST API (`%CSP.REST`, now at `/historymonitor/api/v1`), service layer; no code writes scratch
  globals (`^IRISMonitor` removed with the old pages in 2.0.0)
- [ ] Phase 3+: see the phased plan doc. Phase 4 (new interface, spec 002) is implemented, and the old pages are removed
  (spec 003, 2.0.0)
