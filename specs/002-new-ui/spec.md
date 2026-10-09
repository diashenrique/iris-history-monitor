# Feature Specification: New Monitor Interface

**Feature Branch**: `002-new-ui`

**Created**: 2026-10-09

**Status**: Clarified

**Input**: User description: "Spec 002, interface nova (Fase 4): uma interface web nova, com o novo design, reformulado para o que existe hoje de mais moderno e dinâmico, pois precisa ser atraente e informativo, que substitui as páginas antigas e usa a API v1 (/api/historymonitor/v1) como única fonte de dados. Primeira entrega: a tela de Overview, liberada por uma flag, seguida de Histórico (licença, sessões CSP, tamanho de banco) e Processos. A constitution define que a interface é servida como arquivos estáticos pela aplicação web do IRIS, segue WCAG 2.2 AA e suporta en, pt-BR e es. O login precisa ser compartilhado com a API, como medido na research.md R12."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the health of the instance at a glance (Priority: P1)

An operator opens the monitor and, on one screen, sees whether the instance is healthy: every overview metric with its value, unit and status, the problems first, and the figures updating on their own while the screen is open, with a short trend of how each changing number moved since the screen was opened.

**Why this priority**: The Overview is the first screen people open and the first delivery the owner asked for. It replaces two old dashboards and proves the new design on real data.

**Independent Test**: Turn the new interface on, sign in with a monitor account, and compare every figure on the Overview with the same overview read directly from the API at the same moment.

**Acceptance Scenarios**:

1. **Given** the new interface is turned on and the user is signed in, **When** the Overview opens, **Then** all 18 overview metrics are shown with value, unit and status, and any metric that is not ok is placed before the ok ones.
2. **Given** a metric is a warning, critical or unavailable, **When** it is shown, **Then** its status is conveyed by text and an icon as well as color, and an unavailable metric shows the reason given by the API.
3. **Given** the Overview stays open, **When** the refresh interval passes, **Then** the figures update without reloading the page, the time of the last update is shown, and changing numbers show their trend since the screen was opened.
4. **Given** the data source stops answering, **When** a refresh fails, **Then** the last figures stay visible, are marked as out of date with the time of the last successful update, and the screen recovers by itself when the source answers again.
5. **Given** the new interface is turned off, **When** a user goes to its address, **Then** they are told it is not enabled and pointed to the existing pages.

---

### User Story 2 - Explore history for license, CSP sessions and database size (Priority: P1)

A user picks a metric (license usage, CSP sessions or database size), a granularity (5 minutes, hourly, daily) and a period (preset or custom), and sees an interactive chart and a matching table. They can see exact values by pointing at the chart, compare statistics or databases, and know when the instance does not keep data for the whole period.

**Why this priority**: History is three old pages with three sections each. One screen that answers "what happened over this period" is the main reason to use the monitor after the Overview.

**Independent Test**: Choose each metric and granularity over a period with known data and compare the points shown with the same request made to the API.

**Acceptance Scenarios**:

1. **Given** a metric, granularity and period, **When** the user applies them, **Then** the chart and the table show the same points in time order, with times in the user's local time zone and the zone named.
2. **Given** the instance keeps data for only part of the period, **When** the result is shown, **Then** the screen states the period actually covered (first and last time present) instead of implying the whole period.
3. **Given** a period holds more points than one response returns, **When** the result is shown, **Then** the screen loads the remaining points itself or clearly offers to, and never silently shows a cut series.
4. **Given** database size is chosen, **When** the result is shown, **Then** the user can choose which databases to show, and each database is a distinguishable series.
5. **Given** a period with no data, **When** it is applied, **Then** the screen says there is no data for that period rather than showing an empty chart without explanation.
6. **Given** a chosen metric, granularity and period, **When** the user copies the page address and opens it later, **Then** the same view is restored.

---

### User Story 3 - Find and inspect running processes (Priority: P2)

A user looks for processes by namespace, user, state or free text, sorts by any column, pages through the result, and opens one process to see all of its details.

**Why this priority**: The process list is the heaviest old page and its filters are the main usability complaint, but it is used less often than the Overview and history.

**Independent Test**: Apply a filter and a sort and compare the rows and the total with the same request made to the API.

**Acceptance Scenarios**:

1. **Given** the process screen, **When** the user filters and sorts, **Then** only matching processes are shown, in the chosen order, with the total number of matches.
2. **Given** a process row, **When** the user opens it, **Then** every field the API returns for it is shown, and fields the process does not have are not shown as blank placeholders.
3. **Given** automatic refresh is on, **When** a process ends between refreshes, **Then** the list updates without an error, and the user can pause refreshing while reading.

---

### User Story 4 - Sign in once and keep working (Priority: P2)

A user signs in once and uses every screen of the new interface without being asked for credentials again until the session ends. A user without monitor access is told so clearly.

**Why this priority**: Without a shared sign-in the screens cannot read data at all (research.md R12 of spec 001); it is a precondition of every other story, delivered alongside the first screen.

**Independent Test**: Sign in, use all screens, let the session expire, and use an account without the monitor role.

**Acceptance Scenarios**:

1. **Given** a signed-in user, **When** they move between screens, **Then** no screen asks for credentials again and every screen shows data.
2. **Given** the session expires, **When** the next data request fails for that reason, **Then** the user is sent to sign in and, after signing in, returns to the screen they were on.
3. **Given** an account that can sign in but lacks monitor access, **When** it opens the interface, **Then** it sees a "no access" message naming the role it needs, and no data.

---

### User Story 5 - Use it in my language, with any ability, on any screen size (Priority: P3)

A user switches the interface between English, Brazilian Portuguese and Spanish, chooses a light or dark appearance, and uses every screen with a keyboard, a screen reader, or a narrow phone screen.

**Why this priority**: These are constitution requirements for any new interface; they are spread over every screen and checked at the end, but each screen is built with them from the start.

**Independent Test**: Run every screen in each language and appearance, with keyboard only, with a screen reader, and at phone width, and run an accessibility audit.

**Acceptance Scenarios**:

1. **Given** any screen, **When** the user changes the language, **Then** all text, numbers, dates and times follow that language without reloading, and the choice is remembered.
2. **Given** a keyboard-only user, **When** they use any screen, **Then** every action can be reached and the focus is always visible.
3. **Given** a chart, **When** a screen reader user reaches it, **Then** the same information is available as text or a table.
4. **Given** a phone-width screen, **When** any screen is used, **Then** nothing needs horizontal scrolling except wide tables, which scroll on their own.

### Edge Cases

- The instance has just been installed: history is empty and the Overview still shows every metric.
- A period crosses a daylight-saving change: times stay in order and none is shown twice or skipped.
- The user's browser is in a time zone different from the server: times are shown in the user's zone, labelled.
- Several thousand processes are running: the list stays responsive because filtering and paging happen in the source.
- The data source answers with an error the screen does not expect: a short message is shown with the problem title from the source, never raw technical text.
- The user opens two screens in two browser tabs: both work with the same sign-in.
- The new interface is turned off while a user has it open: on the next refresh the user is told it is no longer enabled.

## Clarifications

### Session 2026-10-09

- Q: When the new interface is complete, what happens to the old pages? -> A: They are marked obsolete and removed from the menu, the new interface becomes the default entry point, and the old pages stay reachable by address until a later release (FR-024).
- Q: How is the sign-in shared with the API (research.md R12 of spec 001)? -> A: The interface and the API are served under one common address prefix with the session limited to that prefix; the API address moves under it (FR-025).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The new interface MUST read all of its data from the monitor API v1 and from no other source.
- **FR-002**: The new interface MUST be switchable on and off for the whole instance by an administrator, and MUST start switched off. While it is off its address MUST explain that it is not enabled.
- **FR-003**: The Overview MUST show all overview metrics with value, unit and status, ordered with non-ok metrics first, and MUST show the reason for any unavailable metric.
- **FR-004**: Status MUST never be conveyed by color alone; each status MUST also have a text label and an icon.
- **FR-005**: The Overview MUST refresh on its own at an interval the user can pause, MUST show the time of the last successful update, and MUST mark figures as out of date when a refresh fails.
- **FR-006**: The Overview MUST show, for each numeric metric, its trend since the screen was opened.
- **FR-007**: The history screen MUST let the user choose metric, granularity and period, with presets for the last 24 hours, 7 days, 30 days and 90 days and a custom range.
- **FR-008**: The history screen MUST show the result as a chart and as a table of the same points, MUST show exact values on demand, and MUST state the period actually covered when it is shorter than the one asked.
- **FR-009**: The history screen MUST obtain every point of the chosen period, following the source's continuation until the series is complete or offering to, and MUST never present a truncated series as complete.
- **FR-010**: For database size, the user MUST be able to choose which databases are shown.
- **FR-011**: The process screen MUST offer filtering by namespace, user, state and free text, sorting by any shown column, paging with the total count, a detail view of one process, and an automatic refresh that can be paused.
- **FR-012**: The user MUST be able to export the data currently shown on the history and process screens as a CSV file.
- **FR-013**: The chosen screen, filters, metric, granularity and period MUST be kept in the page address so that a view can be bookmarked and shared.
- **FR-014**: A user MUST sign in once to use every screen and every data request; the sign-in MUST be the instance's own (no new accounts or passwords). Anonymous access MUST stay disabled.
- **FR-015**: When the session expires the user MUST be asked to sign in again and returned to the screen they were on.
- **FR-016**: An account without monitor access MUST see a message naming the role it needs and no data.
- **FR-017**: All text MUST be available in English, Brazilian Portuguese and Spanish; numbers, dates and times MUST follow the chosen language; the choice MUST be remembered per browser. The initial language MUST follow the browser, falling back to English.
- **FR-018**: Times MUST be shown in the user's local time zone with the zone named.
- **FR-019**: Every screen MUST meet WCAG 2.2 level AA, including keyboard operation, visible focus, sufficient contrast in both appearances, and a text or table alternative for every chart.
- **FR-020**: The interface MUST offer a light and a dark appearance, following the operating system by default, with the choice remembered per browser.
- **FR-021**: Every screen MUST be usable from a 360-pixel-wide phone screen up to a wide desktop screen.
- **FR-022**: Error messages MUST be short, in the chosen language, based on the problem returned by the source, and MUST never show stack traces or internal text.
- **FR-023**: The screens MUST be delivered in this order, each usable on its own: Overview (with sign-in), then History, then Processes.
- **FR-024**: The existing pages MUST keep working, unchanged, while the new interface is being delivered. When the three screens are complete, the old pages MUST be marked obsolete and removed from the menu, with the new interface as the default entry point; they MUST stay reachable by their address until a later release removes them.
- **FR-025**: The sign-in MUST be shared between the interface and the API by serving both under one common address prefix, with the session limited to that prefix, so that no other application on the same server sees the session. The API keeps its v1 contract; only its address moves under the prefix.

### Key Entities *(include if feature involves data)*

- **Overview metric**: a named figure with value, unit, status and, when unavailable, a reason; shown live, with a short trend kept only while the screen is open.
- **History view**: a metric, a granularity, a period and, for database size, a set of databases; produces one or more series of time-ordered points plus the period actually covered.
- **Process**: one running process with its identifying and state fields; fields it does not have are absent.
- **User preferences**: language and appearance, kept in the browser; not shared between browsers.
- **Interface switch**: the instance-wide on/off setting for the new interface.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a moderated test with at least five operators, each identifies every metric that is not ok within 5 seconds of the Overview appearing.
- **SC-002**: On the reference instance the Overview shows its first complete set of figures within 2 seconds of opening, and a 90-day history view appears within 3 seconds.
- **SC-003**: Every figure shown on the three screens equals the value returned by the API at the same moment, checked side by side for every metric, each granularity, and one filtered process page.
- **SC-004**: An automated accessibility audit of every screen in both appearances reports no critical or serious issue, and a keyboard-only user completes the main task of each screen.
- **SC-005**: 100% of interface text exists in all three languages, checked automatically.
- **SC-006**: A recorded session of normal use shows no data request to anything other than the monitor API.
- **SC-007**: Every screen is fully usable at 360 pixels wide without page-level horizontal scrolling.
- **SC-008**: In the same moderated test, at least four of five participants rate the new interface as clearer than the old pages for finding the instance's state.

## Assumptions

- The data comes only from the API delivered by spec 001 (overview, history, processes); any figure the API does not provide (for example the Message Viewer) is out of scope.
- The Overview refreshes every 10 seconds by default; the user can pause it. The process list refreshes every 15 seconds when its automatic refresh is on.
- The Overview trend covers only the time the screen has been open (the API has no short-term history of overview figures); longer trends belong to the history screen.
- "Modern and dynamic" means smooth live updates, interactive charts with values on demand, light and dark appearances and a responsive layout; the exact visual design (palette, typography, layout) is decided in the plan with a design mock-up reviewed by the owner.
- Users are the same accounts that use the monitor today; access is granted by the monitor role created by spec 001. There are no new user types or permissions.
- The interface is turned on and off for the whole instance by an administrator; per-user switching is not needed.
- Export is CSV of what is currently shown; other formats are out of scope.
- Supported browsers are the current versions of Chrome, Edge, Firefox and Safari.
- Removing the old pages for good, and the shared temporary data they write, belongs to a later release (FR-024).
