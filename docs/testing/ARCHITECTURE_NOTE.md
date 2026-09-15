# FiveM Test Bridge — Architecture Discovery Note (Phase 1)

Verified against HEAD `725db77`, not from memory.

## 1. How sunset_core exposes player state
- `exports.sunset_core:GetCharacter(source)` → character row (id, name, money fields).
- `exports.sunset_core:GetMoney(source, account)` / `AddMoney` / `RemoveMoney(source, account, amount, reason)` — reason string is ledger-audited (`money_transactions`).
- `exports.sunset_core:GetPlayer(source)`, `GetPlayerDisplayName(source)`.
- Domain owners: `sunset_inventory:GetInventory/HasItem/AddItem/RemoveItem/CountItem`, `sunset_factions:GetWantedState/IsJailed/IsOnDuty`, `sunset_jobs` session table (`SunsetJobs_GetSession`), `sunset_licenses:HasLicense`, `sunset_admin:GetAdminLevel(source)`.
- **Rule honored:** the test agent READS through these exports; it never duplicates state.

## 2. How callbacks work
- Server: `exports.sunset_core:RegisterCallback(name, fn(source, ...))` → returns `result` or `nil, err`.
- Client: `Sunset.AwaitCallback(name, ...)` (promise-wrapped, 15s timeout) via `sunset_core/client/callbacks.lua`.
- Wire events: `sunset:server:triggerCallback` / `sunset:client:callbackResponse`.
- The test agent **reuses** this bus for server→client requests? No — the bus is client→server only. For server→client request/response the agent implements its own correlated RPC (`sunset:testagent:rpc` / `rpcResult`) because no such primitive exists in the repo.

## 3. How sessions are tracked
- `sunset_sessions` is the canonical session service (CreateSession/Transition/EndSession/SetEntity, `ListSessions`). Jobs/robbery/taxi mirror into it.
- Test agent reads session state via each domain's own exports (e.g. `SunsetJobs_GetSession` is a global in sunset_jobs server context — not exported; the agent instead calls domain callbacks/exports that exist, and for jobs uses the `sunset:jobs:status` callback).

## 4. How NUI communication works
- `exports.sunset_ui:Send(action, payload)` → `SendNUIMessage` → `app.js` switch.
- JS `post(name)` → `RegisterNUICallback` in `sunset_ui/client/nui_bridge.lua` → `TriggerEvent('sunset:nui:'..name)`.
- Focus: `exports.sunset_ui:SetFocus(focus, cursor, keepInput, owner)`; `GetFocusOwner()` and `IsOpen()` exports already exist.
- NUI errors already flow: JS `nuiError`/`nuiTrace` callbacks print `[NUI ERROR]` lines client-side.
- **Instrumentation plan:** a gated (convar `sv_sunset_nuidebug 1`) ring buffer inside sunset_ui recording last messages/focus transitions/callback names — additive, zero behavior change when off.

## 5. Commands / admin permissions
- No ACE-based admin; the repo uses `exports.sunset_admin:GetAdminLevel(source)` (levels 0-5). `add_ace group.admin command allow` exists but is unused by resources.
- Test-agent commands will require admin level ≥ configurable (default 5 = owner) **and** the convar kill switch.

## 6. Resource restart / deploy
- Restart: `RestartResource` server native (used by sunset_admin).
- Deploy: git push → `scripts/remote-deploy.ps1` → VPS docker compose. Container recreate wipes docker logs; persistent logs go to `/config`.

## 7. screenshot-basic
- **Not present.** A minimal, dependency-free `screenshot_basic` resource will be added (client `TakeHighQualityScreenshot` native → POSTs JPEG/PNG bytes to a local HTTP endpoint). It is only started when the test agent is enabled.

## 8. Existing HTTP/TCP/WebSocket mechanism
- `SetHttpHandler` is used nowhere in the repo → the FXServer HTTP endpoint (game port, `30120`) is free. This is the cleanest transport: no extra ports, no firewall changes, native to FXServer.
- **Chosen protocol:** HTTP POST JSON to `http://<fxserver>:30120/testagent/<route>` with `Authorization: Bearer <token>`, request/response correlated by `requestId` in the JSON body; async response supported by the HTTP handler. Chosen over WebSocket because: no ws server code in Lua stdlib, MCP side needs one simple `fetch`, and dev traffic is low-rate request/response.

## 9. What is reused vs new
| Reused | New |
|---|---|
| sunset_core exports (character/money/inventory reads) | `sunset_test_agent` resource (bridge + tools) |
| sunset_admin GetAdminLevel | `screenshot_basic` minimal resource |
| sunset_ui exports (IsOpen/GetFocusOwner) + gated instrumentation | server→client correlated RPC |
| sunset_factions/jobs/racing/robbery exports & callbacks | `tools/fivem-mcp` MCP server (TypeScript) |
| FXServer HTTP endpoint (SetHttpHandler) | scenario runner + assertions |
