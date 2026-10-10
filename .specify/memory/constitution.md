# IRIS History Monitor Constitution

## Core Principles

### I. Secure by Default
Request data is never executed, concatenated into SQL, or trusted as a network target.
- `Xecute` / `$Xecute` with request data is forbidden. Web requests are handled by `%CSP.REST`
  classes with explicit URL maps; a request never selects which code runs.
- SQL uses parameters (`?` plus `%Execute(args)`). Never build SQL from request values.
- A server-side HTTP call never goes to a host taken from a request; outbound calls use fixed,
  configured addresses.
- Anything that reads `%SYS` does so through the service layer, never from a page class.

### II. Tests Gate Every Merge (NON-NEGOTIABLE)
A change is not done until a `%UnitTest` case covers its acceptance criteria and CI is green.
- Tests live in `src/cls/diashenrique/historymonitor/test` and are not shipped in `module.xml`.
- Security rules in Principle I have regression tests; a fix without one is incomplete.
- Code that was written but not executed is reported as unverified. It is never described as tested.

### III. Contract First, Versioned
The UI talks to one versioned REST API. The contract is written before the implementation.
- `/api/v1` is described by an OpenAPI document that lives in the repository.
- Errors use `application/problem+json`. A breaking change needs a new version path.
- Each route has a contract test that fails when the response shape drifts.

### IV. One Source per Fact, No Shared Scratch State
- No request handler writes per-request results into shared globals such as `^IRISMonitor(...)`.
  Concurrent users must not be able to overwrite or `Kill` each other's data.
- Specs state what and why; plans state how; tasks state the steps. A story links to the spec
  instead of restating it.
- `CLAUDE.md` holds code rules only. Product intent lives in `specs/`.

### V. Small, Reversible Increments
Ship in phases that each deliver value alone: security, then API, then history model, then UI.
- Prefer a flag over a long-lived branch for large work (the new UI shipped Overview first behind one).
- Do not add a dependency, framework or abstraction a spec does not require.

## Technical Constraints

- Platform: InterSystems IRIS, ObjectScript, packaged and released with IPM (`module.xml`, SemVer).
  The version bumps with behavior changes.
- New UI (when its spec is approved): React, TypeScript and Vite, served as static files from the
  IRIS web application. Targets WCAG 2.2 AA and supports en, pt-BR and es.
- Data sources stay the System Monitor history tables, `SYS.Stats.Dashboard.Sample()`,
  `%SYS.ProcessQuery` and the SAM sensors. Any change in source needs a spec.
- The repository is public and open source. Code, comments and specs are written in English.

## Development Workflow

1. Every non-trivial change starts as a spec in `specs/NNN-name/` (`/speckit-specify`),
   is clarified, planned and broken into tasks before any code is written.
2. Work happens on a branch and lands through a pull request; the owner approves the merge.
3. A pull request states what was verified and what was not, including anything not executed.
4. Review checks the diff against Principles I to V; a violation is justified in the plan's
   Complexity Tracking table or the change is revised.

## Governance

This constitution overrides other practices when they conflict. An amendment is a pull request
that changes this file, explains the reason, and updates `CLAUDE.md` if a code rule changes.
Versions follow SemVer: MAJOR removes or redefines a principle, MINOR adds one or widens a
rule, PATCH clarifies wording.

**Version**: 1.1.0 | **Ratified**: 2026-10-07 | **Last Amended**: 2026-10-09
