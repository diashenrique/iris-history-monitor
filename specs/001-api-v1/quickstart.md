# Quickstart: Versioned Read API (v1)

Use this to check the feature by hand once it is implemented. Replace host and credentials.

1. Install the module on an IRIS instance and give a test user the role created by the install.
2. Overview: `curl -u user:pass http://localhost:52773/api/historymonitor/v1/overview` returns a snapshot
   with every metric named in `data-model.md`, each with a status.
3. History: `curl -u user:pass "http://localhost:52773/api/historymonitor/v1/history/license?granularity=daily&from=2026-07-09T00:00:00Z&to=2026-10-07T00:00:00Z"`
   returns ascending points and a `coverage` block. Compare three points with the System Monitor tables.
4. Processes: `curl -u user:pass "http://localhost:52773/api/historymonitor/v1/processes?namespace=USER&pageSize=20"`
   returns at most 20 items and a `total`.
5. Errors: repeat step 3 with `from` after `to`; expect `400` and `application/problem+json`.
   Repeat step 2 without credentials; expect `401`. Repeat with a user lacking the role; expect `403`.
6. Pages: open the six existing pages and compare their figures with the values from steps 2 to 4.
7. Old URLs: request one of the old `...cls?method=...` URLs; it still answers.
