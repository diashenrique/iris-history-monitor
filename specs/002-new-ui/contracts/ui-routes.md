# Interface routes and address contract

The interface is served at `/historymonitor/` and uses hash routes (research R6). These addresses are a
public contract: bookmarks and shared links depend on them (FR-013). Unknown or invalid values fall back
to the defaults shown here and show a short notice; they never cause an error page.

| Route | Screen | Query parameters (all optional) | Defaults |
| --- | --- | --- | --- |
| `#/` | Overview | `paused=1` | live |
| `#/history` | History | `metric`, `granularity`, `preset` or `from`+`to` (UTC, ISO 8601), `db` (repeatable) | `metric=license`, `granularity=hourly`, `preset=7d` |
| `#/processes` | Processes | `namespace`, `user`, `state`, `q`, `sort`, `page`, `pageSize` | `sort=job`, `page=1`, `pageSize=50` |
| `#/processes/:pid` | Process detail (over the list) | as above | |

Screens outside the routes (not addressable): `not-enabled` (switch off), `no-access` (403),
`loading`, `error`.

## Accessibility contract for every route
- Each route sets the document title (`<screen> · IRIS History Monitor`) and moves focus to the main heading.
- A "skip to content" link is the first focusable element.
- Live regions announce Overview status changes (polite) and errors (assertive), not every refresh.
