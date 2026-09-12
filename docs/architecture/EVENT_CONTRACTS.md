# EVENT_CONTRACTS — Client↔Server & NUI Communication Rules

## 1. The callback bus (primary contract)

**Flow:** client `Sunset.AwaitCallback(name, ...)` → `TriggerServerEvent('sunset:server:triggerCallback', name, requestId, ...)` → core validates + rate-limits → `Callbacks[name](source, ...)` → response `sunset:client:callbackResponse(requestId, {result, err})` → client promise resolves `(result, err)`.

**Contract rules:**
- `name`: string ≤80 chars, must be registered (`exports.sunset_core:RegisterCallback`). Unregistered → error response, never silent.
- `requestId`: number; client times out at 15s and resolves `(nil, 'timeout')` — callers MUST handle the error branch.
- Handler return convention: `return result` on success, `return nil, 'Human-readable reason'` on failure. Errors shown to players must state what failed and what to do (see RELEASE_GATE error-contract rule).
- Rate limits: 30/s per source global, 12/s per name default. Financial/expensive callbacks MUST be added to `EXPENSIVE_CALLBACK_LIMITS` in `sunset_core/server/main.lua` (auth=2/s, getInventory=4, trade:commit=2, dealership:purchase=2, propertyBuy/Rent=2, craftItem=3...).
- Handler `source` is ALWAYS the event source. Never accept a client-sent "source"/"src" field as identity.
- Any handler mutating money/items/assets must follow INVARIANTS M1-M7 / I1-I7.

**Registration checklist for a new callback:**
1. Register via `exports.sunset_core:RegisterCallback('domain:action', fn)` in the OWNING resource.
2. Validate: character loaded → ownership → permission → proximity/state → value ranges (`tonumber` + floor + min/max).
3. Idempotency: would a double-fire double-reward? If yes, add lock/status/unique-key.
4. Error strings: actionable, no nils, no internal names.
5. If financial: add to EXPENSIVE_CALLBACK_LIMITS + ensure ledger entry.

## 2. Raw net events (RegisterNetEvent) — restricted

Use ONLY for: fire-and-forget telemetry, or flows predating the bus. Every new one requires the same validation checklist. Current inventory (~47) is classified in `docs/audit/MASTER_AUDIT.md` Phase 2 Part B. High-risk ones carry `[AUDIT ...]` guards in code.

**Broadcast rules (server→client):**
- Targeted: money/inventory/phone/wanted data ONLY to the owning source.
- `-1` broadcasts allowed for: world state (turfs, cleanup plates, time/weather), non-sensitive notifications.
- Known leak (backlog P3-07): `sunsetWanted`/`sunsetJailed` statebags replicate to all clients. Do not extend this pattern; new sensitive state uses targeted events.

## 3. Server-internal events (TriggerEvent)

Cross-domain notifications use the contracts table in DOMAIN_OWNERSHIP.md. Rules:
- Namespaced: `sunset:<domain>:<verb>`.
- Payloads: validated on the receiving side (`tonumber`, type checks) — internal events are trusted transport, not trusted data.
- New cross-domain event → add row to the DOMAIN_OWNERSHIP contracts table in the same commit.

## 4. NUI contract

**Layers:** JS `fetch('https://sunset_ui/<callback>')` → `RegisterNUICallback` (bridge) → `TriggerEvent('sunset:nui:<name>')` (client-local) → feature resource → `Sunset.AwaitCallback` → server.

**Rules:**
- Every JS `post(...)` name MUST exist as a `forward()`/RegisterNUICallback in `sunset_ui/client/nui_bridge.lua`. Mismatch = silent 404 (battlepass bug, P8-07). The regression matrix includes a bridge-completeness check.
- Bridge callbacks answer `cb('ok')` immediately (no hangs). Blocking-response callbacks (licenseQuizAnswer) must call `cb` on EVERY branch.
- JS `post()` centrally swallows fetch rejections (P8-31).
- Every panel that calls `SetFocus(true)` MUST have: (a) a close callback that calls `SetFocus(false)`/`ReleaseFocusUnlessModal`, (b) an ESC entry in `panels.js` map, (c) a guaranteed-close path on failure branches.
- Modal exclusivity is enforced by `activateGameplayModal` (app.js); panels owning Lua flags receive `sunset:nui:modalSuperseded` and MUST clear their flag without touching focus.
- Player-controlled strings reaching `innerHTML` MUST pass an escape helper. New JS: reuse `esc()`/`escHtml()`/`Phone.escapeHtml` (strict variant).
- Correlation: NUI request/response pairs that can race (e.g., async data loads) must carry an id and the UI must drop stale ids. (Currently implemented for callbacks via requestId; panel-level correlation IDs are backlog P8-15 adjacent.)
- `playerInteractionClose` has a bridge-level failsafe (hide + ReleaseFocusUnlessModal) — owner handlers may rely on it but should still close their own state.

## 5. Error contract (player-facing)

Every denial must answer: WHAT failed, WHY, WHAT is missing, WHAT to do next.
- Good: `'You need $2,500 in bank for this ECU save.'`, `'Stand inside the entrance marker to enter.'`
- Forbidden: `'nil'`, `'Callback not found: sunset:x'` reaching players (bus returns a friendly wrapper), raw SQL errors, empty strings.
- The bus pcall wrapper converts handler exceptions into a generic-but-actionable message + console log with callback name — handlers should still pre-validate rather than rely on it.

## 6. Rate-limit / replay protection contract

| Action class | Limit | Replay protection |
|---|---|---|
| Reads (inventory, phone, scoreboard) | 3-4/s (EXPENSIVE list) | none needed |
| Writes non-financial | 12/s default | server state checks |
| Financial (purchase, trade commit, property) | 2/s | txn guards + locks + unique keys |
| Auth | 2/s + 5-fail lockout (exp. backoff to 5min) | token hash + device hash |
| Dumps (turfs sync, drops) | 1/5s via `RateLimit` export | — |
| Vehicle state sync | 30s tick, server-throttled 10s floor | monotonic value guards |
