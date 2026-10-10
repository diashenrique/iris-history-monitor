# Contract: old address forwarding

The web application `/csp/irismonitor` answers **every** request (any method, any path below the prefix,
any query string) with:

```
HTTP/1.1 302 Found
Location: <target>
Cache-Control: no-store
```

and no body that carries data. The target is chosen by the **last path segment**, compared without
case and without the query string:

| Old address (last segment) | Target | New screen |
| --- | --- | --- |
| `dashboard.csp` | `/historymonitor/index.html#/` | Overview |
| `historylicense.csp` | `/historymonitor/index.html#/history?metric=license` | History, license use |
| `historycspsessions.csp` | `/historymonitor/index.html#/history?metric=csp-sessions` | History, CSP sessions |
| `historydatabase.csp` | `/historymonitor/index.html#/history?metric=database-size` | History, database size |
| `systemprocesses.csp` | `/historymonitor/index.html#/processes` | Processes |
| anything else (incl. `dashboardapi.csp`, `/`, static files, `*.cls`) | `/historymonitor/index.html#/` | Overview |

Rules:
- The target is always one of the six fixed strings above. No part of the request is copied into it.
- No sign-in is needed (research R2). The new monitor asks for it and returns to the target route.
- No outbound request and no data read.
- In place for all of 2.x (FR-003).
