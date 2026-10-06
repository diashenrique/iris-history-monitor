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

## Phase backlog
- [x] Phase 0: tests + CI
- [x] Phase 1: remove `Xecute`, parameterize SQL, SSRF guard on `readMetrics`
- [ ] Phase 2: versioned REST API (`%CSP.REST`, `/api/v1`), service layer, replace `^IRISMonitor` scratch globals
- [ ] Phase 3+: see the phased plan doc
