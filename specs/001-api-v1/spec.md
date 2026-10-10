# Feature Specification: Versioned Read API (v1)

**Feature Branch**: `001-api-v1`
**Created**: 2026-10-07
**Status**: Clarified (one default pending confirmation)
**Input**: User description: "Phase 2 of the redesign plan: replace the page-per-metric CSP classes with one versioned REST API that serves the overview, the process list and the history series, so a new interface can be built on a stable contract."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read the system overview from one place (Priority: P1)

An operator or the UI asks for the current health of the instance and receives one consistent snapshot: system status, license usage, CSP sessions, cache efficiency, journal, backup, locks, write daemon and application errors.

**Why this priority**: The Overview is the screen people open first, and today it needs two dashboards ("System Dashboard" and "System Dashboard 2.0") that call different sources. One snapshot is the smallest slice that removes that duplication.

**Independent Test**: Request the overview with a valid account and compare each returned value with the same figure shown by the Management Portal. Delivers value alone because the current UI can be pointed at it.

**Acceptance Scenarios**:

1. **Given** a running instance, **When** the overview is requested, **Then** every metric the current dashboards show is present, with a unit and a status of ok, warning or critical.
2. **Given** a metric source is unavailable, **When** the overview is requested, **Then** the other metrics are still returned and the missing one is marked unavailable with a reason, not omitted.
3. **Given** the last backup never ran, **When** the overview is requested, **Then** the backup entry is reported as a warning, not as neutral information.

---

### User Story 2 - Query history by metric, granularity and period (Priority: P1)

A user asks for license usage, CSP sessions or database size over a period, at 5-minute, hourly or daily granularity, and receives a time series in ascending order.

**Why this priority**: History is three pages with three sections each today. One query shape is what lets the UI collapse them into one screen.

**Independent Test**: Request each metric at each granularity for a known period and compare the points with the System Monitor history tables.

**Acceptance Scenarios**:

1. **Given** a metric, a granularity and a date range, **When** the series is requested, **Then** points are returned oldest first, each with a timestamp and a value, and an unknown metric or granularity is rejected with a clear error.
2. **Given** a range holding more points than one response may carry, **When** the series is requested, **Then** the response says it was truncated and how to get the rest. Points are never dropped silently.
3. **Given** a start date after the end date or an unparseable date, **When** the series is requested, **Then** the request is rejected with a clear error and nothing is queried.
4. **Given** two users request different ranges at the same time, **When** both complete, **Then** each receives only the data for its own range.

---

### User Story 3 - List processes with server-side filtering (Priority: P2)

A user lists running processes, filters by namespace, user, state or text, sorts, and pages through the result without the browser receiving all 14 columns for every process.

**Why this priority**: The process table is the heaviest page and its filters are the main usability complaint, but it can be shipped after the overview and history.

**Independent Test**: Request a filtered, sorted page and compare it with the Management Portal process list.

**Acceptance Scenarios**:

1. **Given** a filter and a page size, **When** the list is requested, **Then** only matching processes up to the page size are returned, with the total count and a way to request the next page.
2. **Given** a process that ends between two page requests, **When** the next page is requested, **Then** the response is still valid and does not fail.
3. **Given** a system daemon with no user or device, **When** it is listed, **Then** empty fields are returned as absent, not as placeholder text.

---

### User Story 4 - Predictable errors and access control (Priority: P2)

Every failure returns the same error shape, and only accounts holding a dedicated resource can read the API.

**Why this priority**: The UI and any script need to react to failures without parsing text, and the monitor exposes system internals.

**Independent Test**: Call each route without credentials, with an account lacking the resource, and with bad input, and check status and shape.

**Acceptance Scenarios**:

1. **Given** no valid credentials, **When** any route is called, **Then** the response is an authentication error and no data is returned.
2. **Given** an authenticated account without the monitor resource, **When** any route is called, **Then** the response is a forbidden error.
3. **Given** any failure, **When** the response is read, **Then** it carries a machine-readable type, a short title, a status and a human-readable detail.

---

### User Story 5 - Current screens read from the API (Priority: P3) - DEFERRED to Phase 4

> Removed from this feature on 2026-10-09 by the owner: the old pages will not be used; the new interface (Phase 4) is the first client of the API. Kept below for history.

Until the new interface exists, the existing pages keep rendering and read their data from the API instead of running their own queries.

**Why this priority**: It proves the API covers what users see today and lets old and new code share one source of truth before the old pages are retired.

**Independent Test**: Open every existing page before and after the change and compare what they show.

**Acceptance Scenarios**:

1. **Given** the existing pages, **When** they load after the change, **Then** they show the same figures as before.
2. **Given** the old page URLs, **When** they are requested, **Then** they still respond.

### Edge Cases

- A period with no data: an empty series with a success status, not an error.
- A period that crosses a daylight-saving change: timestamps stay unambiguous and ordered.
- System History tables are empty on a fresh instance: the series is empty and the overview still works.
- The monitor is called on an instance where the SAM sensors are not registered: the overview reports those metrics as unavailable.
- An unlisted metric name containing quotes, spaces or code: rejected as invalid input and never executed or echoed unescaped.
- A very large page size: capped at a documented maximum.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose the overview, the history series and the process list through one versioned API, with the version in the path.
- **FR-002**: The overview MUST include every metric shown today by the System Dashboard and System Dashboard 2.0, each with a unit and a status.
- **FR-003**: The history series MUST accept a metric (license usage, CSP sessions, database size), a granularity (5 minutes, hourly, daily) and a date range, and MUST return points oldest first.
- **FR-004**: A response that holds fewer points than the range contains MUST say so and MUST offer a way to continue. Silent truncation is not allowed.
- **FR-005**: The process list MUST support filtering, sorting and paging on the server, and MUST report the total count.
- **FR-006**: All query inputs MUST be validated against an allow-list or a strict format before use, and MUST reach the database only as parameters.
- **FR-007**: Every error MUST use one problem-style shape with a type, title, status and detail.
- **FR-008**: Access MUST require a dedicated resource, separate from general administrative rights, and the install package MUST create the role that holds it.
- **FR-009**: The API MUST NOT write shared per-request state, so concurrent requests cannot affect each other.
- **FR-010**: The contract MUST be published as a machine-readable document kept in the repository, and every route MUST have a test that fails when its response shape drifts.
- **FR-011** (withdrawn 2026-10-09, see Clarifications): ~~The existing pages MUST read their data from the API~~. The old class URLs keep responding, unchanged, until the new interface replaces them.
- **FR-013**: A history request MUST support windows up to 90 days at daily and hourly granularity, and MUST report the coverage actually available (first and last timestamp) when the System Monitor holds less than the window asked for.
- **FR-012**: The API MUST honour the project constitution: no dynamic code execution from request data, parameterized SQL, host validation for any outbound call.

### Key Entities

- **Overview snapshot**: the instant state of the instance as a set of named metrics, each with a value, unit and status.
- **History series**: a metric at a granularity over a period, as ordered timestamp and value points, plus truncation information.
- **Process**: one running process with its identifying and state fields; absent fields are omitted.
- **Problem**: the shape of every error.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every figure on the current Overview, License, CSP Sessions, Database and Processes pages can be obtained from the API, checked by a side-by-side comparison on a sample instance.
- **SC-002**: A 90-day daily series and a 90-day hourly series are each returned in under 2 seconds at the 95th percentile on the reference Docker image. This is a target, to be confirmed by measurement.
- **SC-003**: 100% of routes have a contract test and an authorization test, and the CI run is green before merge.
- **SC-004**: No request handler writes to a shared scratch global, confirmed by a test that runs two overlapping requests with different ranges.
- **SC-005**: The security tests from the earlier hardening phase still pass unchanged.

## Assumptions

- The first consumers are the existing pages and, later, the new interface; third-party consumers are not a goal of v1.
- The API is read-only in v1. Anything that changes system state is out of scope.
- The data sources stay as they are today: System Monitor history tables, the dashboard sample, process queries and the SAM sensors.
- The Message Viewer screen has no matching page in the repository and is out of scope here.
- The new interface uses this API but is specified separately (Phase 4).

## Clarifications

### Session 2026-10-07

- Q: How far back must history reach? -> A: 90 days. A 90-day window must be answerable at daily and hourly granularity. When the System Monitor holds less than the requested window at a granularity, the response returns what exists and reports the real coverage, instead of failing.
- Q: Should the old pages move to the API in this feature? -> A: Yes. The existing pages read from the API in this feature; their old class URLs keep responding but no page uses them.
- Q: Which authentication does the API accept? -> The same authentication the IRIS web application already provides (password login, session cookie or HTTP basic), no tokens in v1. Anonymous access stays disabled. Confirmed by the owner on 2026-10-07.

### Session 2026-10-09

- Q: Should the old pages still move to the API (user story 5)? -> A: No. The old pages will not be used; work goes to the new interface in Phase 4. US5 and FR-011 are withdrawn from this feature. Replaces the 2026-10-07 answer.
- Q: May a viewer list every process without `%Admin_Manage`? -> A: Yes, accepted as designed (research.md R10).
- Q: Is a 401 with an empty body, instead of a problem, acceptable? -> A: Yes; anonymous access stays disabled (research.md R11).
- Q: Overview status thresholds (license 80/95 percent, serious alerts above 0)? -> A: Accepted (research.md R8).
