# Data model: Browser notifications

Nothing on the server. In the browser:

| Item | Where | Values |
| --- | --- | --- |
| Preference | `localStorage` `hm.notifications` | `on` / absent (off) |
| Last notified, per metric | `localStorage` `hm.notified.<metric>` | `<state>|<epoch ms>`; a repeat within 10 minutes is dropped (research R5) |
| Last known states | memory of the open tab | `Map<metric, Status>`; replaced on each successful reading |
| Last interaction | memory of the open tab | epoch ms; idle when older than 8 hours (research R6) |

Transition: `{ metric, from: Status, to: 'warning' | 'critical' }`, produced by `worseTransitions(before, metrics)`.
