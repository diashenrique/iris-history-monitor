---
description: "Tasks for spec 005, browser notifications"
---

# Tasks: Browser notifications

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/ui-notifications.md](contracts/ui-notifications.md), [quickstart.md](quickstart.md)

**Tests**: required (constitution II), written before the code they cover. `N` = `web/src/features/notifications`.

## Phase 1: Setup

- [ ] T001 Set `module.xml` `<Version>` to 2.2.0 (new feature, raised by hand) and open `## 2.2.0 (unreleased)` in `CHANGELOG.md`.

## Phase 2: Foundational (pure rules)

- [ ] T002 [P] Tests first in `web/tests/unit/notifications-rules.test.ts`:
  - `worseTransitions`: ok→warning, ok→critical, warning→critical notify; same state, better state, anything to or from unavailable, a first reading (no previous) and a new metric do not (research R3).
  - `availability`: returns insecure, unsupported, denied, default or granted, in that order of precedence (R7).
  - `shouldNotifyAgain`: drops a metric+state notified in the last 10 minutes, accepts after that or for a different state; works with no storage (R5).
  - `notificationBody`: one transition gives "{metric} is now {state}"; several give "{count} metrics got worse: …" (contract).
- [ ] T003 Implement `N/transitions.ts`, `N/availability.ts`, `N/preference.ts` (`hm.notifications`), `N/dedupe.ts` (`hm.notified.<metric>`) and the body builder. Every `localStorage` access is in try/catch. T002 must pass.

## Phase 3: User Story 1 - Be told when a metric gets worse (P1) MVP

- [ ] T004 [US1] Tests first in `web/tests/unit/notifications-watcher.test.tsx`, with a fake `Notification`, fake timers and the fake API. Cases:
  - on + granted, with the History screen open: an ok→warning change makes one notification;
  - the same state again makes none;
  - two metrics in one reading make one notification;
  - the first reading makes none;
  - on the visible Overview, none (R4);
  - hidden document on the Overview: one;
  - clicking the notification focuses the window and opens `#/`;
  - off, or not granted: no polling of `/overview` from the watcher.
- [ ] T005 [US1] Implement `N/useNotificationWatcher.ts`:
  - query `['overview']`, 30 s, in the background, enabled when the preference is on, the permission is granted and the watcher is not idle;
  - baseline map;
  - show rule (R4);
  - de-duplication;
  - `new Notification(title, { body, tag })` with `onclick`.

  Mount it in `Layout` (`web/src/App.tsx`). T004 must pass.
- [ ] T006 [US1] E2E `web/tests/e2e/notifications.spec.ts`, one project:
  - grant the `notifications` permission and stub `window.Notification` to record each call;
  - turn notifications on in the dialog and open History;
  - route `**/api/v1/overview` to change one metric's status after the first response;
  - expect one recorded notification naming it within 45 s;
  - then expect no second one for the same state.

## Phase 4: User Story 2 - Turn on and off, and know when they cannot work (P1)

- [ ] T007 [US2] Tests first in `web/tests/unit/notifications-control.test.tsx`:
  - the button's name includes the state;
  - the dialog text and action match each state of the contract (off, on, paused, denied, insecure, unsupported);
  - **Turn on** calls `Notification.requestPermission` only on click and sets the preference on "granted";
  - "denied" leaves it off and shows the blocked text;
  - **Turn off** clears the preference;
  - the choice survives a remount;
  - axe finds no serious issue;
  - pt-BR and es strings exist.
- [ ] T008 [US2] Implement `N/NotificationsControl.tsx`: the header button and the existing `Dialog` component. Add it to `web/src/shell/Header.tsx`, with strings `notifications.*` in `web/src/i18n/{en,pt-BR,es}.json`. T007 must pass.
- [ ] T009 [US2] Idle stop (FR-008, SC-006). Tests first, in the watcher test:
  - after 8 hours with no `keydown`, `pointerdown` or visibility change, the watcher stops fetching and shows one "paused" notification;
  - the control says paused;
  - one `pointerdown` resumes it.

  Then implement this in `useNotificationWatcher.ts`, exposing the paused state to the control (a small context or store in `N/`).

## Phase 5: User Story 3 - Know what this is and is not (P2)

- [ ] T010 [P] [US3] README section "Notifications". It covers:
  - how to turn them on;
  - the secure-address and open-tab limits;
  - the delay in hidden tabs, and the 8-hour pause with its reason (session and license unit);
  - unattended alerting: System Monitor e-mail alerts, and the SAM sensors with an alert manager.

## Phase 6: Polish

- [ ] T011 Run lint, `npm test`, build, `check-build`, `check-size` and the e2e suite, and record the numbers in research (R8). Rebuild `src/web/historymonitor/`.
- [ ] T012 Docs:
  - in `CHANGELOG.md`, fill 2.2.0;
  - in `CLAUDE.md`, the open specs line;
  - tick T001–T012.

  The PR closes #6.

## Dependencies

- T001; T002 → T003 → T004 → T005 → T006.
- T007 → T008 after T003. T009 after T005 and T008.
- T010 any time. T011 and T012 last.
