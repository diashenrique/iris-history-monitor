# IRIS History Monitor

ObjectScript + CSP monitor for InterSystems IRIS, packaged with IPM (`module.xml`).
Code lives in `src/cls/diashenrique/historymonitor/{dashboard,util}`; pages in `src/csp`.

## Rules
- Never use `Xecute` or `$Xecute` with request data. Route `%CSP.Page` requests through
  `util.Dispatcher.Run(class, method, "allowedA,allowedB")`.
- SQL takes parameters (`?` + `%Execute(args)`). Never concatenate request values into SQL.
- Any server-side HTTP call to a host derived from a request must pass `metrics.IsAllowedTarget`.
- Tests live in `src/cls/diashenrique/historymonitor/test` (not shipped in `module.xml`).
  Run: `do ##class(%UnitTest.Manager).RunTest("diashenrique/historymonitor/test","/nodelete")`.
- Keep the IPM version in `module.xml` in step with behavior changes (SemVer).
- `module.xml` changes are checked by the `ipm-install` CI job. `<WebApplication>` needs an explicit
  `AutheEnabled`; `PasswordAuthEnabled`/`UnauthenticatedEnabled` belong to `<CSPApplication>` only.

## Spec-driven workflow (Spec Kit)
- Principles live in `.specify/memory/constitution.md`; it overrides this file if they conflict.
- A change starts as `specs/NNN-name/spec.md` (`/speckit-specify`), then `/speckit-clarify`, `/speckit-plan`,
  `/speckit-tasks`, `/speckit-analyze` and only then `/speckit-implement`.
- Open specs: none awaiting code. `specs/002-new-ui` (Phase 4, new interface) is implemented: Overview, History,
  Processes at `/historymonitor/index.html`, API at `/historymonitor/api/v1`, behind `util.Settings.SetInterfaceEnabled`.
  Interface source in `web/` (React + TypeScript + Vite; `npm test`, `npm run build`, `npx playwright test` with
  `.github/ci/e2e-setup.sh`); the build is committed to `src/web/historymonitor/` and CI checks it matches.
  Owner still to run: `specs/002-new-ui/usability-test.md` (SC-001, SC-008).
- `specs/001-api-v1` (Phase 2) is complete: `GET /overview`, `/history/{metric}`, `/processes`
  (now under `/historymonitor/api/v1`, spec 002). User story 5 (old pages read the API) was withdrawn: the old pages will not be used.
  History rows are keyed in UTC (`ZDATE`/`ZTIME`); never format a UTC value with `$ZDateTime(..., 7)`.
  The role is checked in `Dispatch.OnPreDispatch` (403); the web application has no resource on purpose (research.md R11).

## Phase backlog
- [x] Phase 0: tests + CI
- [x] Phase 1: remove `Xecute`, parameterize SQL, SSRF guard on `readMetrics`
- [x] Phase 2: versioned REST API (`%CSP.REST`, now at `/historymonitor/api/v1`), service layer; the new code writes no scratch
  globals (the old pages still use `^IRISMonitor` until they are retired)
- [ ] Phase 3+: see the phased plan doc. Phase 4 (new interface, spec 002) is implemented; the old pages are obsolete
  (banner, out of the menu) and are removed in a later release
