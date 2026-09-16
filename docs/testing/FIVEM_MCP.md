# FiveM Runtime Testing Bridge (MCP)

Real runtime testing for AI coding agents against a LIVE FXServer + connected
FiveM test client. No mocks: every tool reads/writes the actual game runtime
through authoritative domain owners.

```
Claude Code ──MCP(stdio)──► tools/fivem-mcp ──HTTP+bearer──► sunset_test_agent (FXServer)
                                                                  │
                                                                  ├── server tools (state, DB reads, resources)
                                                                  └── correlated RPC ──► test client
                                                                        (coords, entities, NUI, screenshot, logs)
```

## Why HTTP on the game port

FXServer has a built-in HTTP endpoint (`SetHttpHandler`) on the game port — no
extra ports, no firewall changes, works through SSH tunnels
(`ssh -L 30120:127.0.0.1:30120 root@vps`). Request/response is correlated by
`requestId`; auth is a bearer token compared in constant time; every call has a
timeout; errors are structured `{code, message, retryable}`. WebSocket was
rejected: no ws server in Lua stdlib, and dev traffic is low-rate request/response.

## Security model

| Layer | Control |
|---|---|
| Kill switch | `setr sunset_test_agent_enabled true` — default OFF; every HTTP route 403s without it |
| Bearer token | `set sunset_test_agent_token <random>` — constant-time compare; missing token = locked bridge |
| Test player | in-game `/testagent register` requires sunset_admin level ≥ 5; optional license allowlist |
| No eval | NO executeLua / eval / shell / raw SQL writes / arbitrary events anywhere |
| Callbacks | `invoke_callback` only fires a fixed allowlist (status reads + safe leaves), enforced server- AND client-side |
| Entities | delete only test-tagged entities; spawn tags via state bag |
| Resources | only `sunset_*`; protected: sunset_core, sunset_sessions, oxmysql, sunset_test_agent, webadmin, monitor |
| Screenshots | client → HTTP POST (bearer) → memory store, 120s TTL, never on disk |
| DB | read-only domain tools (`get_character_db_state`, `get_robbery_db_state`, `get_vehicle_ownership_state`) |

**Production safety checklist:** `sunset_test_agent` NOT ensured in `server.cfg.template`
(it isn't), kill switch off, token unset → the resource boots inert and the HTTP
routes answer 403. Even fully enabled, worst case is admin-level game actions —
the same power `/testagent`-registered staff already have.

## Install & run (dev box)

1. **server.cfg (dev only):**
   ```cfg
   ensure sunset_test_agent
   setr sunset_test_agent_enabled true
   set sunset_test_agent_token <random 64 chars>
   setr sv_sunset_nuidebug 1        # full NUI instrumentation (optional but recommended)
   ```
2. **screenshot_basic** (external, only needed for screenshots):
   clone https://github.com/citizenfx/screenshot-basic into `resources/` and build it
   (`npm i && npm run build` inside it). The agent starts it automatically when enabled.
3. Start FXServer, connect your FiveM client, log in with an **admin level 5** character.
4. In-game: `/testagent register` → you are THE test player.
5. **MCP server:**
   ```powershell
   cd tools\fivem-mcp
   npm install
   npm run build
   $env:FIVEM_TEST_TOKEN = "<same token>"
   # remote VPS: first  ssh -L 30120:127.0.0.1:30120 root@193.33.167.216
   npm start   # or let Claude Code spawn it (below)
   ```

## Connecting Claude Code

`.mcp.json` (project root) or `claude mcp add`:

```json
{
  "mcpServers": {
    "fivem": {
      "command": "node",
      "args": ["C:/Users/stefan/Documents/sunsetmp/tools/fivem-mcp/dist/index.js"],
      "env": {
        "FIVEM_TEST_HOST": "127.0.0.1",
        "FIVEM_TEST_PORT": "30120",
        "FIVEM_TEST_TOKEN": "${FIVEM_TEST_TOKEN}"
      }
    }
  }
}
```

Keep the token in your shell environment, never in committed files.

## Tools (47)

**Core:** `fivem_health` `fivem_wait_for` `fivem_assert` `fivem_list_scenarios` `fivem_run_scenario`
**Player:** `fivem_get_players` `fivem_get_player_state` `fivem_get_player_coords` `fivem_teleport` `fivem_set_health` `fivem_get_vehicle_state` `fivem_get_player_inventory` `fivem_get_player_money` `fivem_get_player_status` `fivem_invoke_callback` `fivem_press_control`
**World:** `fivem_get_nearby_entities` `fivem_get_nearby_objects` `fivem_get_nearby_vehicles` `fivem_inspect_entity` `fivem_find_object_by_model` `fivem_hash_model` `fivem_spawn_test_vehicle` `fivem_delete_test_entity` `fivem_cleanup_test_entities`
**NUI:** `fivem_get_nui_state` `fivem_get_nui_focus` `fivem_get_open_panels` `fivem_get_nui_history` `fivem_get_nui_errors`
**Media:** `fivem_take_screenshot` (returns real JPEG image content; requires screenshot_basic — optional)
**Resources/logs:** `fivem_get_resource_state` `fivem_list_resources` `fivem_restart_resource` `fivem_start_resource` `fivem_stop_resource` `fivem_get_server_logs` `fivem_get_recent_errors` `fivem_get_client_logs` `fivem_clear_client_logs`
**Domains:** `fivem_get_robbery_state` `fivem_get_race_state` `fivem_get_job_state` `fivem_get_drug_state` `fivem_get_wanted_state` `fivem_get_vehicles_db` `fivem_get_robbery_db`

### Mutation-target policy (security)

- **READ tools** may target any connected player by explicit serverId.
- **MUTATION tools** (teleport, heading, vitals, spawn/delete entity, control
  actions, semantic interactions, screenshots, callbacks) may target ONLY the
  registered test player. Any other target → `OPERATION_NOT_ALLOWED`.
  Enforced server-side by `TestAgentAuth.resolveMutationTarget`.
- One test player at a time; a second `/testagent register` while one is
  active is REFUSED (must `/testagent reset` first). Disconnect clears
  registration. Licenses are masked in logs.

### Resource action semantics

`restart/start/stop_resource` return `{requestedAction, immediateState,
finalStatePending}` — `GetResourceState` right after RestartResource is NOT
final. Use `fivem_wait_for resource_state` or the `resource_started` assertion
with `timeoutMs` (the scenario runner does this).

Protected (refused): sunset_test_agent, sunset_sessions, sunset_core, oxmysql,
sunset_auth, sunset_characters, webadmin, monitor. Deliberately NOT protected:
sunset_inventory, sunset_admin (restarting them is a legitimate test and
cannot corrupt persistent data). Only `sunset_*` may be touched at all.

### Honest input semantics + capability matrix

FiveM **cannot inject physical control presses** (no `SetControlNormal` native
exists). `fivem_health` reports this explicitly so no agent can over-claim:

```jsonc
"capabilities": {
  "physicalInputInjection": false,   // ALWAYS false — runtime limitation
  "semanticInteraction": true,       // allowlisted event/callback bypass
  "screenshots": <bool>,             // true only if screenshot_basic started
  "nuiInstrumentation": <bool>,      // true only if sv_sunset_nuidebug 1
  "entityScans": <bool>              // true only if a test client answered ping
}
```

**Consequence (documented limitation):** this bridge CANNOT prove the full
`marker → IsControlJustReleased(38) → handler fired` interaction chain. Bugs
that live specifically in the input layer (e.g. the historical drugs
`openDrugsUI` forward-reference nil) are reachable only via `interact_semantic`
(fires the same server event the marker would) — which exercises the server
path but NOT the client marker/E-press code. Treat "E interaction works" as
**REQUIRES MANUAL IN-GAME TEST**, never as bridge-proven.

| Capability | Status |
|---|---|
| Read player/world/entity/NUI state | LIVE-VERIFIED via bridge |
| Teleport, vitals, heading | LIVE (mutation, test-player only) |
| Spawn/delete tagged vehicles | LIVE (tag policy enforced) |
| Semantic interaction (allowlisted events) | LIVE, marked `bypass: true` |
| Physical key injection | **UNSUPPORTED** (FiveM limitation) |
| Callback invocation (allowlisted) | LIVE |
| Screenshots | LIVE **only if** screenshot_basic installed; else clean `SCREENSHOT_FAILED` |
| NUI message/callback/error history | LIVE **only if** `sv_sunset_nuidebug 1`; else focus-only fallback |
| Resource restart/start/stop | LIVE (guarded, `finalStatePending`) |
| DB reads (character/robbery/vehicles) | LIVE (read-only, domain-scoped) |
| DB writes / eval / arbitrary events | **NEVER** (by design) |

`fivem_press_control`:
- returns `OPERATION_NOT_ALLOWED` (physical injection unavailable), OR
- if `semanticEvent` is provided and allowlisted, fires it and returns
  `{ fired, bypass: true }` (same path as the `interact_semantic` bridge tool).

It NEVER claims a real E press happened.

### Error codes

`TEST_PLAYER_NOT_CONNECTED` `RESOURCE_NOT_STARTED` `TIMEOUT` `ENTITY_NOT_FOUND`
`UNAUTHORIZED` `SCREENSHOT_FAILED` `NUI_UNAVAILABLE` `INVALID_ARGUMENT`
`OPERATION_NOT_ALLOWED` `ASSERTION_FAILED` `BRIDGE_UNREACHABLE` `INTERNAL`

## Scenarios

`fivem_run_scenario` runs deterministic step lists (tool → wait → assert, fail-fast,
per-step timings). Built-in:

| id | covers |
|---|---|
| `player_connect_smoke` | bridge + players + core reads |
| `teleport_and_state` | teleport → position assert |
| `vehicle_spawn_and_network` | tagged spawn → networked **observed** (assert, not inferred) → cleanup deletes all tagged entities |
| `nui_inspection_smoke` | NUI focus/history/js-errors — INSPECTION ONLY, renamed from nui_open_close because it does NOT open/close panels (that needs input injection) |
| `callback_roundtrip` | every allowlisted status callback |
| `screenshot_test` | capture → store pipeline; FAILS honestly if screenshot_basic missing |
| `resource_restart_test` | restart sunset_drugs → **waits for actual started state** → callbacks alive |
| `mcp_bridge_self_test` | full bridge: health, tp+assert, NUI, inventory/money, spawn+networked, logs, **protected-restart rejection**, **unknown-tool rejection**, cleanup-always |
| `fleeca_robbery` | DOMAIN: vault prop lookup (`v_ilev_gb_vauldoor` found/heading), semantic start (**marked BYPASS**), HACKING stage assert, vault-closed-while-hacking, doorSync. Does NOT complete the hack (server-owned circuit) |

Cleanup steps run **even when the scenario fails** (step numbers 1000+ in the
report; cleanup failure is recorded but never flips the verdict).

The Fleeca scenario deliberately does NOT auto-solve the hack minigame (the
circuit solution is server-secret by design). It gives the agent everything
needed to answer the vault questions: which prop is nearby, its heading before
vs during, collision state, whether `doorSync` says open while the world heading
says closed. Full hack completion is a manual step (or a future dev-only
hack-solve export — flagged as a limitation below).

### Adding a domain adapter

1. Server: `sunset_test_agent/server/domains.lua` → `TestAgentTools.registerDomain('get_x_state', {...})`, reading ONLY through the domain owner's exports.
2. Domain resource: add a read-only `GetTestSnapshot(source)` export if none exists (see sunset_robbery/sessions.lua, sunset_racing, sunset_jobs).
3. MCP: register a thin wrapper tool in `src/tools/*.ts` and add asserts/waits as needed.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `bridge: unreachable` in health | FXServer down, wrong port, or no SSH tunnel |
| `UNAUTHORIZED` | token mismatch between env and convar |
| `OPERATION_NOT_ALLOWED … kill switch` | `setr sunset_test_agent_enabled true` missing |
| `TEST_PLAYER_NOT_CONNECTED` | run `/testagent register` in-game (admin 5+) |
| `SCREENSHOT_FAILED` | screenshot_basic not installed/not started |
| NUI state `instrumented: false` | `setr sv_sunset_nuidebug 1` then restart sunset_ui |
| tools list empty in Claude | MCP server crashed at boot — check its stderr (token env missing is non-fatal; syntax errors are fatal) |

## Verification status of this document's claims

- **STATICALLY VERIFIED**: tsc build, MCP stdio handshake, tools/list (46 tools),
  health graceful-degradation without FiveM, Lua syntax/forward-ref/audit scripts.
- **REQUIRES CONNECTED CLIENT**: every in-game behavior (teleport, screenshots,
  entity scans, NUI instrumentation, scenarios).
