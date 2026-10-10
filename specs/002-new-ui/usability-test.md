# Moderated usability test: SC-001

For the owner to run (spec 002 task T060). This success criterion needs people; nothing in CI measures
it. SC-008 (new monitor clearer than the old pages) was withdrawn when 2.0.0 removed the old pages
(research R17).

## Who and what
- **Participants**: at least five people who look after IRIS instances (operators, administrators).
- **Instance**: a test instance with the module installed and a known
  problem in place (for example a backup that never ran, and licence use above 80%).
- **Accounts**: one account with the `HistoryMonitorViewer` role per participant, or one shared account.
- **Session**: about 20 minutes each, screen shared, think-aloud. Record time with a stopwatch.

## Prepare the instance
The Docker image gives a ready instance in a few minutes (from the repository root):

```shell
docker compose up -d --build
docker exec -it iris-history-monitor iris session IRIS -U %SYS
```

Then, in that terminal (one user per participant; choose the passwords):

```objectscript
do ##class(SYS.History.SysData).Demo(30)
do ##class(Security.Users).Create("p1", "HistoryMonitorViewer", "<password>")
halt
```

A new container already has a known problem: **Last backup** is *Never* (warning). Some dashboard
metrics also show as *Unavailable* on a container that has just started; participants should name the
warning and may name those. Sign each participant in before the session starts, so task 1 starts on the
Overview.

## Tasks
1. **Find the problems (SC-001).** Open `/historymonitor/index.html` (already signed in). Ask: "Which
   metrics need attention?" Start the stopwatch when the Overview appears; stop when the participant has
   named every metric that is not OK. **Pass: within 5 seconds.**
2. **History.** "How many licences were in use, at most, each day of the last 30 days?" (The participant
   should choose License usage, Daily, Last 30 days, and read the Maximum series.)
3. **Processes.** "Which process in %SYS used the most CPU? Open it." (Filter namespace `%SYS`, sort
   CPU time descending, open the first row.)

## Record
| Participant | Task 1 time (s) | Task 1 all found? | Task 2 done? | Task 3 done? | Notes |
| --- | --- | --- | --- | --- | --- |
| P1 | | | | | |
| P2 | | | | | |
| P3 | | | | | |
| P4 | | | | | |
| P5 | | | | | |

Put the results in `research.md` (a new entry) and open issues for anything participants stumbled on.
