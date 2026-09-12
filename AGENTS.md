# AGENTS.md — SunsetMP / Blazed (FiveM RPG server)

Custom framework: ~29 `sunset_*` resources under `resources/[sunset]/`, oxmysql for DB. No ESX/QBCore. `sunset_core` owns money/players/callback bus; ~290 callbacks registered via `exports.sunset_core:RegisterCallback(name, fn)` and called client-side with `Sunset.AwaitCallback(name, ...)`.

## CRITICAL: deploy flow

`scripts/remote-deploy.ps1` does NOT upload the working tree. It SSHes into the VPS and runs `/opt/blazed/deploy.sh`, which does **`git pull`/archive download from GitHub**. Therefore:

**commit → `git push origin main` → `.\scripts\remote-deploy.ps1`**

If you skip the push, the VPS silently keeps running old code and "verification" (logs, testdriver) tests the OLD build. This has bitten us before — always verify after deploy that the new commit hash is live:
`ssh -i C:\Users\stefan\.ssh\sshxodo root@193.33.167.216 "cd /opt/blazed && git log --oneline -1"`

- VPS: `root@193.33.167.216`, key `C:\Users\stefan\.ssh\sshxodo`, Docker Compose (`blazed-fivem-1`, `blazed-mariadb-1`), game port 30120.
- DB creds live in container env: `docker exec blazed-mariadb-1 printenv | grep MARIADB`. Direct SQL: `docker exec blazed-mariadb-1 mariadb -usunset -p<PASS> sunsetmp -e "..."` (single quotes inside `-e` break through SSH — write the SQL with escaped double quotes or use a heredoc file).
- After deploy, check health: `docker logs blazed-fivem-1 --since 3m | grep -i testdriver` → expect `all: 56 checks, 0 failed`.

## Static checks (run before every commit)

```powershell
node scripts\check-lua-syntax.js         # 0 Lua syntax errors (luaparse; MANDATORY after bulk edits - a broken file loads as "resource started" with NO exports and errors only in VPS logs)
node scripts\check-lua-forward-refs.js   # 0 forward-reference issues
node scripts\check-db-writes.js          # 0 NEW cross-domain write violations
node scripts\check-nui-bridge.js         # all posted NUI callbacks registered
powershell -File scripts\audit-static.ps1 # manifest refs, duplicate commands
node --check <file>.js                    # for any edited web JS
```

After deploy, ALWAYS grep VPS logs for `Error parsing script` — FiveM logs it once at startup and then reports "Started resource" anyway, silently killing every export/command in that file:
`ssh ... "docker logs blazed-fivem-1 2>&1 | grep -a 'Error parsing script'"`

No local Lua interpreter; there is no `luac`. Lua errors only surface on the VPS after deploy.

## Windows PowerShell gotchas (this machine, PS 5.1)

- Paths contain literal `[sunset]` brackets — ALWAYS use `-LiteralPath` with `Get-Content`/`Set-Content`/`Select-String`, or paths get wildcard-matched and silently return nothing.
- Do NOT do multi-string Romanian/diacritic replacements via PowerShell `-Raw` + `Set-Content` (corrupts UTF-8 diacritics). Write a small Node.js script (`fs.readFileSync/writeFileSync`, `'utf8'`) in `C:\Users\stefan\AppData\Local\Temp\opencode\` instead. `rg` is not installed; use `Select-String` or Node.
- `&&` doesn't work; use `;` or `if ($?) { }`.

## Key architecture facts

- **Domain ownership** (`docs/architecture/DOMAIN_OWNERSHIP.md`, `INVARIANTS.md`): only the owning resource writes its tables. Cross-resource reads go through `sunset_core` callbacks.
- **Sessions framework**: `sunset_sessions` is the canonical session service (state machine, deadlines, downed/jail/drop triggers). Jobs (`sunset_jobs`: trucker/fisherman/courier/garbage/mechanic), taxi, robbery, and license exams all mirror into it via `CreateSession`/`Transition`/`EndSession`/`SetEntity` + `onEndEvent` hooks. New activity systems should follow this pattern.
- **NUI flow**: client Lua → `exports.sunset_ui:Send(action, payload)` → `web/js/app.js` switch dispatches to panels/modules → JS `post(action, data)` → `nui_bridge.lua` → `TriggerEvent('sunset:nui:<action>')` on the client. Every `post()` name must have a matching `AddEventHandler('sunset:nui:...')` (check-nui-bridge.js enforces).
- **UI focus**: `exports.sunset_ui:SetFocus(bool, bool, keepInput, owner)` in `sunset_ui/client/main.lua`. Modal UIs trap the cursor; any panel opened with focus MUST have a guaranteed close path (ESC handler, close button, force-close on death `closeAllModalUi` in sunset_death). Fullscreen overlays need their own cancel affordance inside the overlay (trade countdown bug).
- **FiveM exports quirk**: `exports.res.X` returns a truthy proxy even for undefined exports — guard with `GetResourceState() == 'started'` + `pcall`, never with `if exports.x:Y`.
- **Server exports**: use colon-call form `exports.sunset_sessions:Method(...)` — FiveM proxy drops `self` otherwise (arg shift bug, see commit 889e66f).

## Product/language rule

All player-facing strings (notifications, command help, UI labels) in **English**. Romanian remains only in code comments and some staff-facing Discord embeds. Commands: English canonical (`/armory`, `/intervene`), occasional Romanian aliases accepted (`/armurie`, `/portbagaj`).

## Gameplay domain notes (hard-won)

- Turf wars (`sunset_turfs`): kill points score ONLY on actual death via `scoreWarKill` at war respawn (hits merely record last aggressor). Zone scoring excludes dead/downed players. `/intervene` works ONLY on neutral (unowned) captures — intervener becomes defender; owner-vs-attacker wars cannot be intervened. Rally window = no zone scoring for `RallyDelaySec`.
- Firearm license gate: `weaponDamageEvent` handler in `sunset_licenses/server/main.lua` cancels damage when shooter lacks license (war combat exempt). This system is known-flaky (stale caches, `NetworkGetEntityOwner` unreliable); owner has requested it disabled — check current state before touching.
- Inventory capacity: effective max = `Sunset.Config.MaxWeight` + `CapacityBonus[src]` (duffel bag during robbery). Server sends effective capacity as 5th arg of `sunset:client:inventoryUpdate`; keep client/UI in sync with it.
- Vehicles: personal cars spawn ONLY at garage spawn or explicit `/park` coords; store/disconnect must NULL the parked_* columns.
- Trade: two-phase row transfer inside one `MySQL.startTransaction` (consume both sides, then insert) to avoid UNIQUE(character_id,slot) collisions.

## Docs to consult (do not re-derive)

- `docs/audit/MASTER_AUDIT.md` + `AUDIT_STATE.md` — full audit register, phase fixes tagged `[AUDIT Px-xx]` in source, deferred backlog, 15 runtime tests.
- `docs/architecture/` — RESOURCE_MAP, DOMAIN_OWNERSHIP, INVARIANTS, EVENT_CONTRACTS.
- `docs/clothing/CLOTHING_IMPLEMENTATION_REPORT.md` — clothing/outfit system + 12 runtime tests.
- `sql/` — numbered migrations (45 so far), applied automatically by deploy.sh; add `sql/NN-name.sql` for schema changes, never edit applied files.

## Repo hygiene

- `funpay-setup.cjs`, `server redesign/` (HTML mockups), root `*.dll`, `FXServer.exe` — local artifacts, do not touch/commit.
- Never commit: `server.cfg` secrets (license key, DB passwords), `*.key` files.
- Owner communicates in Romanian; reply in Romanian. Code, UI text and commit messages in English.
