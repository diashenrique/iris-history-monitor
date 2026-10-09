# Quickstart: New Monitor Interface

How to check the feature by hand once it is implemented. The automated version of these steps is the
end-to-end suite (research R13). Replace host and credentials.

## Prerequisites
- An IRIS instance with the module installed by IPM (`zpm "install iris-history-monitor"` or `load` from
  the repository). No Node is needed on the server (research R12).
- A user holding `HistoryMonitorViewer`, a user without it, and an administrator.
- Some history: on a test instance, `do ##class(SYS.History.SysData).Demo(90)` in `%SYS`.

## Steps
1. **Switch off by default** (FR-002): open `http://host:52773/historymonitor/` and sign in as the viewer.
   Expect the "not enabled" page with a link to the old pages.
2. **Turn it on**: as the administrator, `do ##class(diashenrique.historymonitor.util.Settings).SetInterfaceEnabled(1)`.
   As the viewer, `do ##class(...).SetInterfaceEnabled(1)` must fail. Reload: the Overview appears.
3. **Overview** (US1): 18 metrics, non-ok first, each status with icon and label; the "last updated" time
   moves every 10 s; numeric metrics grow a trend. Stop the web server briefly: figures stay and are marked
   out of date; they recover when it is back.
4. **History** (US2): `#/history?metric=license&granularity=hourly&preset=90d`. Chart and table agree;
   times are in your zone with its name; copy the address into a new tab and get the same view. Try
   `database-size` and pick two databases. Try a custom range with no data and read the "no data" message.
5. **Processes** (US3): filter by namespace `%SYS`, sort by CPU descending, open one process, export CSV.
6. **Sign-in** (US4): wait for the session to expire (or end it), act on any screen: you are asked to sign
   in and come back to the same view. Sign in as the user without the role: "no access" naming
   `HistoryMonitorViewer`.
7. **Language, appearance, size** (US5): switch to pt-BR and es (dates and numbers change too), dark and
   light, keyboard only, and a 360-pixel-wide window.
8. **One source** (SC-006): in the browser's network panel, every request goes to `/historymonitor/`.
9. **Old pages** (FR-024, after all screens): the Management Portal favourite opens `/historymonitor/`;
   the old pages show the obsolete banner and still answer at `/csp/irismonitor/...`.
