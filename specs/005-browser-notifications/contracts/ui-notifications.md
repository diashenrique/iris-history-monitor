# Contract: notifications control and texts

## Header button
A button labeled **Notifications** (with a bell icon) whose accessible name includes the state:
"Notifications: on", "Notifications: off", "Notifications: paused", "Notifications: unavailable".
It opens a dialog titled "Notifications".

## Dialog, by state
| State | Text | Action |
| --- | --- | --- |
| off (permission default or granted) | "Get a desktop notification when a metric gets worse, while the monitor stays open in a tab. Hidden tabs are checked about once a minute." | **Turn on** (asks the browser when needed) |
| on | same text + "Notifications are on in this browser." | **Turn off** |
| paused | "Notifications paused after 8 hours without activity. They resume when you use the monitor." | **Turn off** |
| denied | "Your browser blocks notifications for this site. Allow them in the browser's site settings, then turn them on here." | none |
| insecure | "Notifications need a secure address (HTTPS) or this computer (localhost). This monitor is open on an address that is neither." | none |
| unsupported | "This browser does not support notifications." | none |

## Notification texts
- Title: "IRIS History Monitor".
- One transition: body "{metric} is now {state}" (the existing `overview.statusChanged` string).
- Several: body "{count} metrics got worse: {metric} ({state}), …".
- Paused: body "Notifications paused after 8 hours without activity."
- Click: focus the monitor's tab and open the Overview.

All texts in en, pt-BR and es.
