# Moderated usability test: SC-001 and SC-008

For the owner to run (spec 002 task T060). These two success criteria need people; nothing in CI
measures them.

## Who and what
- **Participants**: at least five people who look after IRIS instances (operators, administrators).
- **Instance**: a test instance with the module installed, the interface switched on, and a known
  problem in place (for example a backup that never ran, and licence use above 80%).
- **Accounts**: one account with the `HistoryMonitorViewer` role per participant, or one shared account.
- **Session**: about 20 minutes each, screen shared, think-aloud. Record time with a stopwatch.

## Tasks
1. **Find the problems (SC-001).** Open `/historymonitor/index.html` (already signed in). Ask: "Which
   metrics need attention?" Start the stopwatch when the Overview appears; stop when the participant has
   named every metric that is not OK. **Pass: within 5 seconds.**
2. **History.** "How many licences were in use, at most, each day of the last 30 days?" (The participant
   should choose License usage, Daily, Last 30 days, and read the Maximum series.)
3. **Processes.** "Which process in %SYS used the most CPU? Open it." (Filter namespace `%SYS`, sort
   CPU time descending, open the first row.)
4. **Old pages, for comparison.** Repeat task 1 on the old dashboard (`/csp/irismonitor/dashboard.csp`).

## Question (SC-008)
After task 4, ask: "To find the state of the instance, is the new monitor clearer, about the same, or
less clear than the old pages?" **Pass: at least four of five say clearer.**

## Record
| Participant | Task 1 time (s) | Task 1 all found? | Task 2 done? | Task 3 done? | Clearer / same / less | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | | | | | | |
| P2 | | | | | | |
| P3 | | | | | | |
| P4 | | | | | | |
| P5 | | | | | | |

Put the results in `research.md` (a new entry) and open issues for anything participants stumbled on.
