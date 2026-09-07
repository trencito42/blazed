# Sunset/Blaze RPG — Release Audit

**Audit started:** 2026-09-07  
**Starting commit (deployed baseline):** `eff70762ce5b06bf2cd5e0b43ab8147e2324bad4` (`eff7076`)  
**Local state:** Uncommitted fixes on `main` (18 modified + 7 new docs + `scripts/audit-static.ps1`)  
**Production:** Not restarted during this pass

---

## 1. Repository state

| Item | Value |
|------|-------|
| Branch | `main` (synced with `origin/main` at start) |
| Uncommitted | Command router, MOTD, pass, deploy, chat rate limits, docs |
| Untracked user assets | HTML/png prototypes at repo root (preserved) |
| `server.cfg` | Gitignored — not in remote |
| SQL migrations | `sql/02`–`sql/23` (24 files); `01-sunset.sql` bootstrap skipped on deploy |

---

## 2. System inventory (35 `sunset_*` resources)

Production ensure order: `config/server.cfg.template` (all 35 resources).

| Resource | Purpose |
|----------|---------|
| sunset_loadscreen | Loading screen NUI |
| sunset_core | Framework: player, character, money, callbacks, buylevel |
| sunset_ui | Shared NUI shell, notifications, panels |
| sunset_world | World markers, blips, zones |
| sunset_factions | Police/EMS/Fire/Taxi factions, duty, wanted, jail |
| sunset_clans | Player clans, tags, MOTD, management |
| sunset_dispatch | Service calls (taxi/medic/fire/mechanic) |
| sunset_crafting | Crafting stations |
| sunset_auth | Login/register |
| sunset_characters | Character list/create |
| sunset_appearance | Character appearance |
| sunset_spawn | Spawn selector |
| sunset_player | Player state sync |
| sunset_inventory | Items, weight |
| sunset_economy | Shops (if split) |
| sunset_needs | Hunger/thirst/stress |
| sunset_death | Downed/death/respawn |
| sunset_vehicles | Keys, fuel, garage hooks |
| sunset_admin | Admin commands |
| sunset_properties | Houses, rent, interiors |
| sunset_emotes | Emotes |
| sunset_clothing | Clothing shops |
| sunset_phone | Phone NUI |
| sunset_taxi | Taxi fares |
| sunset_fire | Fire missions |
| sunset_documents | ID/licenses |
| sunset_jobs | Civilian jobs (trucker, garbage, courier, fisherman, mechanic) |
| sunset_robbery | Store robbery minigame |
| sunset_pass | Blaze Pass seasons |
| sunset_hud | On-screen HUD |
| sunset_dealership | Vehicle dealership |
| sunset_scoreboard | Player list |
| sunset_chat | T-chat, command router, connect MOTD |
| sunset_menu | M-menu |
| sunset_help | `/help` panel |

**Manifest audit:** No missing script files in manifests (static scan). `sunset_ui` uses globs for assets.

**Dependency issue:** `sunset_world` ↔ `sunset_factions` circular `dependencies` — monitor startup; template order loads world before factions.

**Dev `server.cfg`:** Only 12 resources — local dev ≠ production parity.

---

## 3. Fixes applied (this audit pass)

| ID | Severity | Issue | Fix | Verified |
|----|----------|-------|-----|----------|
| F1 | P0 | `/cmotd` / clan MOTD UI broken | Server `RunMotdCommand`, safe audit/broadcast, `pcall` dashboard, UI prefill | Code |
| F2 | P0 | `/fmotd` chat routing | `RunFactionMotdCommand` + router | Code |
| F3 | P0 | T-chat server cmds → client | `tryRunResourceCommand` + exports | Code |
| F4 | P0 | EMS heal/revive admin-blocked | Faction medic bypass in router | Code |
| F5 | P1 | `/accept` collision | Delegate &lt;2 args to client | Code |
| F6 | P1 | Pass claim duplication risk | Persist before grant | Code |
| F7 | P1 | deploy migrations swallowed | Exit 1 on failure | Code |
| F8 | P1 | Chat/command spam | Rate limits 350/400ms | Code |

---

## 4. Release gates (§24)

| Gate | Status |
|------|--------|
| Unauthorised economy mutation | **REVIEW** — callbacks audited statically; not live-tested |
| Client-trusted rewards | **PARTIAL** — robbery/jobs need live test; pass fixed |
| Item/money duplication | **PARTIAL** — pass fix; inventory not fully tested |
| `/help` or commands return nil | **PASS** (code) — help returns error string if no char |
| Broken auth/spawn | **NOT TESTED** live |
| Stuck NUI focus | **NOT TESTED** live |
| Faction/job corruption on leave | **PASS** (code intent) — verify live |
| deploy migration safety | **FIXED** locally |
| Critical manifest omission | **PASS** |
| Severe perf loop | **NOT MEASURED** |

**Overall release-ready:** **NO** — requires live multiplayer verification and death-system hardening.

---

## 5. What was tested

| Area | Method |
|------|--------|
| Git state, migrations list | Shell |
| 35 manifests, command collisions | Static explore agent + grep |
| Command router logic | Code review |
| MOTD/clan/pass paths | Code review |
| Secrets in tracked files | Grep |
| Runtime gameplay | **NOT RUN** (no production restart) |

---

## 6. What could not be tested

- Dual-client replication (cuff, revive, taxi)
- Full job completion loops
- Dealership stock races
- Payday/AFK progression
- Performance (`resmon`, query counts)
- Production DB state on VPS

---

## 7. Database migrations

**Required for current code:** Through `23-clan-ranks.sql` (numeric clan ranks, `rank_labels`, warns).

**Deploy:** `deploy.sh` applies `sql/[0-9][0-9]-*.sql` after MariaDB healthy. Failures now **abort** unless `DEPLOY_IGNORE_MIGRATION_ERRORS=1`.

**Rollback:** Revert git + redeploy; do not drop production DB. Clan/faction data in normal columns unaffected by this pass.

---

## 8. Deployment procedure

```text
1. Commit local fixes (separate commits: gameplay fixes, deploy, docs)
2. Push to origin/main
3. Run scripts/remote-deploy.ps1 ONLY when operator approves
4. Verify: /cmotd, /clan MOTD save, /buylevel, /help, /service medic test
5. Run MANUAL_MULTIPLAYER_TEST_PLAN.md with two clients
```

**Do not** restart production until step 1–2 complete and operator requests deploy.

---

## 9. Related documents

| Document | Contents |
|----------|----------|
| `PERMISSION_MATRIX.md` | Admin, faction, clan, economy permissions |
| `COMMAND_REFERENCE.md` | ~169 commands from registrations |
| `SECURITY_AUDIT.md` | Findings H1–M6, secrets |
| `PERFORMANCE_REPORT.md` | Static notes; no runtime metrics |
| `MANUAL_MULTIPLAYER_TEST_PLAN.md` | Two-client checklist |
| `scripts/audit-static.ps1` | Repeatable static checks |

---

## 10. Remaining blockers

1. **Live verification** of MOTD, router, pass, EMS heal after deploy.
2. **Death/downed** client-trust (H3 in security audit).
3. **saved-account passwords** in client KVP (H4).
4. **Performance profiling** not done.
5. **Full job/faction/police** matrix not executed.
6. **world ↔ factions** circular dependency — watch for startup races.

---

## 11. Stale reports

Treat any prior “completed” labels as **unverified** until covered by this audit or live tests above.
