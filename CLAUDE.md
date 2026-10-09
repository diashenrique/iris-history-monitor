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
- Open specs: `specs/001-api-v1` (Phase 2): foundation T001-T010 done (Problem, Validate, Dispatch, Security, contract helper, `ipm-install` CI); US1 `GET /overview` (T011-T013) and US2 `GET /history/{metric}` (T014-T017) done; next is US3 processes (T018).
  History rows are keyed in UTC (`ZDATE`/`ZTIME`); never format a UTC value with `$ZDateTime(..., 7)`.

## Phase backlog
- [x] Phase 0: tests + CI
- [x] Phase 1: remove `Xecute`, parameterize SQL, SSRF guard on `readMetrics`
- [ ] Phase 2: versioned REST API (`%CSP.REST`, `/api/v1`), service layer, replace `^IRISMonitor` scratch globals
- [ ] Phase 3+: see the phased plan doc
