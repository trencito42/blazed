# ANTICHEAT SYSTEM — Full Specification ("Blaze Shield")

> Status: SPEC (no code written — hand off to implementation)
> Companion to: `docs/ADMIN_SYSTEM_SPEC.md` (shares sanction table, helper GUI, broadcast system)
> Design mandate from owner: **conservative — zero tolerance for false-positive bans.** Detection gathers evidence; humans decide. Nothing auto-bans on a heuristic alone.

---

## 1. DESIGN PRINCIPLES (non-negotiable)

1. **No automatic bans.** Every detection = a "tick" (strike). Ticks accumulate heat; only **staff** convert heat into warn/kick/ban via `/acheat` GUI. The single exception: confirmed *server-side money/inventory injection* (DB-level impossibility, see §4.9) may auto-kick + flag for review.
2. **Ticks decay.** A tick expires after 30 min of clean play (configurable). Casual lag spikes never accumulate into anything.
3. **Evidence per tick.** Every tick stores: detector name, measured values, threshold, player state snapshot (vehicle, bucket, session, faction duty, last admin action). Staff sees WHY it fired, not just THAT it fired.
4. **Context whitelists are part of the detector, not an afterthought.** Server-side legit sources of "impossible" movement/weapons must be excluded by design (see §3 — this codebase has MANY: turf war respawns, admin commands, robbery systems, property buckets, seatbelt ejection).
5. **Server authority first.** Client telemetry is advisory only — a compromised client can lie, so client-reported detections never solo-convict; they need server-side corroboration or repeat pattern.
6. **Rate-limit everything.** Detectors are throttled server-side (tick sampling every 1–2 s), never per-frame, to keep resmon near zero (server already has perf issues — see `docs/NUI_PERFORMANCE_DIAGNOSIS.md`).

### Honest capability statement (set expectations)
A server-side anticheat on FiveM **cannot** detect: client-side ESP/wallhack, aimbot (only statistical suspicion), modified client resources, external overlays. It CAN reliably detect: speedhack, teleport, noclip/fly, godmode, health/armor injection, weapon/ammo spawn, vehicle spawn, money injection, event/callback spam, superjump, invisibility, plate spoofing. This spec targets the detectable set and flags aimbot only via *pattern evidence* (never solo action).

---

## 2. ARCHITECTURE

New resource: **`sunset_anticheat`** (own domain — writes only its own tables, per DOMAIN_OWNERSHIP).

```
┌─────────────────────────────────────────────────────────────┐
│ SERVER (sunset_anticheat/server/)                            │
│  • detectors.lua      — server-side heuristic engine         │
│  • corroboration.lua  — cross-checks client claims vs state  │
│  • context.lua        — whitelist provider (§3)              │
│  • strikes.lua        — tick registry, decay, heat scoring   │
│  • exports            — IsWhitelisted / RegisterLegitSource  │
├─────────────────────────────────────────────────────────────┤
│ CLIENT (sunset_anticheat/client/)                            │
│  • sampler.lua        — telemetry: speed, health, coords,    │
│                        weapon list, control state (1 Hz)     │
│  • sends to server via secured event (rate-limited, signed)  │
├─────────────────────────────────────────────────────────────┤
│ NUI (admin GUI)                                              │
│  • live tick feed (bZone style, on-screen corner widget)     │
│  • /acheat panel: player heat list, evidence detail, actions │
├─────────────────────────────────────────────────────────────┤
│ DB: anticheat_strikes + anticheat_flags                      │
└─────────────────────────────────────────────────────────────┘
```

Integration points (READ-only via existing `sunset_core` callbacks / exports):
- `sunset_sessions` — active session type (robbery/job/exam/war) → context
- `sunset_properties` — inside-property + routing bucket → context
- `sunset_factions` — on-duty + loadout issued → context
- `sunset_vehicles` — owned/known vehicle models → context
- `sunset_admin` — recent admin actions on player (`/car`, `/speed`, `/noclip`, `/tp`) → context
- `sunset_inventory` — inventory contents (weapon legitimacy) → corroboration
- `sunset_economy` — balance-change events → money injection checks

---

## 3. CONTEXT WHITELIST ENGINE (the false-positive killer)

Every detector call `Context.IsLegit(src, checkType)` BEFORE recording a tick. A player is exempt from movement/weapon checks when ANY of these is true:

| Context source | Exempts checks | Why |
|---|---|---|
| Admin level ≥ 2 AND `/noclip` `/god` `/speed` active on them | speed, fly, teleport, damage | Admin tools legitimately break physics |
| Inside property (bucket > BucketBase) or bucket transition in last 10 s | teleport, speed, "invisible ped" | Routing bucket swaps cause coord jumps |
| Active turf war participant (war state from sunset_turfs) | weapons (loadout), teleport (war respawn), death-rate | War respawn + issued loadouts |
| Active robbery session (sunset_robbery) | weapons near store, speed (escape phase), inventory weight (duffel +8kg) | Robbery systems grant these |
| Active license exam session | vehicle spawn (exam car), teleport (checkpoint fail reset) | Exams spawn/reset vehicles |
| Active job session (trucker/fisherman/…) | vehicle spawn (job vehicle), coords in job zone | `/work` spawns vehicles |
| On-duty faction member with issued loadout | weapons, ammo | `/duty` gives weapons |
| Within 10 s of receiving ANY admin action (`/tp` `/bring` `/car` `/givegun` `/arespawn` `/slap` `/spectate`) | matching check types | Admin commands look exactly like cheats |
| Vehicle = owned / insured / job-spawned / dealership test-drive | vehicle spawn, plate checks | Legit vehicle sources |
| Dead/downed/bleedout state | health anomalies, speed (ragdoll physics) | Death system moves bodies |
| Seatbelt-ejection ragdoll in last 15 s | teleport (short), fly (ragdoll launch) | Ejection physics throw players |
| Ping > 250 ms or packet-loss spike (server-known) | ALL timing-based checks for 30 s | Lag is not cheating |

Context is **logged with every tick** so staff can see "fired while player was in a legit war" instantly.

Whitelist registry export: other resources call `exports.sunset_anticheat:MarkLegit(src, 'vehicle_spawn', 10)` when THEY do something cheat-looking (e.g., dealership delivery, tuning save). One-line integration per system.

---

## 4. DETECTORS (tick sources)

Each detector: name, method, threshold, FP mitigation, severity (1–3 ticks per fire), cooldown between fires.

### 4.1 Speed — `speed_check` (server-side, 1 Hz)
- Method: track `GetEntityCoords` delta per second for players in vehicles; compare against per-vehicle-class max (vehicle class → top speed table, e.g. super 62 m/s, sedan 45, motorcycle 50, plane/heli exempt entirely).
- Trigger: measured > class_max × **1.35** sustained for **3 consecutive samples** (not one spike!).
- FP mitigation: 1.35× margin absorbs netcode jitter + downhill + draft; 3-sample sustain kills single-tick lag jumps; planes/boats/helis exempt; admin `/speed` multiplier read from admin state and applied to threshold.
- Severity 2, cooldown 60 s.

### 4.2 Teleport — `teleport_check` (server-side, 1 Hz)
- Method: position delta between samples > 60 m/s equivalent while NOT in exempt vehicle class; or instant coord jump > 150 m in 1 s on foot.
- FP mitigation: full Context table (§3) — bucket swaps, war respawn, admin tp, exam resets, ragdoll. On-foot-only strictness (vehicles get §4.1 instead).
- Severity 2, cooldown 30 s.

### 4.3 Fly / noclip — `fly_check` (client sampler + server corroboration)
- Method: client reports `IsPedFalling`, `IsPedInAnyVehicle`, `IsPedSwimming`, `IsPedRagdoll` + Z-velocity; server flags sustained ascent (Z+ > 3 m/s for 5 s) with no vehicle/parachute/ragdoll/explasion context.
- FP mitigation: parachute (`GetPedParachuteState`), admin noclip flag, helicopter exit (grace 5 s), stunt jumps (falling state exempt), `IsEntityInAir` cross-check server-side.
- Severity 3, cooldown 120 s.

### 4.4 Godmode / damage resistance — `damage_check` (server-side event)
- Method: hook `weaponDamageEvent` (server-side — the license gate already hooks it, reuse pattern). Track incoming damage vs health decrease. If player takes > 500 cumulative damage in 10 s with < 10% health loss → tick. Also `GetPlayerInvincible` server native check every 10 s.
- FP mitigation: armor absorbs damage legitimately (track armor too — combined HP+armor must drop); admin `/god` flag; EMS heal during window subtracts from "missing damage"; only count player-sourced damage, not falling/world.
- Severity 3, cooldown 60 s.

### 4.5 Health / armor injection — `health_check` (server-side, 0.2 Hz)
- Method: server knows last known HP/armor; flag instant jumps (HP +50 in <2 s) with no heal source (EMS command, bandage use event, hospital respawn, admin heal — all whitelisted via MarkLegit).
- FP mitigation: every legit heal path already goes through server code — instrument them all with `MarkLegit(src,'health',5)`.
- Severity 3, cooldown 60 s.

### 4.6 Weapon spawn — `weapon_check` (client list vs server ledger)
- Method: server keeps a per-player weapon ledger (starting inventory + shop purchases [ammo/weapon events] + faction loadout on duty + admin `/givegun` + war armory + robbery props). Client sampler reports `GetAllWeapons`-style list every 5 s; unledgered weapon = tick.
- FP mitigation: ledger is seeded generously (duty loadout events, armory pickup, exam issue); mismatch gives player 10 s grace (inventory sync latency); ledger rebuilds on respawn/session change; **first fire = FLAG only (severity 1)**, second unledgered weapon within 10 min = severity 3.
- Note: this is the highest-value detector on this server (gun economy is gated by license + $8.5k–32k prices).
- Severity 1→3 progressive, cooldown 300 s.

### 4.7 Ammo injection — `ammo_check` (client sampler, 10 s)
- Method: ammo for ledgered weapons vs purchase history (ammo boxes) with wide margin: flagged only if ammo > owned_boxes × 24 + 300 (generous floor).
- FP mitigation: war armory grants flat ammo (ledgered), loadouts ledgered, generous floor absorbs all legit sources.
- Severity 2, cooldown 600 s.

### 4.8 Vehicle spawn — `vehicle_spawn_check` (server-side entity created event)
- Method: `entityCreated` hook — vehicle whose owner-source player has no matching spawn source (garage spawn event, `/car` admin, job spawn, dealership delivery, exam, faction fleet duty spawn) = tick.
- FP mitigation: ALL spawn paths funnel through server code today (verified in audit) — instrument each with MarkLegit. Trailer/tow combinations inherit parent legitimacy.
- Severity 3, cooldown 120 s.

### 4.9 Money / stat injection — `economy_check` (server-side, event-based) — **the only auto-action detector**
- Method: `sunset_economy` already routes every balance change server-side. Sanity rules: cash/bank increase not matching a known source (payday, job payout, fence, sale, trade, lottery, dice, admin setstat) = FLAG + auto-KICK + Discord @owner ping + row in `anticheat_flags` with full evidence.
- This is not a heuristic — it's an accounting impossibility; a client cannot add money without a server callback, so if the ledger doesn't balance, something injected via a compromised callback path. Zero FP risk IF all sources are enumerated — enumerate them in Phase 1 against `sunset_economy` + `sunset_inventory/trade.lua`.
- Severity: immediate kick (never auto-ban), staff reviews via flag.

### 4.10 Event/callback spam — `spam_check` (server-side, per-event counters)
- Method: wrap hot NUI callbacks + chat commands with sliding-window rate limits (e.g., `post()` bridge events: >30/min per name = tick; chat commands >20/min = tick; `sunset:admin:*` events from non-admins = instant flag).
- FP mitigation: legit UI spam (fast inventory clicks) stays under 30/min easily; measure real usage in Phase 1 before enabling (log-only mode first week).
- Severity 1, cooldown 300 s.

### 4.11 Superjump / stamina — `movement_check` (client sampler, 1 Hz)
- Method: vertical impulse without vehicle/fall context (> 8 m jump on flat ground); infinite stamina flag (`GetPlayerSprintStaminaRemaining` never decreasing while sprinting, sampled 5×).
- FP mitigation: ramps/stunts excluded via `IsPedFalling` + surface normal check; only fires 3× in 60 s.
- Severity 1, cooldown 300 s.

### 4.12 Invisibility / model swap — `ped_check` (server-side, 0.1 Hz)
- Method: `IsEntityVisible(ped)` false without spectate/admin flag; ped model not matching character appearance model (server stores expected model at spawn).
- FP mitigation: spectate whitelist, death-state invisibility (ragdoll/corpse handling), clothing-change sessions at barber/wardrobe (MarkLegit during UI focus).
- Severity 3, cooldown 120 s.

### 4.13 Plate spoofing — `plate_check` (server-side, on vehicle enter events)
- Method: entered vehicle's plate vs DB registration when owner-source known; mismatch on owned vehicle = flag.
- Severity 1, cooldown 600 s. (Low priority — cosmetic crime.)

### 4.14 Resource stopper / client tamper — `heartbeat_check`
- Method: client sampler must heartbeat every 10 s with a rotating server nonce. Missing 3 heartbeats while connected = tick ("client module not responding" — covers resource stopper).
- FP mitigation: ONLY fires while player is connected AND not loading/respawning; never kicks on its own (many legit disconnect artifacts) — it's a flag for staff, severity 2.
- **Note:** a real stopper can also freeze our sampler — the nonce + server-side timeout catches that, but a modified-client user could forge heartbeats. Accept: this detector catches casual stoppers only; do not over-trust it.

### 4.15 Aimbot suspicion — `aim_stats` (client sampler, LOG-ONLY forever)
- Method: sample headshot ratio + snap-angle deltas over 100+ shots; store stats, never tick alone.
- Output: shows as an *info badge* in `/acheat` player detail ("HS ratio 78% over 200 shots") for staff judgment. **Never generates a strike by itself** — snipers legit headshot.

---

## 5. STRIKE / HEAT SYSTEM

```
heat = Σ (severity × recency_factor)   -- recency: tick <5min = ×1.0, <15min = ×0.7, <30min = ×0.4, >30min = expired
```

| Heat | Status | Automatic consequence |
|---|---|---|
| 0–2 | 🟢 CLEAN | none |
| 3–5 | 🟡 WATCH | player appears in admin live feed; staff notified (once per threshold) |
| 6–9 | 🟠 SUSPECT | auto-broadcast to ALL online staff with evidence summary; player name orange in `/helpdesk` roster |
| 10+ | 🔴 CRITICAL | auto-broadcast + `/spectate` prompt; still **NO auto-ban** — staff decides (kick/ban via existing sanction system → public chat broadcast per ADMIN_SYSTEM_SPEC §3.5) |

Tick decay: every detector tick has `expires_at = now + 30 min`; heat recomputed lazily. A player who lags once and plays clean is back to 🟢 in half an hour with zero staff noise.

Staff resolution actions (from GUI): `DISMISS` (marks ticks as false positive — feeds a per-detector FP counter; if a detector's FP-dismiss rate > 40%, auto-log a warning to owners that the threshold needs tuning), `WARN`, `KICK`, `BAN`, `SPECTATE`, `FREEZE`.

---

## 6. ADMIN GUI (the bZone-style on-screen system)

### 6.1 Live feed widget (level 1+ = helpers see it too)
- Small corner HUD element (NUI, toggleable with `/achud`, position saved):
```
┌ BLAZE SHIELD ────────────────┐
│ 🔴 Mihai #12   speed ×3      │
│ 🟠 Alex  #4    weapon flag   │
│ WATCHING: 2  TICKS/min: 0.4  │
└──────────────────────────────┘
```
- Only shows 🟠+ players (keeps it quiet — no noise from single lag ticks).
- Click a row → opens full `/acheat` panel for that player.

### 6.2 `/acheat` panel (full dashboard, level 1+)
- **Left: player list** — everyone online sorted by heat, color-coded, with heat number + tick count + top detector.
- **Right: selected player detail**
  - Heat score + decay timeline
  - Tick list: detector, measured vs threshold, time, **context snapshot** (in war? in property? admin action 5 s before? job session?)
  - Quick stats: ping, FPS (from admintools sampler — already collected!), playtime, prior sanctions (`admin_sanctions` join), warn count
  - Aim-badge if aim_stats has 100+ shots of data
  - Action buttons: Spectate · Freeze · Warn · Kick · Ban · Dismiss all ticks (each gated by the standard permission levels — helpers can only Dismiss/Warn/Freeze/Spectate)
- **Top: detector health tab** (level 3+) — per-detector: fires today, dismiss rate, top-fired players. This is how you TUNE thresholds without guessing: a detector with 40%+ dismiss rate is too sensitive and shows itself.

### 6.3 Discord integration
- 🟠+ heat events → `#anticheat` channel embed: player, detector, evidence, context, heat. (Reuses `sunset_core:SendDiscordLog`.)
- Economy injection auto-kicks → @owner ping.
- Daily summary (optional): ticks per detector, top suspects, dismiss rate.

---

## 7. DB SCHEMA

```sql
CREATE TABLE IF NOT EXISTS anticheat_strikes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  character_id INT NULL,
  account_id INT NULL,
  player_name VARCHAR(64) NOT NULL,
  license VARCHAR(64) NULL,
  detector VARCHAR(48) NOT NULL,
  severity TINYINT UNSIGNED NOT NULL,
  measured VARCHAR(255) NOT NULL,      -- e.g. "68.2 m/s vs limit 45 (sedan)"
  context JSON NULL,                    -- {in_war:false, bucket:0, admin_action:"/tp 4s ago", session:null, ping:82}
  resolved ENUM('pending','dismissed','warned','kicked','banned') DEFAULT 'pending',
  resolved_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NULL,            -- decay (30 min default)
  INDEX idx_acc_created (account_id, created_at),
  INDEX idx_detector (detector, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS anticheat_flags (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  account_id INT NULL,
  player_name VARCHAR(64) NOT NULL,
  flag_type VARCHAR(48) NOT NULL,       -- 'economy_injection','admin_event_abuse','aim_stats'
  evidence JSON NOT NULL,
  action_taken VARCHAR(32) DEFAULT 'none',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_acc (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Migration: next free `sql/NN-anticheat.sql` (verify number at implementation time).

---

## 8. CONFIG (`sunset_anticheat/shared/config.lua`)

```lua
Config = {
    Enabled = true,
    Mode = 'enforce',            -- 'log_only' = record ticks, no GUI noise (Phase 1 rollout mode!)
    TickLifetimeSec = 1800,
    Heat = { watch = 3, suspect = 6, critical = 10 },
    AutoKickOnEconomyInjection = true,   -- the ONLY auto-action
    AutoBanAnything = false,             -- must stay false. ever.
    PingExemptMs = 250,
    Detectors = {
        speed    = { enabled = true, margin = 1.35, sustainSamples = 3, cooldown = 60 },
        teleport = { enabled = true, cooldown = 30 },
        fly      = { enabled = true, cooldown = 120 },
        damage   = { enabled = true, cooldown = 60 },
        health   = { enabled = true, cooldown = 60 },
        weapon   = { enabled = true, cooldown = 300 },
        ammo     = { enabled = true, cooldown = 600 },
        vehspawn = { enabled = true, cooldown = 120 },
        economy  = { enabled = true },
        spam     = { enabled = true, nuiPerMin = 30, chatPerMin = 20 },
        movement = { enabled = true, cooldown = 300 },
        ped      = { enabled = true, cooldown = 120 },
        plate    = { enabled = false },          -- off by default, cosmetic
        heartbeat= { enabled = true, cooldown = 300 },
        aimstats = { enabled = true, logOnly = true, locked = true },  -- can never tick
    },
    Hud = { enabled = true, defaultPos = 'topright' },
    Discord = { channel = 'anticheat', dailySummary = true },
}
```

**Rollout protocol (owner requirement — no FP bans):**
1. Deploy in `Mode = 'log_only'` for **1 full week** of normal population.
2. Review `/acheat` detector-health tab daily: any detector with fires on known-legit players → tune threshold or fix whitelist BEFORE enforce mode.
3. Flip to `enforce` only when dismiss rate < 10% on every detector for 3 consecutive days.
4. Economy injection detector may run in enforce from day 1 (accounting, not heuristic) — but only after Phase-1 source enumeration is verified complete.

---

## 9. IMPLEMENTATION PLAN (phased)

**Phase 0 — plumbing (small):** resource skeleton, DB migration, heartbeat, Context engine + `MarkLegit` export, instrument existing legit sources (admin commands, duty loadout, war armory, job spawns, dealership, exams, property bucket changes, robbery). *This phase is 50% of the false-positive battle — do it first and completely.*

**Phase 1 — log-only detectors:** speed, teleport, fly, health, damage, spam. GUI: `/acheat` panel + live feed widget (staff can already watch ticks accumulate with zero player impact).

**Phase 2 — ledger detectors:** weapon + ammo ledger (needs inventory/purchase instrumentation), vehicle spawn, economy accounting. Discord embeds.

**Phase 3 — remainder + tuning:** movement, ped, heartbeat, plate, aim_stats badge; detector-health tuning tab; FP-dismiss analytics; enforce mode per rollout protocol.

**Phase 4 — integration polish:** heat colors in `/helpdesk` roster (ADMIN_SYSTEM_SPEC §4.9), spectate-from-GUI, sanction actions from GUI writing to `admin_sanctions` + public broadcasts (existing system).

**Static checks after each phase (AGENTS.md):** lua-syntax, forward-refs, db-writes (anticheat owns only its 2 tables; economy reads via callbacks, never writes sunset_economy tables), nui-bridge (GUI posts), audit-static (no command collisions: `/acheat` `/achud` are free — verified against current command list).

---

## 10. RISK NOTES

- **Performance:** server is already NUI-heavy on clients; sampler must be 1 Hz max, batched into ONE event per tick, and server detectors must reuse one 1 Hz loop for all players (not per-player timers). Budget: <0.05 ms resmon server-side.
- **`weaponDamageEvent` is shared:** the firearm-license gate already hooks it (`sunset_licenses`, known-flaky per AGENTS.md — owner wanted it disabled). Anticheat's damage hook must be an independent `AddEventHandler` in its own resource; verify it doesn't resurrect or conflict with the license gate.
- **OneSync culling:** server `GetEntityCoords` for far-away players can be stale — detectors must skip players outside the admin/OneSync scope or use `GetPlayerServerCoord`-style updates only when entity is network-owned server-side. Test with 20+ players before trusting speed numbers.
- **Property buckets:** any position check that ignores routing buckets will flag every house visitor. Context engine handles it — but Phase 0 must include `sunset_properties` bucket-enter/exit MarkLegit or Phase 1 will drown in FPs.
- **Turf wars:** war loadout + war respawn teleport + war-weapon stripping at end = the single densest FP source on this server. All three instrumented in Phase 0.
- **Client sampler can be stopped** by a determined cheater — heartbeat catches stopping, but a forged client beats it. Accept the ceiling: this system stops 95% of script kiddies (injectors, trainers with obvious toggles) and gives staff *evidence* for the rest. Server-authoritative accounting (economy, weapon ledger) is the part that can't be forged — prioritize those.
- **Privacy/UX:** the live feed shows player names to helpers — restrict GUI to level 1+ (already), and log every `/acheat` open to Discord so staff-monitoring-staff stays auditable.
