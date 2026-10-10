# Quickstart: verify spec 003

Prerequisites: Docker, the repository, `gh`.

1. **Upgrade from 1.9.x** (the main path, US2):
   - Start IRIS 2026.1 with IPM 0.10.9 and the repository mounted at `/home/irisowner/repo`. Check out
     commit `900a421` (1.9.3, on master; never released on its own) and `load` it.
   - Open `/csp/irismonitor/historylicense.csp` once, so `^IRISMonitor` exists.
   - Check out `003-retire-old-pages` and `load` again.
   - Expect: `ci.InstallCheck` prints `INSTALL_CHECK=OK`. That covers no old classes, no compiled
     pages, no `${cspdir}irismonitor/`, no `^IRISMonitor`, no switch value, the forwarding app present,
     and the API and interface apps unchanged.
2. **Fresh install**: the CI `ipm-install` job; same `InstallCheck`.
3. **Forwarding (US1)**: `curl -si http://localhost:52773/csp/irismonitor/historylicense.csp` returns
   `302` with `Location: /historymonitor/index.html#/history?metric=license`. Repeat for every row of
   [contracts/forwarding.md](contracts/forwarding.md). The e2e `forwarding.spec.ts` follows each one in a
   browser to the matching screen, signed in and signed out.
4. **Interface (US3)**: `npm test` and the e2e suite pass. No screen offers the old pages, and `GET
   /historymonitor/api/v1/settings` returns `{"interfaceEnabled":true}`.
5. **Image**: `docker compose up -d --build`; the CI `docker` job checks the forwarding instead of the
   old banner.
6. **Uninstall (US2-5)**: `zpm "uninstall iris-history-monitor"`. Expect no `diashenrique.historymonitor.*`
   class, no `/csp/irismonitor`, `/historymonitor` or `/historymonitor/api/v1` application, and no
   leftovers from the table in [data-model.md](data-model.md).
