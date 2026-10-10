# Feature Specification: History collection health

**Feature Branch**: `004-history-collection-health`

**Created**: 2026-10-10

**Status**: Draft

**Input**: User description: "Spec 004, history collection health (Phase 3): on a standard IRIS 2026.1 install the System Monitor history collection is off (no %Monitor.System.HistoryPerf / HistorySys class active, no %MONAPP process), so the History screen is empty with no explanation; after a restart, the Application Monitor did not come back on its own even with the classes active. Retention is not the problem (5-minute detail 7 days, hourly 60 days, daily never purged), so the product will not keep its own rollups. The monitor must tell viewers and administrators whether history is being collected and how many days of each granularity the instance keeps; when collection is off or stale, the History screen explains it and shows an administrator what to do. Owner decision (option A): the module never turns collection on by itself; it only reports and guides (documented commands). Also find out why the Application Monitor does not restart after a container restart and document the fix. README gets a "Turning on history collection" section."

## Context

The History screen reads what the instance's own history collector records. Measured on IRIS 2026.1
(2026-10-10):
- On a standard install the collector is off, so nothing is recorded and History stays empty with no
  reason given.
- Once turned on, it records within 5 minutes.
- After a restart, the collector stayed off even though it was still configured to run.
- The instance keeps 5-minute detail for 7 days and hourly summaries for 60 days, and never purges
  daily summaries. Both limits can be changed by an administrator.

Retention is therefore enough, and the product will not keep its own copies. What is missing is telling
people whether history is being recorded and what to do when it is not. Phase 3 of the plan ("history
model") becomes this.

## Clarifications

### Session 2026-10-10
- Q: Should the module turn history collection on by itself? → A: No (owner, option A). It reports the
  state and guides an administrator with documented steps. It never changes the instance's monitoring
  configuration.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Know whether history is being recorded (Priority: P1)

An operator opens History and sees an empty chart. Instead of guessing, they read on the screen that the
instance is not recording history, since when the last sample was taken (if ever), and that an
administrator needs to turn collection on. The screen links to the steps.

**Why this priority**: this is the situation of every standard install today. An empty History screen
with no reason looks like a broken product.

**Independent Test**: on an instance with collection off, open History; on one with collection on and
recent samples, open History.

**Acceptance Scenarios**:

1. **Given** collection is off and nothing was ever recorded, **When** a viewer opens History, **Then**
   the screen says history is not being recorded, that an administrator can turn it on, and links to the
   steps. No empty chart is shown without that message.
2. **Given** collection is off but older samples exist, **When** a viewer opens History, **Then** the
   recorded data is shown with a notice that recording stopped, giving the time of the last sample.
3. **Given** collection is configured but the last sample is older than three collection intervals
   (stale), **When** a viewer opens History, **Then** the same notice as scenario 2 appears and names the
   likely cause (the collector is not running, for example after a restart).
4. **Given** collection is running and the last sample is recent, **When** a viewer opens History,
   **Then** no notice is shown.

---

### User Story 2 - Know how far back each view can go (Priority: P2)

A viewer chooses a granularity and a period. They can see how many days of that granularity the instance
keeps (for example "5-minute detail: last 7 days"), so they choose a period the instance can answer.

**Why this priority**: today the screen only says, after the fact, that part of the period is missing.
Saying the limit up front avoids empty requests.

**Independent Test**: open History on instances with default and with changed retention; compare the
limits shown with the instance's settings.

**Acceptance Scenarios**:

1. **Given** default settings, **When** a viewer looks at the granularity choices, **Then** they see 7
   days for 5-minute detail, 60 days for hourly, and "kept indefinitely" for daily.
2. **Given** an administrator changed the hourly retention to 90 days, **When** a viewer opens History,
   **Then** the hourly limit shows 90 days.
3. **Given** a period longer than the chosen granularity keeps, **When** the result is shown, **Then** the
   existing partial-period notice still applies and names the retention limit as the reason.

---

### User Story 3 - An administrator can turn collection on, and keep it on (Priority: P2)

An administrator follows the documented steps. After that, history is recorded within minutes and keeps
being recorded after the instance restarts, including the container image.

**Why this priority**: the guidance is only useful if it works, including after a restart, which is
where the measured behaviour failed.

**Independent Test**: on a fresh instance, follow the README steps, check that samples arrive, restart,
and check that samples keep arriving.

**Acceptance Scenarios**:

1. **Given** a fresh instance, **When** an administrator follows the documented steps, **Then** the
   first sample is recorded within 10 minutes and History stops showing the "not recorded" message.
2. **Given** collection was turned on following the steps, **When** the instance restarts, **Then**
   samples keep arriving within 10 minutes of the restart without anyone acting.
3. **Given** the module is installed or upgraded, **When** the install ends, **Then** the instance's
   history collection settings are exactly as they were before (option A).

### Edge Cases

- The viewer has the monitor role but is not an administrator: they see the state and the steps, which
  are labeled as administrator steps. Nothing on the screen can change the instance's configuration.
- Collection is turned on while a viewer has History open: within one refresh the notice goes away.
- The instance clock or time zone differs from the viewer's: the time of the last sample is shown in the
  viewer's time zone, like other times on the screen.
- The retention settings cannot be read (permissions, older IRIS): the limits are shown as unknown and
  History still works.
- Only one of the two collector parts is active (performance or system usage): the state is reported
  per metric the History screen uses. The three metrics come from system usage, so that part decides.
- Demo data loaded by an administrator for evaluation exists but nothing new is recorded: this is the
  same as scenario 2 or 3 of User Story 1.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The monitor MUST report the state of history collection as one of:
  - **recording**: the collector is configured and the last sample is recent;
  - **stale**: the collector is configured but no sample arrived in the last three collection intervals;
  - **off**: the collector is not configured.

  It MUST also report the time of the last recorded sample, if there is one.
- **FR-002**: The monitor MUST report, for each granularity it offers (5-minute, hourly, daily), how many
  days the instance keeps, or that it keeps them indefinitely, or that the limit is unknown.
- **FR-003**: Any viewer with the monitor role MUST be able to read FR-001 and FR-002 through the API v1
  as an additive change (no existing response changes shape).
- **FR-004**: History MUST show a notice when the state is "off" or "stale". The notice states the
  situation, gives the time of the last sample when there is one, and links to the documented steps.
  With no data at all, the notice replaces the empty chart.
- **FR-005**: History MUST show the retention limit of each granularity next to the granularity choice.
  When a result is partial, the partial notice MUST name the retention limit when that is the reason.
- **FR-006**: The module MUST NOT change the instance's history collection or retention settings, on
  install, upgrade, uninstall or at any other time (option A).
- **FR-007**: The README MUST have a section "Turning on history collection". It gives the steps to turn
  collection on, to keep it running after a restart (including in the container image), and to change
  retention. Every step is run and checked during development (SC-003).
- **FR-008**: The reason the collector did not resume after a restart MUST be found and recorded in
  research, with the fix the README gives.
- **FR-009**: Notices and labels MUST be in English, Portuguese (Brazil) and Spanish and meet WCAG 2.2
  AA, like the rest of the interface (spec 002).
- **FR-010**: The container image of this repository MAY turn collection on for itself, as a
  demonstration environment, if research shows it is needed for the image to be useful. That is the
  image's own setup, not the module's install (FR-006 still holds for the module).

### Key Entities

- **Collection state**: recording, stale or off; the time of the last sample; the collection interval it
  was judged against.
- **Retention**: per granularity, the number of days kept, "indefinitely" or "unknown".

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On an instance where collection is off, 100% of History views either show data with a
  "stopped" notice or show the "not recorded" message. None shows an unexplained empty chart.
- **SC-002**: The retention limits shown match the instance's settings in 100% of checks: defaults, and
  values changed by an administrator.
- **SC-003**: An administrator following only the README gets samples recorded within 10 minutes on a
  fresh instance, and again within 10 minutes after a restart. Checked on the container image and on a
  plain install.
- **SC-004**: After installing or upgrading the module, the instance's collection and retention settings
  are identical to before, in 100% of checks.
- **SC-005**: The notice goes away within one refresh of History after collection resumes.

## Assumptions

- "Collection interval" is the instance's own interval for system usage samples (5 minutes by default).
  "Stale" is three intervals without a sample, about 15 minutes with the defaults.
- The three History metrics (license use, CSP sessions, database size) come from the system-usage part
  of the collector. The performance part is not needed for them.
- The retention limits are read from the instance at request time; they are not configured in the
  module.
- The container image is a demonstration and development environment; production installs go through
  IPM on an existing instance.
- No own rollups or copies of history are kept (Phase 3 decision, measured retention).
