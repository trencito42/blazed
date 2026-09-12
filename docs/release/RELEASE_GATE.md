# RELEASE_GATE — Production-Readiness Criteria

A phase may deploy only when every applicable gate is PASS with evidence. "It parses / resources start" is NOT sufficient — stability is proven via invariants, automated checks, and adversarial runtime tests.

## Gate checklist

| # | Gate | Current status | Evidence / blocker |
|---|---|---|---|
| G1 | No CRITICAL/HIGH correctness or security findings open | **PASS (code)** | all CRIT/HIGH from audit fixed; see MASTER_AUDIT findings register. Residual backlog items are MED/LOW or perf |
| G2 | All migrations pass on a production-like DB copy | **PARTIAL** | sql/42 applied clean on live VPS (idempotent re-run verified). Not yet tested on a *clone* before live — adopt clone-first for future destructive migrations |
| G3 | All syntax/static checks pass | **PASS** | 257 Lua, 53 JS, audit-static.ps1 |
| G4 | Core gameplay regression matrix passes | **FAIL/BLOCKED** | REGRESSION_MATRIX §3 R1-R30 + §4 A1-A7 all need in-game execution — NOT done (static-only env) |
| G5 | Economy invariants pass | **PARTIAL** | code enforces M1-M7; needs live DB invariant queries (negative balance, dup plate, orphan FK) — script TODO |
| G6 | Reconnect/restart tests pass | **BLOCKED** | R15/R16/R23/R24 + session restart behavior need runtime |
| G7 | No known NUI focus traps | **PASS (code)** | carjack hang, ticket-receive, modalSuperseded fixed + failsafes; needs R17-R19 visual confirm |
| G8 | No raw nil / generic callback errors reach users | **PARTIAL** | bus wraps handler errors; per-callback message audit not exhaustive — spot-check during R-tests |
| G9 | No unexplained resource errors in logs | **PASS** | VPS startup: 0 errors, 50 resources started |
| G10 | Performance within budgets | **BLOCKED** | PERFORMANCE_BASELINE budgets are TARGET; not yet profiled on populated server |
| G11 | Rollback procedure ready | **PASS** | see ROLLBACK.md |
| G12 | OneSync actually enabled at runtime | **BLOCKED** | txAdmin controls it; must confirm ON in txAdmin settings page (required for damage/explosion gating) |

## Overall verdict

**NOT YET a clean production release by these gates.** The *code* is hardened (G1/G3/G7/G9/G11 pass), and the VPS is up healthy with migrations applied. But the brief's own rule — "prove stability through adversarial runtime tests, not because it parses" — means **G4, G6, G10, G12 are BLOCKED** until someone runs the server with real/bot clients and executes REGRESSION_MATRIX §3-§4.

**What this means practically:**
- Safe to run as a **controlled test / soft launch** with staff, watching logs.
- NOT safe to open to uncontrolled public until G4+G6 pass and G12 (OneSync) is confirmed.
- Highest-value runtime confirmations first: R4/R5 (carjack money), R1/R2/R3 (XSS), R8 (jailed payday), R13/R14 (vehicle state), R17 (UI hang the user reported).

## Per-phase gates (execution plan mapping)

| Phase | Gate to pass before deploying it |
|---|---|
| Phase 0 (audit patch) | DONE — deployed to VPS, migrations applied, 0 startup errors |
| Phase 1 (critical fixes) | DONE — all CRIT/HIGH code-fixed; G4 runtime confirmation pending |
| Phase 2 (canonical services, sessions, invariants, error contract) | new resource start/stop tests + session unit tests + bridge-completeness script + test-driver |
| Phase 3 (repair existing systems) | REGRESSION_MATRIX §3 rows for each repaired system |
| Phase 4 (Trucker vertical slice) | full §5 vertical-slice matrix row for Trucker (all 19 handlers) |
| Phase 5-8 (jobs/factions/quests/crime) | per-activity vertical-slice rows + economy invariant queries |
| Phase 9 (RC + load test) | ALL gates G1-G12 PASS with evidence, perf within budget at 48 players |

## Never claim "bug-free"

Report instead: what was tested (this file + REGRESSION_MATRIX), what was NOT (all BLOCKED rows), evidence (logs/scripts), known risks (backlog in MASTER_AUDIT + AUDIT_STATE), rollback plan (ROLLBACK.md).
