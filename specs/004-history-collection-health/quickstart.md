# Quickstart: verify spec 004

1. **Off** (standard instance, collector never turned on): `GET /historymonitor/api/v1/history-collection`
   returns `state: off`, `running: false`. History shows the "not being recorded" notice with the link to
   the README section. With demo data loaded it shows the data and the "stopped" notice.
2. **Turn on** (README "Turning on history collection", as an administrator in `%SYS`). Within 10
   minutes `state` is `recording`, and the notice is gone after one refresh.
3. **Restart** the instance (with the README `%ZSTART` step done). Within 10 minutes `running` is true
   and a new sample arrives.
4. **Retention**: `do ##class(SYS.History.Hourly).SetPurge(90)`; the route and the History label show
   90 days. Put it back to 60.
5. **Unchanged by the module**: CI `ipm-install` compares the collector and retention settings before and
   after `load` (`InstallCheck`).
6. **Image**: `docker compose up -d --build`; the route reports `recording` within 10 minutes.
