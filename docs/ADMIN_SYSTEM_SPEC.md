# ADMIN & HELPER SYSTEM — Full Specification

> Status: SPEC (no code written yet — hand off to implementation)
> Scope: `sunset_admin` (commands, permissions, sanctions, broadcasts) + new helper tier
> Source of truth for current state: `resources/[sunset]/sunset_admin/`, `sunset_admintools/`, `sunset_factions/server/police.lua` (jail), `sunset_core` (CommandReply / SendDiscordLog)

---

## 1. CURRENT STATE AUDIT

### 1.1 Permission model (as-is)

`sunset_admin/shared/config.lua` defines 5 levels:

| Level | Title | Notes |
|---|---|---|
| 1 | Helper | Only `/ar`, `/cr`, `/reports` (ticket handling) today |
| 2 | Moderator | kick, tp/bring, heal/revive/arespawn, dv, fix, coords, checkpoints, astats |
| 3 | Admin | ban/unban, car, noclip, god, announce, sett/setw, give*, set* |
| 4 | Super Admin | (nothing exclusive — same gates as 3) |
| 5 | Owner | `/setadmin` only |

Admin identity: `admins` table (license → level) + `accounts.admin_level` (max of both), loaded in `sunset_admin/server/main.lua::loadAdmin`. Console (`sunset_setowner`) bootstraps the first owner.

Ban check: `playerConnecting` deferral against `bans` table (`license`, `expires_at` supported but `/ban` never sets it → all bans permanent).

### 1.2 Commands that EXIST today (verified in source)

**Moderation:** `/kick [id] [reason]` · `/ban [id] [reason]` · `/unban [id|license:xxx]` · `/report [id] [reason]` · `/helpme [question]` · `/ar [ticket]` · `/cr [ticket] [reply]` · `/reports`
**Teleport:** `/tp [id|x y z]` (accepts `vector3(...)` paste) · `/bring [id]` · `/setcp` `/delcp` `/gotocp` `/gotoloc` (saved checkpoints + world location list) · `/tpwp` (waypoint, client-side) · `/coords`
**Medical:** `/heal [id]` · `/revive [id]` (both also honor EMS faction perm) · `/arespawn [id] | [id] hospital | [id] menu`
**Vehicles:** `/car [model]` · `/dv` · `/fix [id]` (+aliases `arepaircar/arepair/fixcar`) · `/givecar` (sunset_vehicles) · `/speed [0.5–10|off]`
**Stats:** `/astats [id]` · `/setstat [id] [stat] [value]` + 15 aliases (`/setcash` `/setbank` `/setlevel` `/setrp` `/setrob` `/setpremium` `/setsc` `/sethunger` `/setthirst` `/setstress` `/setpaydays` `/setplaytime` …) · `/setjobstat [id] [job] [xp|level|tasks|earned] [v]` — all audited into `admin_stat_audit`
**Items/weapons:** `/giveitem [id] [item] [count]` · `/givegun [id] [weapon] [ammo]`
**Management:** `/setjob` `/setfaction` (sunset_jobs) · `/setleader` `/removeleader` (sunset_factions) · `/givelicense` `/agivelicense` `/revokelicense` (sunset_licenses) · `/setadmin [id|username] [level]` · `/dealershipadmin` · `/bizadmin` · `/ahouseedit` `acreatehouse` (properties)
**World:** `/sett [h] [m]` · `/setw [WEATHER|RESET]` · `/announce [msg]` (chat + UI banner) · `/noclip` · `/god`
**Diagnostics:** `/inspect` `/cinematic` `/blzresmon [sec]` `/sweeporphans [force]` (sunset_admintools, level 3+)
**Turf admin:** `/turflist` `/gototurf` `/forceturf` `/stopwar` `/resetturfcd` (sunset_turfs)
**Misc:** `/robdebug` · `/integrity` `/smoketest` `/testall` (sunset_testdriver) · `/hudexport`

### 1.3 GAPS (verified missing — no handler anywhere in `resources/[sunset]`)

| # | Missing | Impact |
|---|---|---|
| G1 | `/spectate` | Cannot watch suspected cheaters invisibly |
| G2 | `/freeze` | Cannot immobilize a player mid-cheat/combat-log attempt |
| G3 | `/slap` | No light physical sanction / anti-grief tool |
| G4 | `/warn` (staff) + persistent warning log | Kick→ban has no intermediate step; no sanction history |
| G5 | `/ajail [id] [min]` | Admins cannot jail directly (combat-loggers returning, rule-breakers); `/unjail` exists but is police-gated |
| G6 | Teleport WITH vehicle (self & target) | `/tp` `/bring` move the ped only — admin loses his car, brought player's car stays behind |
| G7 | Routing-bucket safety on tp/bring | Target inside a house (bucket ≠ 0) → teleported admin/target becomes **invisible**; only `/arespawn` fixes bucket ([AUDIT 3-5.1] pattern) |
| G8 | Sanction broadcasts to players | Bans/kicks/warns are silent to the server — players only find out from Discord |
| G9 | Helper-level actions | Level 1 can literally only answer tickets — no warn, no heal, no freeze, nothing |
| G10 | `/gotoplayer` with dismount safety | bringing yourself into a player inside a vehicle = ped stuck in car collision |
| G11 | Temp-ban support | `bans.expires_at` exists in schema but `/ban` never writes it |
| G12 | Sanction history viewer | No `/history [id]` — staff cannot see past warns/kicks/bans of a player |
| G13 | `/aclear [id]` | Cannot clear wanted stars without faction perms (police offline edge case) |
| G14 | `/aheal all` / mass actions | Emergencies (server-wide stuck state) need per-player commands today |
| G15 | `goto` orphan permission | `['goto'] = 2` exists in config but NO command registers it — dead entry, remove or implement |
| G16 | `/revive` for downed-in-vehicle | works, but no `/pullout [id]` (extract from car before heal) |
| G17 | Spectator-mode player list | No quick overlay listing online players w/ id, name, admin level, faction, wanted, ping — staff navigate by `/astats` one-by-one |
| G18 | `/setrank` for turf clan ranks, `/setclan` | Only faction/job exist; clan edits need DB |
| G19 | Log of admin teleports/spawns | `logAdminAction` fires Discord embed for EVERY admin command call (spam risk) but there's no searchable local log |
| G20 | Console parity | `tp/bring/car/dv/noclip/god/heal/revive/coords/setcp…` all `return` for source 0 — fine — but `giveitem/givegun/kick/ban/setstat` DO work from console; document which do |

---

## 2. NEW HELPER SYSTEM (level 1)

### 2.1 Design goals
- Helpers are trusted players, NOT admins: they can de-escalate and assist, never silently punish (no ban/kick) and never touch economy/items.
- Every helper action is broadcast to all online staff (level ≥ 1) and written to `admin_sanctions` (see §4).
- Helper actions target ONLY the player experience: unfreeze situations, heal, respawn, warnings.

### 2.2 Helper permission table (level 1)

| Command | Level | Notes |
|---|---|---|
| `/warn [id] [reason]` | **1** | New — writes sanction row, broadcasts (§3) |
| `/history [id]` | **1** | New — read-only sanction history |
| `/heal [id]` | **1** | exists (2) — lower gate to 1 |
| `/revive [id]` | **1** | exists (2) — lower gate to 1 |
| `/arespawn [id] [mode]` | **1** | exists (2) — lower gate to 1 |
| `/freeze [id]` | **1** | New — freeze only; unfreeze by same or higher |
| `/unfreeze [id]` | **1** | New |
| `/tp [id]` · `/bring [id]` | keep **2** | Helpers should not move players; exception: `/tp` self stays level 1 for report response |
| `/helpdesk` | **1** | New — online player roster overlay with context actions (§4.9) |
| `/ar` `/cr` `/reports` | 1 | exists |

Everything else stays ≥ 2/3/5 as today. `logAdminAction` (Discord) stays for level ≥ 2 commands only — helper spam goes to the staff chat channel instead (no Discord embed per warn).

### 2.3 Helper on-duty flag (optional, phase 2)
`/aduty` toggles a helper's visible `[HELPER]` prefix in chat + name tag. Off-duty helpers act silently (same perms). Implementation: reuse the faction-duty pattern but store flag on `player.state:set('adminDuty', bool)`; chat prefix injected in `sunset_chat` where `[TAG]` is composed.

---

## 3. SANCTION SYSTEM (warn / kick / ban — with broadcasts)

### 3.1 DB: new table `admin_sanctions`

```sql
CREATE TABLE IF NOT EXISTS admin_sanctions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  action ENUM('warn','kick','tempban','ban','unban','jail','unjail','freeze') NOT NULL,
  target_account_id INT NULL,
  target_character_id INT NULL,
  target_name VARCHAR(64) NOT NULL,
  target_license VARCHAR(64) NULL,
  admin_account_id INT NULL,
  admin_name VARCHAR(64) NOT NULL,
  reason VARCHAR(255) NOT NULL DEFAULT '',
  duration_min INT NULL,              -- tempban / ajail duration
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_target_acc (target_account_id),
  INDEX idx_license (target_license),
  INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Migration file: `sql/46-admin-sanctions.sql` (next free number — verify before writing; deploy.sh applies automatically).

### 3.2 `/warn [id] [reason]` — NEW
- Level 1+. Reason mandatory (min 3 chars).
- Writes `admin_sanctions` row.
- Notifies target (UI banner `warning` type): `WARNING from {admin}: {reason}` + chat line.
- **Auto-escalation:** 3rd active warn within 7 days → staff broadcast suggesting kick (no auto-kick; owner decision — configurable `AutoKickOnWarns = false`).
- Warns never expire automatically; `/clearwarns [id]` (level 3+) marks them resolved (`resolved_at` column if owner wants — otherwise just don't count older than N days).

### 3.3 `/kick` — extend existing
- Keep behavior; ADD: sanction row + broadcast (§3.5).

### 3.4 `/ban` — extend existing
- New syntax: `/ban [id] [duration|perm] [reason]` — duration tokens: `30m`, `6h`, `7d`, `30d`, `perm`. Backward compatible: if arg2 is not a duration token, treat entire rest as reason → permanent (current behavior).
- Writes `expires_at` in `bans` (column EXISTS, unused today) + sanction row.
- `/tempban` alias.
- Ban-eviction hardening (phase 2): also store `GetPlayerToken(target, 0)` and check tokens in the connecting deferral (`bans` needs a `tokens` TEXT column or a `ban_tokens` side table).

### 3.5 Sanction broadcasts (the "appear in chat" requirement)

**To ALL players** (server chat message, type `admin_action`, styled like `/announce` but with a distinct color/badge):

| Event | Broadcast text (English, per product rule) |
|---|---|
| Warn | `⚠ {Target} received a warning from {Admin}: {reason}` |
| Kick | `✖ {Target} was kicked by {Admin}: {reason}` |
| Ban (temp) | `⛔ {Target} was banned for {duration} by {Admin}: {reason}` |
| Ban (perm) | `⛔ {Target} was permanently banned by {Admin}: {reason}` |
| Unban | `✔ {Target}'s ban was lifted by {Admin}` |
| Ajail | `{Target} was jailed for {minutes} min by {Admin}: {reason}` |

Config toggles in `sunset_admin/shared/config.lua`:
```lua
SunsetAdmin.Broadcast = {
    warn = true, kick = true, ban = true, unban = false, jail = true,
    showReason = { warn = true, kick = true, ban = true },  -- some owners hide ban reasons publicly
    cooldownSec = 2,   -- anti-spam between broadcasts
}
```
Transport: reuse `sunset:chat:message` client event with a new `type = 'admin_action'` (chat renderer in `sunset_ui` needs a style entry — red/orange left border + `SANCTION` badge; if chat types are hardcoded, add to the type switch in the chat module).

**To STAFF only** (level ≥ 1, via existing `broadcastStaff`): every sanction with target license + account id, e.g.
`[SANCTION] Helper Stefan warned Mihai (#12, license:abc…): 'RDM at grocery' — history: 2 prior warns`.

### 3.6 `/history [id]` — NEW (level 1+)
Reads last 10 `admin_sanctions` rows for target account (resolves offline players by name→account too, like `resolvePlayer` already does). Output as chat lines (reuse `sendPlacedCheckpointList` pattern) or the `/astats`-style single notification. Also shows active bans with `expires_at`.

---

## 4. NEW ACTION COMMANDS (full spec)

All commands: server-authoritative, `requirePerm`, target resolution via existing `resolvePlayer` (accepts id / username / display name), self-target guard where sensible.

### 4.1 `/spectate [id]` — level 2
- Server: validate target online → set spectator routing bucket to target's (`SetPlayerRoutingBucket(admin, GetPlayerRoutingBucket(target))`) + send coords snapshot every 1 s while spectating (`sunset:admin:spectateSync`).
- Client: `SetFollowPedCamViewMode` + `NetworkSetInSpectatorMode(true, targetPed)`; freeze local ped (`FreezeEntityPosition(ped, true)`, `SetEntityVisible(ped,false)`, `SetEntityCoords` far away or keep in place — prefer **keep coords, invisible+frozen** to avoid re-entry issues).
- On exit (`/spectate off`, ESC, target disconnect): restore bucket 0, visibility, unfreeze.
- **Routing bucket fix (also fixes G7):** when target is in a property bucket, spectator joins that bucket; on exit MUST reset to 0 (copy `/arespawn`'s `[AUDIT 3-5.1]` guard).
- While spectating, show target's health/armor/coords/vehicle/speed in the admin HUD strip (extend existing admin notify or a small NUI widget — phase 2).
- Log to `admin_sanctions` as `action='spectate'`? NO — keep spectate out of the public log; Discord staff channel only (level ≥ 1 see `X started spectating Y`).

### 4.2 `/freeze [id]` · `/unfreeze [id]` — level 1
- Server stores `Frozen[target] = {by=adminSrc, at=os.time()}`; client event `sunset:admin:freeze` → `FreezeEntityPosition(ped,true)`, disable controls (`DisableAllControlActions`), `TaskStandStill`. If in vehicle: also freeze the vehicle entity (store veh net id).
- Frozen state survives respawn attempts (re-apply in death handler if flagged).
- Auto-unfreeze on target disconnect (clear table) — NO persistent freeze across reconnects.
- Target notification: `You have been frozen by staff. Stay where you are.` + broadcast to staff.
- Guard: cannot freeze level ≥ own level (helpers can't freeze admins).

### 4.3 `/slap [id]` — level 2
- Client: `ApplyForceToEntity(ped, 1, dirX*F, dirY*F, 0, 0,0,0, 0, false,true,true,false,true)` with F = 15.0 upward-forward away from slap origin (use vector from admin→target, fallback straight up).
- Slap kills nothing by itself but combined with fall damage is a real deterrent; clamp: never slap a downed player (skip with error msg).
- Chat broadcast to target only: `You were slapped by {Admin}. Behave.` — no public broadcast (config toggle `Broadcast.slap = false`).

### 4.4 `/ajail [id] [minutes] [reason]` · `/aunjail [id]` — level 2
- Reuse the EXISTING police jail pipeline (`sunset_factions/server/police.lua` jail state + Bolingbroke spawn lock + payday suspension). Do NOT build a parallel jail: call the same internal function the arrest flow uses (expose it as `exports.sunset_factions:AdminJail(target, minutes, reason)` / `AdminUnjail(target)`).
- Duration 1–1440 min. Writes sanction row + broadcast (§3.5).
- `/unjail` (police) already exists — admin variant `/aunjail` bypasses faction perms.
- Interaction with sessions framework: jail transition already mirrored via `sunset_sessions` — ride that, don't duplicate.

### 4.5 `/tpcar [id]` · `/bringcar [id]` — level 2 (the "with the car" requirement)
- `/tpcar`: teleport ADMIN (inside his current vehicle if any, else on foot) to target — moves the whole vehicle entity: `SetEntityCoords(adminVeh, targetCoords+offset)`, put admin back in driver seat (`SetPedIntoVehicle`), reset bucket to target's bucket IF target is in a property (else 0). If admin has no vehicle → behaves as `/tp [id]`.
- `/bringcar`: same in reverse — bring target AND target's current vehicle (if any) to admin. Offset placement +2 m to avoid collision merge. If target not in vehicle → behaves as `/bring`.
- **Bucket normalization for BOTH (fixes G7):** before teleport, read target bucket; if target is inside a property (`sunset_properties` exports an `IsInside(src)` or check bucket > BucketBase), warn admin `Target is inside a property — teleporting to the door instead` and use the property ENTRANCE coords instead (properties config has entrances). Never dump a ped into someone's instanced interior uninvited unless admin explicitly `/tpint [id]` (phase 2).
- Vehicle persistence guard: if the moved vehicle is player-owned (`owner` column in vehicles table) and gets deleted later by session cleanup, nothing special needed — coords aren't persisted until store/park.

### 4.6 `/pullout [id]` — level 1
- Extract target from vehicle: `TaskLeaveVehicle` forced / `SetEntityCoords(ped, beside-vehicle)`; needed before heal/revive of downed drivers.

### 4.7 `/aclear [id]` — level 2
- Clear wanted stars without faction perms: call the existing wanted-clear used by `/clear` (police) via a new export `exports.sunset_factions:AdminClearWanted(target)`.

### 4.8 `/ahealall` · `/fixall` · `/dvall` — level 3
- `/ahealall`: loop `GetPlayers()` → `sunset:admin:heal` (emergency server-wide stuck-state fix).
- `/fixall`: repair every player's current vehicle (mass `/fix`).
- `/dvall [radius|all]`: delete unowned/orphan vehicles around admin — reuse `sweeporphans` logic from admintools where possible (it already deletes orphaned mission entities client-side); server variant deletes non-player-owned nearby vehicles.
- Confirmation prompt for `dvall` (type `CONFIRM` via chat or NUI) — destructive mass action.

### 4.9 `/helpdesk` — level 1 (player list overlay)
- NUI panel listing all online players: id, display name, admin level badge, faction+duty, wanted stars, jail/frozen/downed state, ping, playtime today.
- Row click → context actions gated by YOUR level: tp / bring / heal / warn / freeze / spectate / history / ajail.
- Data: one new callback `sunset:admin:roster` aggregating core player data + faction state + wanted + frozen registry. Refresh on open + every 5 s while visible.
- This replaces navigating blind with `/astats` per id (fixes G17) and is the natural home for all new commands.

### 4.10 `/gotoid [id]` alias cleanup + remove orphan `goto` perm
- Either register `goto` as alias of `tp [id]` or delete `['goto'] = 2` from config (G15). Recommend: alias, since muscle memory from other frameworks.

### 4.11 `/setclan [id] [clanId|none] [rank]` — level 3 (G18)
- Wrap existing clan internals (sunset_clans exposes member ops? verify; otherwise add export) so staff can move players between clans without DB.

---

## 5. CONFIG CHANGES (`sunset_admin/shared/config.lua`)

```lua
SunsetAdmin.Commands = {
    -- existing (unchanged levels except noted)
    heal = 1,          -- was 2
    revive = 1,        -- was 2
    arespawn = 1,      -- was 2
    -- new
    warn = 1,
    history = 1,
    freeze = 1,
    unfreeze = 1,
    pullout = 1,
    helpdesk = 1,
    spectate = 2,
    slap = 2,
    tpcar = 2,
    bringcar = 2,
    aclear = 2,
    ajail = 2,
    aunjail = 2,
    ahealall = 3,
    fixall = 3,
    dvall = 3,
    setclan = 3,
    clearwarns = 3,
    tempban = 3,       -- same gate as ban
}
SunsetAdmin.Broadcast = { ... }   -- §3.5
SunsetAdmin.WarnsBeforeStaffAlert = 3
SunsetAdmin.FreezeMaxSec = 600    -- auto-unfreeze failsafe (never leave a player frozen forever on admin crash)
```

Failsafes (non-negotiable):
- Frozen table cleared on `playerDropped` AND on resource stop (`onResourceStop` → unfreeze everyone).
- Spectate exits on resource stop / admin disconnect (client watchdog: if no sync packet for 5 s → restore).
- Jail via `/ajail` must go through the sessions state machine so a server restart restores it (police jail already persists — verify `AdminJail` uses the same persistence path).

---

## 6. IMPLEMENTATION PLAN (phased, for the coding agent)

**Phase 1 — sanction core (biggest value, no client work):**
1. `sql/46-admin-sanctions.sql` (verify next free number)
2. `/warn`, `/history`, sanction rows in kick/ban, temp-ban support (`expires_at`)
3. Broadcast system (§3.5) + `admin_action` chat type in `sunset_ui` chat renderer
4. Lower heal/revive/arespawn to level 1; helper perm table
5. Remove Discord embed spam for level-1 actions (staff chat instead)

**Phase 2 — presence tools:**
6. `/freeze` `/unfreeze` (+failsafes), `/pullout`, `/slap`
7. `/spectate` with routing-bucket handling
8. `/ajail` `/aunjail` via new `sunset_factions` exports (AdminJail/AdminUnjail/AdminClearWanted)

**Phase 3 — vehicle & mass tools:**
9. `/tpcar` `/bringcar` + property-entrance redirect + bucket normalization (fix G7 for plain `/tp` `/bring` too — same helper function)
10. `/ahealall` `/fixall` `/dvall` with CONFIRM
11. `/helpdesk` NUI roster panel + `sunset:admin:roster` callback

**Phase 4 — polish:**
12. `/setclan`, `/clearwarns`, `goto` alias cleanup, ban token hardening
13. Add all new commands to `sunset_core/shared/help_registry.lua` (staff section) and the wiki (`server redesign/wiki-full.html` → new "Staff Tools" page)

**Static checks per AGENTS.md after each phase:** `check-lua-syntax.js`, `check-lua-forward-refs.js`, `check-db-writes.js` (sanctions table is owned by `sunset_admin` — writes from there are legal; factions must NOT write it directly, call admin exports or duplicate the row via event), `audit-static.ps1` (duplicate command names — `freeze`/`slap` don't collide with anything today, verified), `check-nui-bridge.js` for `/helpdesk`.

---

## 7. RISK NOTES

- **`sunset_sessions` is canonical** for state machines (AGENTS.md): `/freeze` and `/ajail` should mirror into it like jobs/robbery do — a frozen player's sessions (job shift, robbery) need defined behavior. Recommend: freeze does NOT end sessions (it's a hold), jail DOES (existing arrest flow already handles).
- **Domain ownership:** sanction rows only written by `sunset_admin`. Police jail internals stay in `sunset_factions`; admin jail = thin wrapper export, no direct table writes from admin.
- **Broadcast spam:** ban/warn broadcasts are public — a mass-ban wave (raid) would flood chat. Cooldown 2 s + cap 5 broadcasts/min, queue the rest silently to Discord.
- **Helper abuse:** helpers get warn/freeze — every action is DB-logged and staff-broadcast; `/history` on the HELPER themselves is the audit tool. Consider `WarnsPerHour` soft cap alert to owners.
- **OpenCode is live-editing this repo** — coordinate: this spec touches `sunset_admin` (mostly untouched by current work), `sunset_factions` exports (police.lua — high traffic, check before editing), `sunset_ui` chat renderer (app.js — OpenCode was editing it).
