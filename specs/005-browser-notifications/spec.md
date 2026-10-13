# Feature Specification: Browser notifications

**Feature Branch**: `005-browser-notifications`

**Created**: 2026-10-13

**Status**: Draft

**Input**: User description: "Spec 005, browser notifications (issue #6): an operator who keeps the monitor open in a browser tab, even in the background, gets a desktop notification when a metric gets worse, so they notice a problem without watching the Overview. Opt-in per browser, from a control in the header; the browser asks for permission on that click. Notify on transitions to worse states only (from OK to warning or critical, from warning to critical), once per transition, never on every refresh; Unavailable never notifies (it shows on every start). The notification names the metric and its new state, in the user's language (en, pt-BR, es); clicking it brings the Overview to front. Limits stated plainly in the interface: it needs HTTPS or localhost (browsers expose notifications only in a secure context) and an open tab; with the browser closed nothing notifies. Monitoring must continue while the tab is hidden, which today stops (the Overview only refreshes while it is visible and open). Side effect to decide: a tab with notifications on keeps the IRIS session (and a license unit) alive. The server and API do not change. README explains that this is a convenience for someone with the monitor open, not unattended alerting (for that, IRIS System Monitor email alerts or the SAM sensors with an alert manager)."

## Context

Issue #6 (2020) asked for "a browser notification when an alert or error occurs". Today the Overview shows
each metric's state, but only while the Overview is the visible page: it stops refreshing when the tab is
hidden or another screen is open. Someone who keeps the monitor in a background tab learns about a problem
only when they look.

Browsers allow a page to show desktop notifications only on a secure address (HTTPS, or the local machine)
and only while the page is open. This feature is therefore a convenience for people who keep the monitor
open. It does not replace unattended alerting, which the instance itself provides (System Monitor e-mail
alerts, or the monitoring sensors read by an alert manager).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Be told when a metric gets worse (Priority: P1)

An operator turns notifications on once in their browser. Later, with the monitor in a background tab,
license use crosses the warning level. A desktop notification appears: "License use: Warning". They click
it, and the browser brings the monitor's Overview to the front.

**Why this priority**: this is what issue #6 asks for, and the reason for the feature.

**Independent Test**: turn notifications on, hide the tab, make a metric change state on the instance, and
watch for the notification.

**Acceptance Scenarios**:

1. **Given** notifications are on and the monitor tab is hidden, **When** a metric goes from OK to warning,
   **Then** one notification names the metric and its new state, in the interface language.
2. **Given** the same, **When** a metric goes from warning to critical, **Then** one notification names the
   metric and "Critical".
3. **Given** a metric that stays in warning, **When** the monitor checks again and again, **Then** no further
   notification appears for it.
4. **Given** a metric goes back to OK and later to warning again, **When** it does, **Then** a new
   notification appears (a new transition).
5. **Given** a metric becomes unavailable, or the monitor has just opened and reads every state for the first
   time, **When** that happens, **Then** no notification appears.
6. **Given** a notification is shown, **When** the user clicks it, **Then** the monitor's tab comes to the
   front, on the Overview.

---

### User Story 2 - Turn notifications on and off, and know when they cannot work (Priority: P1)

An operator finds the notifications control in the header. Turning it on asks the browser for permission.
If the browser refuses, or the monitor is served on a plain HTTP address, the control says why
notifications are not available instead of failing silently. The choice is remembered for that browser.

**Why this priority**: without a clear on/off and an honest "not available" state, US1 cannot be used or
trusted.

**Independent Test**: use the control on a secure address and on a plain HTTP address; allow and refuse
the browser permission; reload.

**Acceptance Scenarios**:

1. **Given** a secure address and permission not yet asked, **When** the user turns notifications on,
   **Then** the browser asks for permission, and on "allow" the control shows notifications as on.
2. **Given** the user refuses the permission, **When** the control is shown, **Then** it says notifications
   are blocked by the browser and how to allow them, and nothing is notified.
3. **Given** the monitor is on a plain HTTP address that is not the local machine, **When** the user opens
   the control, **Then** it says notifications need HTTPS (or the local machine) and cannot be turned on.
4. **Given** notifications were turned on, **When** the user reloads the page or opens the monitor again in
   the same browser, **Then** they are still on; another browser or person is not affected.
5. **Given** notifications are on, **When** the user turns them off, **Then** no further notification
   appears.

---

### User Story 3 - Know what this is and is not (Priority: P2)

An administrator reading the README learns that notifications need an open tab and a secure address, that
they are not unattended alerting, and where to set up unattended alerting instead.

**Why this priority**: avoids the wrong expectation that the monitor alerts when nobody has it open.

**Independent Test**: read the README section.

**Acceptance Scenarios**:

1. **Given** the README, **When** an administrator looks for notifications, **Then** a section explains the
   two limits (secure address, open tab), the effect on the session (FR-008), and points to System Monitor
   e-mail alerts and the monitoring sensors for unattended alerting.

### Edge Cases

- The tab is hidden for a long time: the browser checks less often, so a notification can arrive later
  than the change (up to about a minute). The interface says so.
- Several metrics get worse in the same check: one notification per metric would flood; they are grouped
  into one notification that names them (for example "3 metrics need attention: …").
- The monitor is open in two tabs of the same browser: each tab would notify. Only one notification per
  transition is shown in that browser.
- The session ends while notifications are on (sign-out elsewhere, server restart): checks start failing;
  the monitor stops notifying and, when the user returns, shows the usual sign-in, not a flood of old
  transitions.
- The instance does not answer for a while: no notification is made from missing data. When it answers
  again, transitions are judged against the last known states.
- The user changes the interface language: later notifications use the new language.
- The browser shows notifications only in some conditions (do-not-disturb, focus modes): that is the
  operating system's choice; nothing in the monitor works around it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The monitor MUST offer a control in the header to turn browser notifications on or off. The
  choice MUST be remembered per browser and MUST NOT affect other browsers or users.
- **FR-002**: Turning notifications on MUST ask the browser for permission at that moment (on the user's
  action), and never before.
- **FR-003**: When notifications cannot work, the control MUST say why and MUST NOT appear to be on:
  - the address is not secure (not HTTPS and not the local machine);
  - the browser's permission was refused;
  - the browser does not support notifications.
- **FR-004**: While notifications are on, the monitor MUST keep checking the metric states with the tab
  hidden and while another screen of the monitor is open, at least once a minute.
- **FR-005**: A notification MUST be shown only for a transition to a worse state among OK, warning and
  critical, as in [NEEDS CLARIFICATION: which transitions notify — every move to warning or critical (OK
  to warning, OK to critical, warning to critical), or only moves to critical?]. A metric that keeps its
  state MUST NOT notify again. Transitions to or from unavailable, and the first reading after the monitor
  opens, MUST NOT notify.
- **FR-006**: A notification MUST name the metric(s) and the new state in the interface language (English,
  Portuguese (Brazil), Spanish). Transitions found in the same check MUST be grouped into one
  notification. A browser with the monitor in several tabs MUST show one notification per transition.
- **FR-007**: Clicking a notification MUST bring the monitor's tab to the front on the Overview.
- **FR-008**: While notifications are on, the checks keep the user's session in use. Session behavior: [NEEDS
  CLARIFICATION: may a tab with notifications on keep the session (and a license unit) alive for as long as
  it stays open, or must the monitor stop checking after a period without user interaction (for example
  8 hours) and say so?]
- **FR-009**: The interface MUST state, next to the control, that notifications need the monitor to stay
  open in a tab and may arrive up to about a minute late when the tab is hidden.
- **FR-010**: The README MUST explain the feature, its limits (secure address, open tab, delay, session
  effect) and point to unattended alerting: System Monitor e-mail alerts and the monitoring sensors with an
  alert manager.
- **FR-011**: The server and the API MUST NOT change; the feature uses the existing overview data.
- **FR-012**: The control and any text MUST meet the same accessibility level and languages as the rest of
  the interface (spec 002).

### Key Entities

- **Notification preference**: on or off, per browser.
- **Last known states**: the state of each metric at the last successful check, kept in the open monitor to
  judge transitions. Not stored on the server.
- **Transition**: a metric, its previous state and its new state, found in one check.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With notifications on and the tab hidden, a change to a worse state produces a notification
  within 90 seconds in 100% of checks on a secure address.
- **SC-002**: Zero notifications for metrics that keep their state, for unavailable, and for the first
  reading after opening, over a 30-minute run with changing states.
- **SC-003**: On a non-secure address, or with the browser permission refused, 100% of attempts to turn
  notifications on end with the control explaining why, and no notification is ever shown.
- **SC-004**: Several metrics getting worse in the same check produce exactly one notification.
- **SC-005**: The server and API are unchanged: every existing API test passes with no change.

## Assumptions

- Browsers show page notifications only on a secure address and while the page is open; this is not worked
  around (no background push service, which would need a server component, HTTPS and a push provider).
- Background tabs are checked less often by browsers (about once a minute after a while); this sets the
  delay in SC-001.
- The existing overview data and states (OK, warning, critical, unavailable) are the source; no new state
  is introduced.
- "Unavailable" shows on every fresh start of an instance (measured during spec 004), so it never notifies.
- Notifications are for people who keep the monitor open. Unattended alerting stays with the instance's own
  tools.
