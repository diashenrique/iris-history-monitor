<!-- Draft of the article for the InterSystems Developer Community.
     The published version will be the reference; this draft stays for history.
     Links and images point to the repository on GitHub, so they work from the Community too.
     The images are served from the master branch. -->

# iris-history-monitor, redesigned: a new interface and a REST backend for IRIS 2026.1

In 2019 I wrote [iris-history-monitor](https://openexchange.intersystems.com/package/iris-history-monitor) to show, in a visual way, what the System Monitor records about an InterSystems IRIS instance, and to replace the Management Portal's dashboard and process list with something easier to read.

It worked, but it had aged. It was a set of CSP pages on top of a large grid library, it kept per-request data in shared globals, and on a current IRIS its History screen was empty without saying why. This post is about the redesign: what you see now, and what changed under it so that the backend works on IRIS 2026.1.

![The new Overview](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/new-overview-light.png)

## What changed

- **A new interface with three screens.** Overview, History and Processes, built as static files (React, TypeScript, Vite) that IRIS serves from its own web application. There is no build step on the server and no other web server to run.
- **A REST API with a contract.** The interface reads one versioned API, `/historymonitor/api/v1`, described by an OpenAPI document in the repository. Errors are `application/problem+json`.
- **One sign-in.** The pages and the API share one IRIS session. Users hold a role, `HistoryMonitorViewer`, that lets them read the monitor and nothing else.
- **The old pages are gone.** The old addresses forward to the matching new screen, so bookmarks keep working.
- **It tells you when history is not recorded.** On a standard IRIS install the System Monitor records no history. The History screen used to be empty; now it says so and shows an administrator what to do.
- **Installs with IPM or Docker.** `zpm "install iris-history-monitor"`, or a published image.
- **Kept honest by CI.** Every pull request runs the ObjectScript tests, an IPM install on a clean instance, an upgrade from the previous version, the interface tests, end-to-end tests in a browser and a Docker build.

## Before and after

This is the System Dashboard of 2019 and the Overview of today. The old one drew a chart per metric and showed the state as a word and a green tick. The new one puts what needs attention first, and states every status as an icon, a word and a color, never the color alone.

| 2019 | Now |
| --- | --- |
| ![The old System Dashboard](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/SystemDashboard.png) | ![The new Overview](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/new-overview-light.png) |
| ![The old System Processes](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/SystemProcesses.png) | ![The new Processes](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/new-processes.png) |

## The interface

### Overview

Every metric of the dashboard with its state: OK, warning, critical or unavailable. The metrics that need attention come first, and the page refreshes by itself every 10 seconds. A **Pause** button stops the refresh, and screen readers are told when a state changes, not on every refresh.

### History

License use, CSP sessions and database size, every 5 minutes, hourly or daily, as a chart with zoom and as a table, with CSV export. The history tables are keyed in UTC; the screen shows the times in your own time zone.

Two things are new. Under **Granularity** it says how long the instance keeps that granularity ("Kept: last 60 days"), and when recording has stopped it says so, with the time of the last sample:

![History with the collection notice](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/new-history-notice.png)

### Processes

The process list with filters (namespace, user, state, text), sorting, paging, a detail dialog for one process, and CSV export.

### Languages, themes and small screens

The interface is available in English, Portuguese (Brazil) and Spanish, in light, dark or the system theme, and it works on a phone-sized screen.

| Portuguese, dark theme | On a phone |
| --- | --- |
| ![Overview in Portuguese](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/new-overview-pt-br.png) | ![Overview on a phone](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/new-overview-mobile.png) |

The first screen weighs about 133 KB of JavaScript, gzipped. The pages it replaced shipped 1,400 static files, 103 MB, of which the grid library alone (DevExtreme 18.2.3) was 64 MB.

## The backend on IRIS 2026.1

### A REST API instead of pages

The old pages were `%CSP.Page` classes that picked the method to run from the request, and they wrote the result of each request into `^IRISMonitor`, a global shared by every user. Two users could overwrite each other.

Now the API is a `%CSP.REST` class with an explicit URL map, and a small service layer under it:

| Route | What it returns |
| --- | --- |
| `GET /overview` | The current snapshot of the dashboard metrics, each with a status. |
| `GET /history/{metric}` | A series for `license`, `csp-sessions` or `database-size`, with `granularity` (`5min`, `hourly`, `daily`) and `from`/`to`. Includes the coverage and whether the period is partial. |
| `GET /processes` | A page of processes, with filters and sorting. |
| `GET /history-collection` | Whether history is being recorded, the last sample and the retention of each granularity. |

The contract is written first, in [`openapi.yaml`](https://github.com/diashenrique/iris-history-monitor/blob/master/specs/001-api-v1/contracts/openapi.yaml), and every route has a test that fails when the response drifts from it. SQL uses bound parameters. No request value is executed or concatenated into SQL, and the server makes no call to a host taken from a request. Nothing is written to a global per request.

### Roles and one sign-in

Installing the module creates the resource `HistoryMonitorRead` and the role `HistoryMonitorViewer`. The role can use that resource, read `%DB_IRISSYS` (for `SYS.Stats.Dashboard`) and `SELECT` the eight `SYS.History` tables. Someone with only that role can use the monitor and cannot do anything else.

The role is checked in `OnPreDispatch`, which answers 403 as `problem+json`. The web application itself has no resource on purpose: with one, CSP refuses a user without the role before the class runs, with a 401 HTML page instead of a problem response.

The interface and the API share the cookie path `/historymonitor/`, so one sign-in covers both. Static files open no CSP session, so a small login class at `/historymonitor/` takes the user through the IRIS login form and back to the screen they asked for.

### Packaging with IPM

`module.xml` declares the web applications as `<WebApplication>` with a `<FileCopy>` for the interface files, since IPM deprecates `<CSPApplication>`, and states `AutheEnabled` explicitly (32, password only). An `<Invoke>` removes what version 1.x left behind, on install, upgrade and uninstall: the old classes, the compiled pages, the page folder and `^IRISMonitor`. It never deletes a namespace or a database.

### What I ran into on IRIS 2026.1

These are the things that cost me time, in case they cost you less.

- **`DispatchRequest` is final in `%CSP.REST`.** Overriding it fails with `ERROR #5272: Cannot change final 'Method'`. The class that forwards the old addresses does its work in `OnPreDispatch` and sets `pContinue = 0`.
- **An unauthenticated web application needs a database role to run your class.** With no role, the request got a 403 before the class ran. The forwarding application matches `:%DB_<namespace>`, which applies only to that application.
- **History tables are keyed in UTC.** `ZDATE` and `ZTIME` are UTC. Formatting such a value with `$ZDateTime(..., 7)` converts it from local time a second time. The API turns the keys into ISO 8601 UTC, and the browser does the local time. A fixture around a daylight-saving change is in the tests.
- **SQL on `%SYS.ProcessQuery` did not show the collector process to a viewer.** The process service opens each process of `^$JOB` as a `%SYS.ProcessQuery` object instead, which works for the viewer role. The Management Portal's own page for this needs `%Admin_Manage`.
- **The `intersystemsdc` image's entrypoint script.** Its after-start step failed in my tests and stopped IRIS. The Dockerfile and the CI start IRIS with `/tini -- /iris-main` directly.
- **A YAML detail.** An unquoted `off` in the OpenAPI document became the boolean `false` in the generated JSON, and my enum `[recording, stale, off]` rejected the value. The tests now check every state against the contract.
- **A fresh instance reports little at first.** `SYS.Stats.Dashboard.Sample()` returns some values only after the System Monitor's first cycle, about five minutes after start. For the first minutes, a few metrics show as unavailable ("no value reported"), which is true.

### History is not recorded by default

This one surprised me. On a standard IRIS install **no history collector is active**: no `%Monitor.System.HistoryPerf` or `%Monitor.System.HistorySys`, and no `%MONAPP` process. The History screen was empty. After a restart, the Application Monitor does not come back by itself, even with the classes active.

Retention is not the problem. The instance keeps 5-minute detail for 7 days and hourly summaries for 60 days, and it never purges daily summaries. So the monitor keeps no copies of its own. It reports the state, and the module never turns collection on by itself. An administrator does it:

```objectscript
do ##class(%Monitor.Manager).Activate("%Monitor.System.HistoryPerf")
do ##class(%Monitor.Manager).Activate("%Monitor.System.HistorySys")
do ##class(%Monitor.Manager).StartApp()
```

and, so that it resumes after a restart, adds an entry to `%ZSTART` in `%SYS`:

```objectscript
%ZSTART ; startup hooks
    quit
SYSTEM ; runs when the instance starts
    try { do ##class(%Monitor.Manager).StartApp() } catch {}
    quit
```

On a clean `intersystemsdc/iris-community:2026.1` container the first sample arrived after 308 seconds, and after a restart a new sample arrived after 310 seconds. The Docker image of this repository runs the same steps for itself; installing the module never does. CI compares seven collector and retention settings before and after an install and fails if one changed.

## Old addresses and upgrading

Version 2.0.0 removed the old pages. Their addresses forward (HTTP 302) to the new screens, for all of 2.x:

| Old address | Opens |
| --- | --- |
| `/csp/irismonitor/dashboard.csp` | Overview |
| `/csp/irismonitor/historylicense.csp`, `historycspsessions.csp`, `historydatabase.csp` | History on that metric |
| `/csp/irismonitor/systemprocesses.csp` | Processes |
| anything else under `/csp/irismonitor/` | Overview |

Install over 1.x as usual. The upgrade removes what the old pages left in the module's namespace.

## Kept honest by CI

The job names are in [`ci.yml`](https://github.com/diashenrique/iris-history-monitor/blob/master/.github/workflows/ci.yml):

- **`unit-tests`**: 141 `%UnitTest` methods, and the job fails if any class does not compile.
- **`ipm-install`**: installs the module with IPM 0.10.9 on a clean instance and checks what was created, and that the install changed none of the collector settings.
- **`ipm-upgrade`**: installs the previous version, opens an old page so it leaves its data, upgrades, and checks that nothing of the old pages is left.
- **`web`**: 159 interface tests, with accessibility checks, and fixtures validated against the OpenAPI contract.
- **`e2e`**: a browser against a real instance, in light, dark and a 360 px layout.
- **`docker`**: builds the image and waits for it to record history.

Merging to `master` bumps the module version and publishes a Docker image to the GitHub Container Registry; Open Exchange takes the new version from the repository.

## Try it

```
docker run -d --name iris-history-monitor -p 52773:52773 ghcr.io/diashenrique/iris-history-monitor:latest
```

Then open http://localhost:52773/historymonitor/index.html and sign in as `_SYSTEM` / `SYS` (change it before anyone else can reach the container). Or, on an instance of your own:

```objectscript
zpm "install iris-history-monitor"
```

The [README](https://github.com/diashenrique/iris-history-monitor#readme) has the rest, including "Turning on history collection".

## What is not done

- **No usability test with people yet.** The goal I set was to find every problem on the Overview within 5 seconds. The script for the test is in the repository, and it has not been run.
- **Accessibility is checked by tools, not audited.** Automated checks (axe) pass in both themes, and keyboard-only tests cover the main task of each screen. That is not a formal audit.
- **No browser notifications.** An old request asked for them ([#6](https://github.com/diashenrique/iris-history-monitor/issues/6)). They are feasible within limits (HTTPS or `localhost`, and an open tab), and they would need their own spec.

If you try it and something is unclear or broken, please open an issue.
