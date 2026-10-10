# Implementation Plan: Retire the old pages

**Branch**: `003-retire-old-pages` | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-retire-old-pages/spec.md`

## Summary

Release 2.0.0 removes the old CSP pages and everything only they use, and removes the monitor switch
(clarification, option A). The old prefix `/csp/irismonitor` stays as a web application whose only job is
to forward (HTTP 302) to the matching screen of the new monitor (research R1, R2). An idempotent cleanup
class runs on install, upgrade and uninstall. It removes what 1.x left: the six compiled page classes, the
page files, the `^IRISMonitor` scratch data and the switch value (R3, R4). It never touches a namespace
or database (FR-006). API v1 keeps `GET /settings` for compatibility, with `interfaceEnabled` always true
(R5). The interface drops its "not turned on" state. Principle I of the constitution names two classes
this release deletes, so it is amended (R6).

## Technical Context

**Language/Version**: ObjectScript on InterSystems IRIS 2026.1; TypeScript 5 / React 19 for the interface.

**Primary Dependencies**: IPM 0.10.9 (`module.xml`), `%CSP.REST` (forwarding class); no new dependency.

**Storage**: none new. Removed: `^IRISMonitor` (old scratch data) and
`^diashenrique.historymonitor.Settings` (switch).

**Testing**: `%UnitTest` (forwarding map, cleanup, settings, over HTTP); Vitest (interface without the
switch); Playwright e2e (old addresses land on the right screen; no link to old pages); CI `ipm-install`
(`InstallCheck`: fresh install and upgrade from 1.9.x) and `docker`.

**Target Platform**: IRIS web server or Web Gateway; any evergreen browser.

**Project Type**: IPM module: REST API, static web interface, and one forwarding web application.

**Performance Goals**: forwarding answers without reading any data (one map lookup, no session needed).

**Constraints**: delete only what the module created (FR-005); keep namespaces and databases (FR-006);
API v1 stays backward compatible (constitution III).

**Scale/Scope**: removes about 5,700 lines of ObjectScript and CSP (6 pages, 5 page classes, 2 util
classes, plus the switch class and 1 test class) and `src/csp/resources`: 1,400 files, 108 MB, including
the DevExtreme 18.2.3 grid library (SC-005).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Secure by Default | The forwarding class reads only the URL path, maps it through a fixed table and redirects to a fixed same-origin path. Nothing is executed, no SQL, no outbound call. The rules name `util.Dispatcher.Run` and `metrics.IsAllowedTarget`, which this release deletes. | Pass, with an amendment (R6) |
| II. Tests Gate Every Merge | Every FR has a test task; cleanup is tested on an instance seeded with 1.x leftovers. | Pass |
| III. Contract First, Versioned | API v1 unchanged except that `interfaceEnabled` is documented as always true and deprecated. Additive, not breaking (R5). The forwarding map is written as a contract first (`contracts/forwarding.md`). | Pass |
| IV. No Shared Scratch State | Removes the last writer of `^IRISMonitor`. | Pass (closes the Phase 2 item) |
| V. Small, Reversible Increments | One major release. The forwarding keeps old links working for all of 2.x. No new dependency. | Pass |

Post-design re-check: unchanged, all pass. The amendment to Principle I is a MINOR constitution change
(1.0.0 → 1.1.0). It drops two named mechanisms whose subjects no longer exist, and the principle stays.

## Project Structure

### Documentation (this feature)

```text
specs/003-retire-old-pages/
├── plan.md
├── research.md          # R1-R7
├── data-model.md        # what is removed, the forwarding map
├── quickstart.md        # upgrade-and-check run
├── contracts/
│   └── forwarding.md    # old address -> new address
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
module.xml                                   # 2.0.0; drop dashboard PKG, CSP FileCopy; forward app; cleanup invokes
src/cls/diashenrique/historymonitor/
├── dashboard/                               # DELETED (5 classes)
├── util/
│   ├── Dispatcher.cls                       # DELETED
│   ├── metrics.cls                          # DELETED
│   ├── Settings.cls                         # DELETED (switch removed)
│   ├── Retire.cls                           # NEW: idempotent cleanup of 1.x leftovers
│   ├── Security.cls, Favorite.cls, customSensors.cls   # unchanged
├── web/
│   ├── Login.cls                            # unchanged
│   └── Forward.cls                          # NEW: %CSP.REST, old address -> 302 to new screen
├── api/Dispatch.cls                         # /settings answers interfaceEnabled=true
└── test/
    ├── SecurityTest.cls                     # DELETED (tested Dispatcher and metrics only)
    └── api/{ForwardTest,RetireTest}.cls     # NEW; SettingsTest, HttpAuthTest, HttpSessionTest updated
src/csp/                                     # DELETED (pages and resources)
web/src/                                     # drop NotEnabledScreen and the settings gate
web/tests/e2e/                               # old-pages.spec -> forwarding; not-enabled.spec deleted
.github/ci/InstallCheck.cls, .github/workflows/ci.yml   # fresh install + upgrade checks
Installer.cls, Dockerfile, docker-compose.yml           # comments; switch call removed
README.md, CHANGELOG.md, CLAUDE.md, .specify/memory/constitution.md
```

**Structure Decision**: the existing IPM module layout. Two new classes go where their kind already
lives: the web entry point in `web/`, next to `Login.cls`, and the install helper in `util/`, next to
`Security.cls`.

## Complexity Tracking

No violations to justify. The constitution amendment (R6) is listed so review can check it.
