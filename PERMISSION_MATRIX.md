# SunsetMP — Permission Matrix (verified from code)

**Base commit audited:** `eff7076` + local uncommitted fixes  
**Legend:** Auth = server-side enforcement required. Client checks are UX only.

---

## Admin commands (`SunsetAdmin.Commands`)

| Command | Min admin level | Alternate access | Denial message source |
|---------|-----------------|------------------|------------------------|
| kick, tp, bring, coords, setcp, delcp, gotocp, gotoloc, speed, astats | 2 | — | `CommandDenyAdmin` |
| heal, revive | 2 | Faction perm `heal`/`revive` on duty (EMS/Fire) | `CommandDenyHeal` / `CommandDenyRevive` |
| ban, unban, car, noclip, god, announce, setadmin, givecar, giveitem, givegun, setleader, removeleader, acreatehouse, ahouseedit, setstat, setjobstat, setrob | 3+ | — | `CommandDenyAdmin` |
| setadmin | 5 | — | Owner only |

**Resource:** `sunset_admin/server/commands.lua`, `sunset_admin/shared/config.lua`

---

## Faction actions

| Action | Who | Duty | Rank/perm | Server handler |
|--------|-----|------|-----------|----------------|
| `/f` faction chat | Faction member | No | In faction | `sunset_factions/server/chat.lua` |
| `/r` radio | Faction member | **Yes** | In faction | same |
| `/d` dept radio | LSPD/EMS/LSFD | **Yes** | Emergency dept | same |
| `/gov` | LSPD/EMS/LSFD | **Yes** | Emergency dept | same |
| `/duty` | Faction member | — | — | Client → server duty toggle |
| `/finvite`, `/fpromote`, `/fgiverank`, `/funinvite`, `/fwarn`, `/fmotd` | Grade with perm | Usually off-duty OK | `invite`, `giverank`, `fmotd`, etc. | Callbacks in `leaders.lua` |
| `/cuff`, `/arrest`, `/ticket`, radar | Police on duty | **Yes** | Police perms | `client/police.lua` + server validation |
| `/heal`, `/revive`, `/stabilize` | EMS/Fire/admin | **Yes** (faction) | `heal`/`revive`/`stabilize` | `sunset_admin` + `sunset_factions/server/ems.lua` |
| Faction vehicles | Faction member | **Yes** | Faction match | `sunset_factions` + `sunset_vehicles` |
| Leave faction | Member | — | — | Must not clear civilian job |

**HQ join via E:** Membership requires leader invite (`/finvite` / `/acceptfaction`), not proximity alone.

---

## Clan actions

| Action | Role | Server callback / command |
|--------|------|---------------------------|
| View panel `/clan`, `/group` | Anyone (guest = create tab) | `sunset:clanDashboard` |
| `/c` clan chat | Member | `sunset_clans/server/chat.lua` |
| `/cmotd` read | Member | `RunMotdCommand` / `sunset:clanGetMotd` |
| `/cmotd` set | Officer (rank ≥5) or owner | `sunset:clanManage` action `motd` |
| Invite | Officer+ | `clanManage` `invite` |
| Kick, warn, rank | Officer+ (rank rules) | `clanManage` |
| Settings (tag, color) | **Leader only** | `clanManage` `settings` |
| Rank labels | **Leader only** | `clanManage` `rankLabels` |
| Dissolve | **Leader only** | `clanManage` `dissolve` |
| Leave | Member (not forced) | `clanManage` `leave` |

**Leaving clan:** Does not modify faction or civilian job (`sunset_clans`).

---

## Civilian jobs

| Action | Requirement | Server |
|--------|-------------|--------|
| `/jobs`, `/work`, `/jobhelp`, `/skills` | Character loaded | `sunset_jobs` |
| Job rewards / completion | Active session server state | Per-job server modules |
| Fisherman sell | Inventory + proximity | `sunset_jobs` fisherman server |
| Trucker trailer | Server validates attachment | `sunset_jobs` trucker |

---

## Economy / NUI mutations (must be server-authoritative)

| Surface | Validation |
|---------|------------|
| `sunset:buyLevel` / `/buylevel` | RP, cash, lock per source |
| `sunset:buyProperty` | Level, price, stock, atomic SQL |
| `sunset:pass:claim` | Tier unlock, premium, persist-before-grant (fixed locally) |
| `sunset:robbery:*` | Session state, cooldown, police count |
| Shop/crafting callbacks | Price from config, not client |
| `setcash`/`setbank`/`setstat` | Admin level 3+, immediate SQL |

---

## Chat / commands

| Entry | Rate limit | Auth |
|-------|------------|------|
| `sunset:chat:send` | 350ms (fixed locally) | Character proximity |
| `sunset:chat:runCommand` | 400ms (fixed locally) | Router + per-command |
| `/help` | — | `sunset:getHelp` — never returns nil categories; error if no character |

---

## Known gaps (not fully hardened)

| Issue | Severity | Notes |
|-------|----------|-------|
| `sunset:server:needsTick` | Medium | Client-driven drain |
| Death/downed events | High | Client-reported; needs server corroboration |
| `sunset:server:triggerCallback` | Medium | Per-callback auth varies |
| Mechanic `dispatchOffer` | Low | Client payload; on-duty gate only |

See `SECURITY_AUDIT.md` for full list.
