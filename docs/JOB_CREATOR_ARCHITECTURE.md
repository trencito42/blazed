# SunsetMP — Universal Civilian Job Creator

## Phase 1 — Architecture Assessment

### Framework

| Area | Implementation |
|------|----------------|
| Framework | **Custom** (`sunset_core`) — not ESX/QBCore/QBox |
| Language | **Lua 5.4** (client/server), **vanilla JS** NUI |
| Database | **oxmysql** + MariaDB, migrations in `sql/` |
| Player ID | `accounts` + `characters`, `exports.sunset_core:GetCharacter(source)` |
| Economy | `exports.sunset_core:AddMoney` / `RemoveMoney` (cash + bank) |
| Inventory | `sunset_inventory` — `AddItem`, `TakeItem`, metadata |
| Callbacks | `exports.sunset_core:RegisterCallback` / `Sunset.AwaitCallback` |
| Notifications | `exports.sunset_ui:Notify` |
| Progress | `exports.sunset_ui:ProgressBar` |
| Admin | `sunset_admin` — `IsAdmin(source, level)` |
| UI | `sunset_ui` — sunset orange glass (`#ff9933`), Rajdhani, panels in `web/` |

### Job vs Faction

- **Civilian jobs**: `Sunset.CivilianJobs` (`jobs_civilian.lua`), hired at Job Center, `/work` shifts via `sunset_jobs`
- **Factions**: `sunset_factions` — LSPD, EMS, LSFD, **Taxi**, gangs, LSSI, etc.
- **Taxi is a faction** (`sunset_taxi`) — must NOT be created via Job Creator
- Job Creator targets **repeatable civilian work only**

### Existing Civilian Jobs (hardcoded)

| Job | Resource | Pattern |
|-----|----------|---------|
| trucker | `sunset_jobs` | Vehicle + trailer + route |
| garbage | `sunset_jobs` | Vehicle + collect + dump |
| courier | `sunset_jobs` | Hub + on-foot delivery loop |
| fisherman | `sunset_jobs` | Zones + minigame + sell |
| mechanic | `sunset_jobs` | Dispatch integration |

**Session engine** (`sunset_jobs/server/core.lua`):

- States: `IDLE` → `STARTING` → `ACTIVE` → `RETURNING` → terminal
- `SunsetJobs_StartSession`, `RequireSession`, `PayReward`, `AddJobXP`
- Progress in `job_progress` table (`sql/09-jobs.sql`)

**Gap**: Each job = separate Lua file + static `jobs_config.lua`. No DB definitions. Adding a job touches 8+ files.

### UI References (match these)

- **Fishing HUD**: `sunset_ui/web/js/fishing.js` — state classes, `{key}` / `/command` highlighting
- **Courier HUD**: `sunset_ui/web/js/courier.js` — counter, progress bar, key cap
- **Panels**: `panels.js`, `gameplay_glass.css`, orange accent `255, 153, 51`

### Integration Points

```
/work → sunset_jobs/client/commands.lua → STARTERS[jobId]
/hire → sunset:hireJob → Sunset.CivilianJobs[jobId]
/jobs → sunset:jobs:getPanelData
```

Job Creator **extends** these without replacing factions or inventory.

---

## Phase 2 — Implementation Plan

### Resource: `sunset_jobcreator`

```
sunset_jobcreator/
  shared/schema.lua      — stage types, validation, defaults
  shared/locale.lua      — user-facing strings
  server/storage.lua     — SQL CRUD, cache, publish
  server/sessions.lua    — authoritative job sessions (separate from sunset_jobs shift when needed)
  server/stages.lua      — built-in stage type registry + handlers
  server/engine.lua      — stage transitions, conditions, variables
  server/creator.lua     — admin CRUD callbacks
  server/runtime.lua     — player interact / reward validation
  server/templates.lua   — seed templates on first run
  server/main.lua        — bootstrap, exports, events
  client/placement.lua   — in-world point placement
  client/runtime.lua     — markers, HUD sync, interact
  client/creator.lua     — admin panel bridge
  client/main.lua
```

NUI in `sunset_ui` (existing pattern):

- `web/js/job_creator.js` + `css/job_creator.css` — admin editor
- `web/js/job_shift.js` + `css/job_shift.css` — player HUD (fishing/courier style)

### Job Definition Schema (JSON in `jc_jobs.definition`)

```json
{
  "startStage": "hub",
  "timeoutSec": 1800,
  "salaryGrade": 0,
  "locations": { "hub": { "x", "y", "z", "radius", "label", "blip" } },
  "pools": { "deliveries": [ { "x", "y", "z", "label", "weight" } ] },
  "variables": { "packagesTotal": 4, "packagesDone": 0 },
  "stages": [
    {
      "id": "hub",
      "type": "zone_interact",
      "label": "Load package",
      "location": "hub",
      "message": "Press {key} to load a package",
      "onSuccess": "route",
      "actions": [{ "type": "increment", "var": "packagesLoaded" }]
    }
  ],
  "progression": { "xpPerTask": 18, "payPerTask": 75 },
  "ui": { "title": "Courier", "icon": "package" }
}
```

### Built-in Stage Types (v1)

| Type | Purpose |
|------|---------|
| `objective` | Set HUD message + waypoint (no completion) |
| `zone_interact` | Must be in zone + E, server validates coords |
| `goto_zone` | Auto-advance when entering zone |
| `scale_from_level` | Set variable from job level (base + perLevel, capped) |
| `pick_random` | Pick from pool → variable |
| `set_variable` | Set/increment/compare variables |
| `branch` | Conditional next stage |
| `give_reward` | Money + job XP via `exports.sunset_jobs` (supports `payVar`) |
| `spawn_vehicle` | Spawn job vehicle, track netId |
| `delete_vehicle` | Cleanup spawned vehicle |
| `create_blip` / `remove_blip` | Client blip helpers |
| `timer` | Fail or branch on timeout |
| `complete` | End session success |
| `fail` | End session failure |

Custom types: `exports('RegisterStageType', ...)` — extension API in `server/stages.lua`.

### Security

- All rewards server-side after session + stage + coords validation
- Rate limit interact events (500ms)
- Session token per shift; stage index cannot skip forward from client
- No Lua in SQL; JSON schema validation on save/publish
- Admin-only creator (`IsAdmin` level 3+)

### Backwards Compatibility

- Existing hardcoded jobs (`trucker`, `courier`, etc.) **unchanged**
- Creator jobs use id prefix `jc_` (e.g. `jc_courier_custom`)
- `/work` checks `exports.sunset_jobcreator:IsCreatorJob(jobId)` first
- Hire list merges published creator jobs into Job Center payload

### Templates (seeded, config-only)

1. `jc_tpl_courier` — hub + random deliveries + level-scaled package count
2. `jc_tpl_route` — randomized trucking routes (pickup → delivery → pay)
3. `jc_tpl_gather` — fishing spots + sell point (fisherman-lite)
4. `jc_tpl_garbage` — randomized bin route + depot unload bonus

Legacy jobs migrate later via import JSON, not by deleting Lua.

---

## Commands

| Command | Who | Action |
|---------|-----|--------|
| `/jobcreator` | Admin 3+ | Open Job Creator panel |
| `/work` | Player | Starts creator job if employed on `jc_*` job |
| `/jcdebug` | Admin 3+ | Inspect active session / skip stage |

## Exports

```lua
exports.sunset_jobcreator:IsCreatorJob(jobId)
exports.sunset_jobcreator:GetJobDefinition(jobId)
exports.sunset_jobcreator:StartJob(source, jobId)
exports.sunset_jobcreator:CancelJob(source)
exports.sunset_jobcreator:GetActiveJob(source)
exports.sunset_jobcreator:RegisterStageType(name, def)
```

## Events

```
sunset:jobcreator:jobStarted
sunset:jobcreator:stageCompleted
sunset:jobcreator:jobCompleted
sunset:jobcreator:jobFailed
```

---

## Status (v0.2)

- [x] Full stage catalog (vehicles, NPCs, items, party, minigames, progress)
- [x] Drag-and-drop stage editor (visual form + reorder)
- [x] Templates: courier, trucker, fisherman, garbage, miner, lumberjack, construction, warehouse, farmer
- [x] Vehicle spawn + trailer attach + return/delete (trucker + garbage)
- [x] Legacy job migration (`trucker`→`jc_tpl_route`, etc.) with XP on legacy id
- [x] Skill check + progress bar stages
- [ ] Full co-op party sessions (party_gate counts nearby coworkers only)
- [ ] Migrate/remove legacy Lua job loops after live validation
