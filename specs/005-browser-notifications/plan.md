# Implementation Plan: Browser notifications

**Branch**: `005-browser-notifications` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-browser-notifications/spec.md`

## Summary

Interface-only. A watcher mounted in the shell reads `GET /overview` (the same query the Overview uses) while
notifications are on, also with the tab hidden, every 30 s; the browser slows hidden tabs to about once a
minute. A pure function compares each reading with the last known states and returns the worse transitions
(OK→warning, OK→critical, warning→critical); the first reading and anything involving unavailable only set
the baseline. Transitions of one check become one browser notification, unless the Overview is the visible
screen (the change is already on screen and announced). A header button opens a dialog to turn
notifications on, explains when they cannot work, and shows when they are paused. After 8 hours without
interaction, checks stop and one notification says so; any interaction resumes them. No server change.

## Technical Context

**Language/Version**: TypeScript 5, React 19 (the existing `web/` interface).

**Primary Dependencies**: existing TanStack Query, i18next; the browser Notification API. No new package.

**Storage**: browser `localStorage` only: the on/off preference (`hm.notifications`) and the last notified
transition per metric for the de-duplication between tabs (`hm.notified.<metric>`). Every access is in
try/catch, like the existing language and theme preferences.

**Testing**: Vitest (pure transitions, availability, de-duplication, idle stop, the control, axe), with a fake
`Notification`; Playwright e2e with the notifications permission granted, a recording stub of
`Notification`, and the `/overview` response changed by route interception to force a transition.

**Target Platform**: evergreen browsers; notifications only in a secure context (HTTPS or `localhost`).

**Project Type**: static web interface served by IRIS.

**Performance Goals**: one extra `/overview` request every 30 s only while notifications are on and the
Overview is not already polling; first-screen JavaScript stays under the 200 KB budget.

**Constraints**: no server or API change (FR-011); WCAG 2.2 AA and three languages (FR-012); the
permission prompt only on the user's click (FR-002).

**Scale/Scope**: about 6 small modules, 1 header control, strings in 3 languages, README section.

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Secure by Default | No server change, no new request type; notification text is built from metric names and states the interface already renders (no HTML). | Pass |
| II. Tests Gate Every Merge | Unit tests for every rule in FR-003, FR-005, FR-006, FR-008; e2e for the end-to-end path. | Pass |
| III. Contract First | Uses `GET /overview` as defined; contract unchanged. | Pass |
| IV. No Shared Scratch State | Browser-local preference only; nothing written on the server. | Pass |
| V. Small, Reversible Increments | Opt-in, off by default; no dependency added; no push service. | Pass |

Post-design re-check: unchanged, all pass.

## Project Structure

```text
specs/005-browser-notifications/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
└── contracts/ui-notifications.md     # the control's states and the notification texts
web/src/features/notifications/
├── transitions.ts        # pure: worse transitions between two readings
├── availability.ts       # secure context, support, permission -> one state
├── preference.ts         # on/off in localStorage
├── dedupe.ts             # one notification per transition across tabs
├── useNotificationWatcher.ts   # polling while on, idle stop, showing notifications
└── NotificationsControl.tsx    # header button + dialog
web/src/shell/Header.tsx, web/src/App.tsx (mount the watcher in Layout)
web/src/i18n/{en,pt-BR,es}.json
web/tests/unit/notifications-*.test.ts(x), web/tests/e2e/notifications.spec.ts
README.md, CHANGELOG.md (2.2.0), module.xml (2.2.0), CLAUDE.md
```

**Structure Decision**: a new feature folder beside `overview/`, `history/` and `processes/`. The watcher is
mounted in the shell, not in the Overview, because it must run on every screen.

## Complexity Tracking

No violations.
