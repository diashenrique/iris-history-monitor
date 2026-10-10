# Research: Retire the old pages

## R1. How old addresses reach the new monitor
- **Decision**: `/csp/irismonitor` stays a web application, now with a dispatch class
  `web.Forward` (a `%CSP.REST` subclass). Every request under the prefix, whatever the method or path,
  gets `302 Found` with `Location` set to a fixed same-origin address of the new monitor from the map in
  `contracts/forwarding.md`. The path is the only input; it is matched against the fixed table of six page
  names, and anything else maps to the Overview.
- **Rationale**: IRIS answers a removed page with a bare 404, and a web application cannot redirect
  without code. A dispatch class sees every path under its prefix, including old static files and
  `*.cls` page URLs, so one class covers FR-002. A 302 (not 301) keeps browsers from caching the answer
  for ever, so a later release can change the target.
- **Alternatives**: a web-server rewrite rule (not every install has one in front of IRIS); empty
  `.csp` stubs that redirect (six files plus a compile step, and they do not cover other paths); 301
  (cached permanently by browsers).

## R2. Sign-in on the forwarding application
- **Decision**: the forwarding application allows unauthenticated access (`AutheEnabled=64`) and grants
  no role (`MatchRoles` empty). It reads no data, so it needs no user. The new monitor then asks for
  sign-in itself, and its return-to-route logic (spec 002 R5) brings the person to the matching screen.
- **Rationale**: if the forwarding application required a password, a person who is not signed in would
  sign in twice: once for the old cookie path and once for `/historymonitor/`. Unauthenticated access to
  a class that only redirects exposes nothing. The class is in the module's namespace. With no role
  granted, the test must prove that UnknownUser can run it (see T-task "forward as UnknownUser"). If it
  cannot, the fallback is `MatchRoles=":%DB_${Namespace}"`, which is scoped to this application, and the
  change is recorded here.
- **Result (T007, measured on IRIS 2026.1)**: with no role, the unauthenticated user got `403` before the
  class ran, because it may not run code from the module's database. With `MatchRoles=":%DB_${Namespace}"`
  the same request gets the `302`. The fallback is used. The role applies only to requests of this
  application, whose dispatch class answers every request with a fixed redirect (OnPreDispatch,
  `pContinue = 0`; `DispatchRequest` is final in `%CSP.REST`), so no other code runs with it.
- **Alternatives**: keep password authentication (double sign-in); forward without a session at all
  through the web server (R1 alternative); a dedicated role with Read only on the database (one more role
  to create and remove, for a class that already runs nothing else).

## R3. Removing what 1.x left on an upgrade
- **Decision**: a new class `util.Retire` with one idempotent method `Run()`, called by `<Invoke>` after
  Activate on every install and upgrade. It deletes:
  - the classes `diashenrique.historymonitor.dashboard.*`, `util.metrics`, `util.Dispatcher` and
    `util.Settings`, if they exist;
  - the six compiled page classes `csp.dashboard`, `csp.dashboardapi`, `csp.historycspsessions`,
    `csp.historydatabase`, `csp.historylicense` and `csp.systemprocesses`, if they exist (no other class
    of the `csp` package is touched);
  - the folder `${cspdir}irismonitor/`, if it exists;
  - `^IRISMonitor`;
  - `^diashenrique.historymonitor.Settings`.

  It runs in the module's namespace only and logs each removal.
- **Rationale**: IPM 0.10.9 is not documented to delete the classes of resources a new version drops,
  and the compiled page classes, page files and globals are not IPM resources at all. Doing the cleanup
  explicitly works on every upgrade path (1.2.4 → 2.0.0 as well as 1.9.x → 2.0.0). Explicit names keep it
  from touching anything the module did not create (FR-005).
- **Alternatives**: rely on IPM to drop removed resources (not guaranteed, and it does not cover the
  rest); a manual upgrade note (people skip it).

## R4. Uninstall
- **Decision**: the same `Retire.Run()` is also invoked before Unconfigure, so an uninstall removes the
  1.x leftovers as well. IPM removes the module's own resources and web applications. A task verifies on
  IPM 0.10.9 that the invoke runs on `uninstall`; if it does not, the README documents
  `do ##class(diashenrique.historymonitor.util.Retire).Run()` before uninstalling, and the decision is
  updated here.
- **Rationale**: US2 scenario 5.

## R5. API v1 and the removed switch
- **Decision**: `GET /settings` stays in API v1 and answers `{"interfaceEnabled": true}` always. The
  contract marks the field deprecated, with a note that 2.0.0 removed the switch. The interface stops
  reading it. `util.Settings` is deleted.
- **Rationale**: constitution III. Removing a route or a field is a breaking API change and needs a new
  version path. A constant value keeps every v1 client working.
- **Alternatives**: remove the route (breaking, needs `/api/v2`); keep the switch (rejected by the owner).

## R6. Constitution amendment (Principle I)
- **Decision**: amend Principle I to 1.1.0:
  - "Requests route through `util.Dispatcher.Run`" becomes "Web requests are handled by `%CSP.REST`
    classes with explicit URL maps; a request never selects which code runs."
  - "must pass `metrics.IsAllowedTarget`" becomes "A server-side HTTP call never goes to a host taken
    from a request; outbound calls use fixed, configured addresses."

  `CLAUDE.md` code rules change to match.
- **Rationale**: both classes are deleted in this release. The intent of the rules stays, and the
  amended rules are stricter: no request-derived host at all, instead of an allow list. The only
  outbound call left is `customSensors`, which goes to `localhost` and the configured web port.
- **Alternatives**: keep the two classes unused (dead code; violates Principle V).

## R7. The container image and namespace
- **Decision**: the image keeps creating the `IRISMONITOR` namespace and installing the module there
  (FR-006). It no longer calls the switch. The comments drop "where the old pages keep their scratch data".
- **Rationale**: a dedicated namespace keeps the module apart from `USER`; nothing in 2.0.0 needs it to
  go away.

## R8. Delivery results (T019)
- **ObjectScript suite** on IRIS 2026.1 with IPM 0.10.9: 133 methods, 0 failed. Removed `SecurityTest`
  (5 methods, tested only the deleted classes) and the switch methods of `SettingsTest`; added
  `RetireTest` (4) and `ForwardTest` (4, including hostile paths and GET/HEAD/POST over HTTP without
  credentials).
- **Upgrade 1.9.3 → 2.0.0** on a container that had used the old pages: `Retire` removed 17 items (5
  `dashboard` classes, `util.metrics`, `util.Dispatcher`, `util.Settings`, 6 compiled pages, the page
  folder, `^IRISMonitor`, the switch value). `InstallCheck` printed `INSTALL_CHECK=OK`, and the old
  addresses answer 302 to the contract targets. The new CI job `ipm-upgrade` repeats this on every PR.
- **Uninstall**: the `Unconfigure`/`Before` invoke runs on IPM 0.10.9 (R4 confirmed). No module class, web
  application or interface file is left.
- **Interface**: `npm test` 148 passed. Lint has the one existing warning (TanStack Table and the React
  Compiler). Build matches, first screen 131.6 KB gzipped. E2E 69 passed and 24 skipped by design. That
  includes the new forwarding tests (six old addresses, a signed-out sign-in that lands on History/license,
  and no link to old pages on any screen) and the CSP test.
- **Docker image**: builds without the switch call; `/settings` answers `{"interfaceEnabled":true}`, and
  `/csp/irismonitor/historylicense.csp` answers 302 to History on license.
- **Found while building**: `DispatchRequest` is final in `%CSP.REST` on 2026.1, so the forwarding uses
  `OnPreDispatch`. The unauthenticated user needed the database role to run the class (R2 result).
