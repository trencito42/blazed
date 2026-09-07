# SunsetMP — Manual Multiplayer Test Plan

Use **two real clients** (or one client + admin observer). Mark each: **PASS** | **FAIL** | **BLOCKED** | **N/A**.

---

## Setup

- [ ] Client A: civilian account
- [ ] Client B: second account or faction test character
- [ ] Admin client optional (level 3+)
- [ ] Note server build commit before test

---

## 1. Authentication & spawn

| # | Test | A | B |
|---|------|---|---|
| 1.1 | Login wrong password → clear error | | |
| 1.2 | Register duplicate username → rejected | | |
| 1.3 | Character select → spawn → no frozen NUI | | |
| 1.4 | Last location spawn — not underground | | |
| 1.5 | Property interior — no cross-player bleed | | |
| 1.6 | Reconnect mid-login — recover cleanly | | |

---

## 2. Chat & commands (T-key)

| # | Test | A | B |
|---|------|---|---|
| 2.1 | `/help` — categories, no nil | | |
| 2.2 | `/cmotd` read + set (officer) | | |
| 2.3 | `/fmotd` read + set (leader) | | |
| 2.4 | Clan UI → Save MOTD | | |
| 2.5 | `/buylevel` from T-chat | | |
| 2.6 | `/f` only visible to same faction | | |
| 2.7 | `/accept` faction vs `/accept taxi 1` dispatch | | |
| 2.8 | EMS `/heal` without admin level | | |

---

## 3. Replication (requires 2 clients)

| # | Test | A | B |
|---|------|---|---|
| 3.1 | A cuffs B — both see cuff state | | |
| 3.2 | A drags B — position sync | | |
| 3.3 | EMS revive B — downed cleared both sides | | |
| 3.4 | Faction vehicle — B denied if wrong faction | | |
| 3.5 | Taxi fare — payment both clients | | |
| 3.6 | Disconnect during cuff — cleanup | | |

---

## 4. Economy persistence

| # | Test | Steps | Result |
|---|------|-------|--------|
| 4.1 | Buy property fail (low level) — money unchanged | | |
| 4.2 | Buy property success — reconnect persists | | |
| 4.3 | Pass claim — no double reward on spam click | | |
| 4.4 | `/buylevel` — RP/cash persist reconnect | | |
| 4.5 | Admin setcash — persists reconnect | | |

---

## 5. Faction / clan / job isolation

| # | Test | Result |
|---|------|--------|
| 5.1 | Leave clan — faction + job unchanged | |
| 5.2 | Leave faction — job unchanged | |
| 5.3 | Clan `/c` not visible outside clan | |
| 5.4 | Off-duty police — cuff denied with reason | |

---

## 6. Jobs (one client minimum, two for delivery handoff)

| Job | Start | Complete | Disconnect cleanup |
|-----|-------|----------|-------------------|
| Trucker | | | |
| Garbage | | | |
| Courier | | | |
| Fisherman | | | |
| Mechanic | | | |

---

## 7. Police / wanted / jail

| # | Test | Result |
|---|------|--------|
| 7.1 | Wanted stars visible (max 5 GTA) | |
| 7.2 | Radar — stationary, valid vehicle only | |
| 7.3 | Jail reconnect — still jailed | |
| 7.4 | Ticket accept/refuse | |

---

## 8. NUI stress

| # | Test | Result |
|---|------|--------|
| 8.1 | Open/close M-menu rapidly — no stuck focus | |
| 8.2 | ESC closes clan/faction panels | |
| 8.3 | 1280×720 — no panel overflow | |
| 8.4 | HUD hidden during login/spawn | |

---

## Sign-off

| Role | Tester | Date | Build |
|------|--------|------|-------|
| QA | | | |
| Dev | | | |

**Release gate:** All P0 rows in `RELEASE_AUDIT.md` must be PASS or FIXED AND VERIFIED before production label.
