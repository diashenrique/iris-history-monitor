# API v1 changes for spec 002

Applied to `specs/001-api-v1/contracts/openapi.yaml` (and the generated `openapi.json`) before any code,
per constitution III. Both changes are additive for clients written against v1, so the version path
stays `v1`; `info.version` goes from 1.0.0 to 1.1.0.

## 1. Server address (FR-025, research R3)
```yaml
servers:
  - url: /historymonitor/api/v1      # was /api/historymonitor/v1
```
The routes, parameters, responses and the 401/403 behaviour are unchanged. The web application moves in
`module.xml`; the session cookie path of both web applications becomes `/historymonitor/`.

## 2. New route `GET /settings` (FR-002, research R4)
```yaml
paths:
  /settings:
    get:
      operationId: getSettings
      summary: Interface settings any monitor viewer may read
      responses:
        '200':
          description: Settings
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Settings' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '403': { $ref: '#/components/responses/Problem' }
components:
  schemas:
    Settings:
      type: object
      required: [interfaceEnabled]
      properties:
        interfaceEnabled: { type: boolean }
```
No parameters. Read-only: there is no route that changes a setting; an administrator uses
`util.Settings.SetInterfaceEnabled(1)` in a terminal.

## Tests that must change with it
- `ContractCoverageTest` (new operation must have a route, a contract test class and an HTTP call).
- `HttpAuthTest` (base URL and routes list; `/settings` for viewer, no role, no credentials).
- A new `SettingsTest` (shape against the contract, default false, only an administrator can change it).
- The CI install check (new web application addresses and cookie path).
