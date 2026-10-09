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
- Open specs: `specs/002-new-ui` (Phase 4, new interface): plan done; React + TypeScript + Vite source in `web/`,
  build committed to `src/web/historymonitor/`, everything under `/historymonitor/` (API at `/historymonitor/api/v1`).
- `specs/001-api-v1` (Phase 2) is complete: `GET /overview`, `/history/{metric}`, `/processes`
  under `/api/historymonitor/v1`. User story 5 (old pages read the API) was withdrawn: the old pages will not be used.
  History rows are keyed in UTC (`ZDATE`/`ZTIME`); never format a UTC value with `$ZDateTime(..., 7)`.
  The role is checked in `Dispatch.OnPreDispatch` (403); the web application has no resource on purpose (research.md R11).

## Phase backlog
- [x] Phase 0: tests + CI
- [x] Phase 1: remove `Xecute`, parameterize SQL, SSRF guard on `readMetrics`
- [x] Phase 2: versioned REST API (`%CSP.REST`, `/api/historymonitor/v1`), service layer; the new code writes no scratch
  globals (the old pages still use `^IRISMonitor` until they are retired)
- [ ] Phase 3+: see the phased plan doc. Phase 4 (new interface) is the first API client; research.md R12 covers sharing
  its login with the API
