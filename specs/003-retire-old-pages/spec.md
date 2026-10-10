# Feature Specification: Retire the old pages

**Feature Branch**: `003-retire-old-pages`

**Created**: 2026-10-09

**Status**: Draft

## Clarifications

### Session 2026-10-09
- Q: With the old pages gone, what happens to the switch that turns the new monitor on? → A: It is
  removed; the monitor is always on once the module is installed (FR-007).

**Input**: User description: "Spec 003, retire the old pages (release 2.0.0): remove the obsolete CSP pages (/csp/irismonitor/*.csp: dashboard, dashboardapi, history pages, systemprocesses) with their static resources and the old ObjectScript code they use (package diashenrique.historymonitor.dashboard and the util classes only they need), the /csp/irismonitor web application, and the ^IRISMonitor scratch globals they write. The new monitor at /historymonitor/ (spec 002) and the API v1 (spec 001) are the only interface. Anyone who opens an old address must still be sent to the new monitor, not get a bare error. An upgrade from 1.9.x must clean up what the old version left (web application, files, globals, the IRISMONITOR namespace created by the Docker image if it is no longer needed). This finishes Phase 2 ("replace ^IRISMonitor scratch globals") and is a breaking change (major version)."

## Context

Since 1.9.0 the old pages are obsolete: they show a banner that points to the new monitor and are out of
the menu (spec 002, FR-024). They still carry the most risk in the product. They render server pages
with a third-party grid library under a non-commercial license, keep per-request scratch data shared by
every user, and include a page that calls other hosts on request. Release 2.0.0 removes them, so the new
monitor and its API are the only way to use the product.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An old address leads to the new monitor (Priority: P1)

An operator opens a bookmark or a link to an old page (for example the old dashboard, a history page or
the process list). Instead of an error, they land on the matching screen of the new monitor: the old
dashboard opens the Overview, a history page opens History on the same metric, and the process list
opens Processes.

**Why this priority**: bookmarks, wiki links and runbooks point to the old addresses. A bare error after
an upgrade looks like an outage; landing on the right screen keeps people working.

**Independent Test**: after an upgrade, open each old address and check where the browser ends up.

**Acceptance Scenarios**:

1. **Given** 2.0.0 is installed, **When** a signed-in viewer opens the old dashboard address, **Then**
   they see the new Overview.
2. **Given** 2.0.0 is installed, **When** a viewer opens the old license, CSP sessions or database
   history address, **Then** they see History with that metric selected.
3. **Given** 2.0.0 is installed, **When** a viewer opens the old process list address, **Then** they see
   Processes.
4. **Given** a person who is not signed in, **When** they open an old address, **Then** they are asked to
   sign in and then see the matching screen.
5. **Given** any other address under the old prefix (an old static file, the old metrics proxy, an
   unknown page), **When** it is opened, **Then** the person lands on the new Overview, not on an error.
   No old content is served and no other host is called.

---

### User Story 2 - An upgrade leaves nothing of the old pages behind (Priority: P1)

An administrator upgrades an instance from 1.9.x to 2.0.0. Afterwards nothing that belonged only to the
old pages remains: no old page code, page files, static resources or scratch data. The new monitor, the
API, the viewer role, the Management Portal favourite and the monitoring sensors keep working as before.

**Why this priority**: code and data that are left behind keep the old risks (an outside library, shared
scratch data) and confuse anyone who looks at the instance later.

**Independent Test**: install 1.9.x, use the old pages so they leave scratch data, upgrade to 2.0.0, then
check the instance for leftovers and use the new monitor.

**Acceptance Scenarios**:

1. **Given** an instance with 1.9.x where the old pages were used, **When** it is upgraded to 2.0.0,
   **Then** the old page code, page files, static resources and scratch data are gone.
2. **Given** the same upgrade, **When** a viewer uses the new monitor, **Then** Overview, History and
   Processes work as before the upgrade, with the same role and the same sign-in.
3. **Given** the same upgrade, **When** the administrator looks at the Management Portal favourites and
   the monitoring sensors, **Then** they are unchanged.
4. **Given** 2.0.0 is installed fresh (no earlier version), **When** the install ends, **Then** none of
   the old parts are created.
5. **Given** 2.0.0 is uninstalled, **When** the uninstall ends, **Then** nothing of the module remains,
   including what upgrade cleanup removes.

---

### User Story 3 - The new monitor no longer depends on the old one (Priority: P2)

Everything that mentioned the old pages now stands on its own. The screen shown when the new monitor is
not available, the documentation, the container image and the automated checks no longer refer to or
offer the old pages.

**Why this priority**: a link or an instruction to a page that no longer exists is a dead end.

**Independent Test**: search the shipped product and its documentation for the old addresses; open the
new monitor in every state it can be in.

**Acceptance Scenarios**:

1. **Given** 2.0.0, **When** a viewer meets any screen of the new monitor, **Then** no screen links to
   or names the old pages, and no screen says the monitor is not turned on.
2. **Given** the documentation and release notes of 2.0.0, **When** an administrator reads them,
   **Then** they learn that the old pages are gone, where each old address now leads, and that this is a
   major version.
3. **Given** the container image of 2.0.0, **When** it starts, **Then** it serves only the new monitor
   and the API (and the old-address forwarding of User Story 1).

### Edge Cases

- An old address carries query parameters (for example a date range on a history page): the person still
  lands on the matching screen; the old parameters do not have to be carried over.
- An old address with an unknown page name or a deep path: lands on the Overview (User Story 1,
  scenario 5).
- The upgrade runs while someone has an old page open: the open page stops updating (its background
  requests now get the forwarding answer); when they reload or follow a link they land on the new monitor.
- Scratch data was written in more than one namespace (the old pages ran wherever the module was
  installed): cleanup covers the namespace the module is installed in.
- An upgrade from a version older than 1.9.x (for example 1.2.4): the result is the same as a fresh 2.0.0
  install, with the old parts removed.
- The old metrics proxy is called with parameters naming another host: no request leaves the server.
- An instance upgraded from 1.x had the new monitor switched off: after the upgrade the monitor is on
  (FR-007), and old addresses lead to it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The old pages MUST no longer be served. That covers the dashboard, the dashboard data page,
  the license, CSP sessions and database history pages, the process list, and their static resources.
- **FR-002**: Every address under the old prefix MUST lead to the new monitor:
  - the old dashboard leads to the Overview;
  - each history page leads to History with its metric (license, CSP sessions, database size);
  - the process list leads to Processes;
  - anything else leads to the Overview.

  Forwarding MUST keep the person's sign-in, or ask them to sign in first. It MUST NOT serve old content
  or call another host.
- **FR-003**: The forwarding of FR-002 MUST stay in place for the whole 2.x line. It is removed no
  earlier than the next major version.
- **FR-004**: The product MUST no longer contain the code that only the old pages used. The new monitor,
  the API, the viewer role, the favourite and the monitoring sensors MUST keep working unchanged.
- **FR-005**: An upgrade from any 1.x version MUST remove what the old pages left on the instance:
  - their code and page files;
  - their static resources;
  - their scratch data in the namespace where the module is installed.

  It MUST leave alone anything the module did not create.
- **FR-006**: An upgrade and an uninstall MUST NOT delete a namespace or a database. A namespace created
  for the module by the container image stays where it is; the image keeps installing the module there.
- **FR-007**: Nothing in the new monitor may point to the old pages. The switch that turned the new
  monitor on is removed: once the module is installed, the monitor is on for everyone who holds the viewer
  role, after a fresh install and after an upgrade. The "not turned on" state and the setting behind it
  no longer exist. An administrator who wants to keep people out removes the viewer role from them or
  disables the web application, as for any IRIS application.
- **FR-008**: The version MUST be 2.0.0, a major version, because addresses that worked in 1.x stop
  serving their pages.
- **FR-009**: The release notes MUST list what was removed, where each old address now leads, and what
  the upgrade cleans up.
- **FR-010**: The container image MUST serve only the new monitor, the API and the forwarding of FR-002.
- **FR-011**: The automated checks MUST prove the forwarding (FR-002), the absence of old parts after a
  fresh install and after an upgrade from 1.9.x (FR-001, FR-004, FR-005), and that no screen of the new
  monitor links to the old pages (FR-007).

### Key Entities

- **Old address**: a URL under the old prefix that people may still have saved. It maps to a screen of
  the new monitor (FR-002).
- **Old-page scratch data**: per-request data the old pages wrote for their grids and charts. It has no
  value after the request ends and nothing else reads it.
- **Monitor switch** (removed): the administrator setting that decided whether the new monitor was
  shown. 2.0.0 removes it (FR-007); a value left by 1.x is cleaned up like the other old parts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the old page addresses (6 pages) lead to the matching new screen, and any other
  address under the old prefix leads to the Overview. None shows an error.
- **SC-002**: After an upgrade from 1.9.x, a check of the instance finds zero old pages, zero old page
  files, zero old static resources and zero old scratch data in the module's namespace.
- **SC-003**: After the upgrade, every automated check of the new monitor and the API that passed on 1.9.x
  still passes.
- **SC-004**: Zero links to old pages in the shipped interface and in the documentation, except the
  sections that describe the removal.
- **SC-005**: The shipped product no longer includes the third-party grid library of the old pages.

## Assumptions

- Nobody depends on the old pages' data as an integration point; the API v1 is the supported way to read
  the monitor's data (spec 001).
- The monitoring sensors (SAM) are a separate feature and stay. They do not use the old pages.
- Forwarding by address is enough; old query parameters (date ranges, filters) are not carried over.
- "The namespace the module is installed in" is where old scratch data lives. Other namespaces are not
  searched.
- People who still have an old page open when the upgrade runs accept that their next action takes them
  to the new monitor.
