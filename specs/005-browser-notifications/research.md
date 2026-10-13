# Research: Browser notifications

## R1. Page notifications, not push
- **Decision**: the page's own Notification API, while the monitor tab is open.
- **Rationale**: push notifications (service worker + push service) need HTTPS, a push provider and a
  server component that sends; the module has none and the spec keeps the server unchanged (FR-011).
- **Alternatives**: Web Push (rejected above); e-mail from the server (that is the instance's own System
  Monitor alerting, pointed to in the README).

## R2. Polling while hidden
- **Decision**: a shell-level query on the same key as the Overview (`['overview']`) with a 30 s interval
  and refetching in the background, enabled only while notifications are on, granted and not idle.
- **Rationale**: the Overview's own query stops when the tab is hidden (`refetchIntervalInBackground:
  false`) and exists only on that screen. Sharing the key means one cache: when the Overview is open both
  observers read the same data. Browsers throttle hidden-tab timers (Chrome: about once a minute after
  5 minutes hidden), which is the delay the spec states (FR-009, SC-001: 90 s).

## R3. Transition rule
- **Decision**: `worse(prev, next)` is true only when `prev` is `ok` or `warning` and `next` ranks higher
  (`ok` < `warning` < `critical`). A missing previous state (first reading, new metric) or `unavailable` on
  either side sets the baseline and never notifies. The last state is updated on every successful reading,
  `unavailable` included; a failed reading changes nothing.
- **Rationale**: FR-005 and the owner's answer (A). Keeping `unavailable` as a state means the warm-up of a
  fresh instance (`unavailable` → `warning`, measured in spec 004) does not notify.

## R4. When to show
- **Decision**: notify when the document is hidden, or when the visible screen is not the Overview.
- **Rationale**: on the visible Overview the change is already on screen and announced to screen readers;
  a desktop notification would duplicate it. US1 describes the background-tab case.

## R5. One notification per transition in a browser
- **Decision**: before notifying, each transition is checked against `localStorage` key
  `hm.notified.<metric>` = `<state>|<epoch ms>`; if the same metric was notified for the same state in the
  last 10 minutes, it is dropped. The notification also carries a `tag` built from its transitions, so two
  identical notifications replace each other.
- **Rationale**: several tabs of the same browser each run the watcher (FR-006). `localStorage` is shared
  by the tabs of one origin; the tag covers a race between two tabs in the same instant.

## R6. Idle stop (owner's answer B)
- **Decision**: the last interaction time is set on `keydown`, `pointerdown` and when the tab becomes
  visible. A timer checks every minute; after 8 hours the watcher disables its query and shows one
  notification ("paused after 8 hours without activity"). The next interaction resumes it.
- **Rationale**: FR-008: a forgotten tab must not hold the session and a license unit indefinitely. The
  Overview's own polling only runs while visible, so it is unaffected.

## R7. Availability
- **Decision**: one state from three facts, in this order: `insecure` (`!window.isSecureContext`),
  `unsupported` (no `Notification`), then `Notification.permission` (`denied`, `default`, `granted`).
  Permission is requested only inside the click handler of the control (FR-002).
