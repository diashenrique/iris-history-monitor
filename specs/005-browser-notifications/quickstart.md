# Quickstart: verify spec 005

1. Open the monitor on `http://localhost:52773/historymonitor/index.html` (localhost is a secure context).
2. Header → **Notifications** → **Turn on**; allow in the browser prompt. The button says "on".
3. Open History (or hide the tab). Make a metric worse on the instance, for example fill the license use, or
   in a test use the e2e route that rewrites `/overview`. Within about 90 s one notification appears, naming
   the metric; clicking it brings the tab to the Overview.
4. Reload: still on. Turn off: no more notifications.
5. Open the monitor on a non-localhost HTTP address: the dialog says HTTPS is needed and there is no
   **Turn on**.
6. Automated: `npm test` (unit), `npx playwright test notifications.spec.ts` (e2e).
