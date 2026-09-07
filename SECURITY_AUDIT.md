# SunsetMP — Security Audit

**Audit date:** 2026-09-07  
**Starting commit:** `eff7076`  
**Scope:** Static code review of `resources/[sunset]`, `deploy.sh`, SQL migrations

---

## Summary

| Severity | Count | Release impact |
|----------|-------|----------------|
| Critical | 0 in tracked git* | — |
| High | 4 | 2 fixed locally; 2 require live hardening |
| Medium | 6 | Documented |
| Low | 4 | Acceptable for beta |

\* `server.cfg` is `.gitignore`d; local dev files may contain keys — do not commit.

---

## Findings

### HIGH

#### H1 — Migration failures ignored during deploy
- **Resource:** `deploy.sh`
- **Repro:** Run deploy with broken SQL
- **Root cause:** Errors logged as warnings; `docker compose up` continued
- **Fix:** Exit 1 on migration failure; optional `DEPLOY_IGNORE_MIGRATION_ERRORS=1`
- **Verification:** Code change in `deploy.sh`
- **Status:** **FIXED** (local)

#### H2 — Blaze Pass claim before persist
- **Resource:** `sunset_pass/server/main.lua`
- **Repro:** Grant succeeds, DB save fails → duplicate claim on retry
- **Root cause:** `grantReward()` before `saveRow()`
- **Fix:** Persist claim first; rollback claim if grant fails
- **Verification:** Code review
- **Status:** **FIXED** (local)

#### H3 — Client-reported death/downed chain
- **Resource:** `sunset_death/server/main.lua`
- **Events:** `sunset:server:playerDied`, `sunset:death:enteredDowned`, `sunset:server:bleedoutExpired`, `sunset:server:requestRespawn`
- **Risk:** Spoof respawn, skip downed timer
- **Fix:** Not implemented this pass — requires server-side health/death corroboration
- **Status:** **BLOCKED** — needs gameplay design + native checks

#### H4 — Plaintext quick-login passwords in client KVP
- **Resource:** `sunset_auth/client/accounts.lua`
- **Risk:** Local credential storage on client machine
- **Fix:** Not changed — use token-based saved accounts only
- **Status:** **OPEN** — document for players; consider refresh tokens

### MEDIUM

#### M1 — Client-driven needs tick
- **Resource:** `sunset_needs/server/main.lua` — `sunset:server:needsTick`
- **Mitigation:** 50s cooldown only
- **Recommendation:** Server-authoritative decay on interval

#### M2 — Chat command spam
- **Resource:** `sunset_chat`
- **Fix:** Rate limits on `chat:send` (350ms) and `runCommand` (400ms)
- **Status:** **FIXED** (local)

#### M3 — Generic callback gateway
- **Resource:** `sunset_core/server/main.lua` — `sunset:server:triggerCallback`
- **Risk:** Any registered callback invokable; security per handler
- **Recommendation:** Audit each `RegisterCallback` (ongoing)

#### M4 — T-chat router sent server commands to client
- **Resource:** `sunset_chat/server/command_router.lua`
- **Risk:** Commands silently failed or wrong handler
- **Fix:** `tryRunResourceCommand` + server MOTD paths
- **Status:** **FIXED** (local)

#### M5 — `/robdebug points` (admin + debug flag)
- **Resource:** `sunset_robbery/server/main.lua`
- **Mitigation:** `SunsetRobbery.Debug` + admin check
- **Recommendation:** Disable debug in production config

#### M6 — SQL injection surface
- **Scan:** Queries use parameterized `MySQL.*.await` with `?` placeholders
- **Status:** **PASS** on reviewed paths; avoid dynamic column names from client

### LOW

- Mechanic `dispatchOffer` accepts client `callData` — on-duty gate only
- `sunset:chat:send` — no character auth check beyond loaded player (proximity only)
- `sunset:server:flowTrace` — debug logging, rate-limited
- Admin `resolvePlayer` substring name match — ambiguous targets

---

## Secrets scan

| Location | Finding |
|----------|---------|
| `server.cfg` | Gitignored — keep out of repo |
| `.env.example` | Placeholders only |
| Sunset Lua | No hardcoded `cfxk_` in tracked resources |
| Auth | Passwords hashed server-side (`sunset_core/shared/password.lua`) |

---

## Recommendations (priority order)

1. Deploy local fixes (router, MOTD, pass, deploy.sh).
2. Harden death/downed server events (H3).
3. Remove or encrypt saved-account passwords (H4).
4. Add regression script: `scripts/audit-static.ps1` (fix bracket paths).
5. Per-callback security pass on economy NUI endpoints.
