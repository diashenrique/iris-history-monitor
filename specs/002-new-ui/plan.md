# Implementation Plan: New Monitor Interface

**Branch**: `002-new-ui` | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-new-ui/spec.md`

## Summary

Build a new single-page interface (Overview, History, Processes) that reads only the monitor API v1,
served as static files by an IRIS web application under one address prefix shared with the API so that
one sign-in covers both. The Overview ships first behind an instance-wide switch that an administrator
turns on; History and Processes follow; the old pages are then marked obsolete and leave the menu.
The API gains one read-only route for the switch and moves under the shared prefix (research R3, R4).

## Technical Context

**Language/Version**: TypeScript (current stable) with React, built by Vite on Node 24 LTS (build only).
ObjectScript for the small server changes (settings class and route, web application addresses).

**Primary Dependencies**: React, React Router (hash routes), TanStack Query, TanStack Table, Apache
ECharts (history screen only), Radix UI primitives, Tailwind CSS, i18next. Each is tied to a requirement
in research R2. Versions are pinned by the lockfile.

**Storage**: none in the browser except preferences (language, appearance); one server setting
(`interfaceEnabled`) in a namespace global written only by an administrator.

**Testing**: Vitest + Testing Library + axe for components, with API fixtures checked against the
OpenAPI contract; a translation completeness test; Playwright end-to-end with axe against an IRIS
container installed by IPM; the existing `%UnitTest` and HTTP suites for the server side (research R13).

**Target Platform**: current Chrome, Edge, Firefox and Safari; 360 px phones to wide desktops; served by
an IRIS web application (Community and licensed, Linux containers in CI).

**Project Type**: web application: a static front end plus the existing IRIS REST service.

**Performance Goals**: Overview complete within 2 s, a 90-day history view within 3 s (SC-002); first
screen JavaScript under 200 KB gzipped (research R11).

**Constraints**: data only from the API (FR-001, SC-006: no CDN, fonts bundled); WCAG 2.2 AA (FR-019);
en, pt-BR, es (FR-017); no build step on the server (research R12); anonymous access stays disabled.

**Scale/Scope**: 3 screens plus shell screens (not enabled, no access, error); one instance per
deployment; up to 25,920 points per series per page set and thousands of processes (paged by the API).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How the plan satisfies it |
| --- | --- | --- |
| I. Secure by default | Pass | No request data is executed or put in SQL; the new `/settings` route takes no input; the switch can only be changed with `%Admin_Manage`; no outbound call; the session is scoped to `/historymonitor/` (owner's FR-025 answer); nothing loads from third-party hosts |
| II. Tests gate every merge | Pass | Tests first per story: component and contract-fixture tests, translation completeness, end-to-end with axe in CI against IPM-installed IRIS; server changes keep the `%UnitTest`/HTTP suites; SC-001 and SC-008 are recorded as owner-run checks, not claimed as automated |
| III. Contract first, versioned | Pass | `contracts/api-v1-changes.md` is applied to the OpenAPI document before code; both changes are additive so the path stays `v1`; UI routes are a written contract (`contracts/ui-routes.md`) |
| IV. One source per fact, no shared scratch | Pass | The interface reads only the API; the Overview trend lives in browser memory; the only stored value is an administrator-set configuration flag, not per-request scratch |
| V. Small, reversible increments | Pass | Switch off by default; Overview first, then History, then Processes, each shippable alone; the old pages stay reachable (FR-024) |
| Technical constraints (React, TypeScript, Vite, static files, WCAG 2.2 AA, en/pt-BR/es) | Pass | Adopted as is |

Re-checked after Phase 1 design (research, data model, contracts, quickstart): no violations, so the
Complexity Tracking table stays empty. One trade-off is recorded rather than justified as a violation:
the built files are committed (research R12), guarded by a CI drift check.

## Project Structure

### Documentation (this feature)

```text
specs/002-new-ui/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── api-v1-changes.md   # applied to specs/001-api-v1/contracts/openapi.yaml
│   └── ui-routes.md
├── checklists/requirements.md
└── tasks.md                # /speckit-tasks
```

### Source Code (repository root)

```text
web/                                   # interface source (not installed)
├── package.json, package-lock.json, vite.config.ts, tsconfig.json
├── index.html
├── src/
│   ├── main.tsx, App.tsx              # shell: settings check, routes, providers
│   ├── api/                           # typed client for /historymonitor/api/v1, 401/403 handling
│   ├── features/
│   │   ├── overview/                  # US1: metric cards, status ordering, sparkline, stale state
│   │   ├── history/                   # US2: query form, ECharts chart (lazy), table, coverage notice
│   │   └── processes/                 # US3: filters, server-side table, detail panel
│   ├── shell/                         # layout, navigation, not-enabled, no-access, error screens
│   ├── design/                        # tokens, light/dark themes, Radix-based components
│   ├── i18n/                          # en.json, pt-BR.json, es.json, formatting helpers
│   └── lib/                           # address state, CSV export, time formatting
├── tests/
│   ├── unit/                          # Vitest + Testing Library + axe
│   ├── fixtures/                      # API responses, validated against openapi.json
│   └── e2e/                           # Playwright against IRIS
└── scripts/check-build.mjs            # CI: committed build equals a fresh build

src/web/historymonitor/                # built files, committed, installed by IPM (research R12)

src/cls/diashenrique/historymonitor/
├── api/Dispatch.cls                   # + GET /settings
├── util/Settings.cls                  # new: interfaceEnabled, admin-only setter
└── test/api/SettingsTest.cls          # new; HttpAuthTest and ContractCoverageTest updated

module.xml                             # web applications under /historymonitor/, cookie path, favourite
.github/workflows/ci.yml               # + web job (lint, types, unit, translations, build drift, size)
                                       # + e2e job (IRIS + IPM + demo data + Playwright)
```

**Structure Decision**: a separate `web/` source tree for the interface and a committed build folder
under `src/` that IPM installs; the server changes stay in the existing ObjectScript packages. The old
pages under `src/csp/` are untouched until the final story (banner and favourite only).

## Complexity Tracking

No violations to justify.
