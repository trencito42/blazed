# Robbery system

The luxury-store robbery is server-authoritative. A player needs one robbery point,
a lockpick, the configured number of on-duty police, and must be at the configured
entrance. The lockpick is an access requirement and is not consumed.

## Security invariants

- One character and one location can have only one starting/active run at a time.
- Cooldowns are stored in `robbery_cooldowns`, keyed by character and location.
- Generated loot is reserved before inventory writes and carries its run and loot IDs.
- Loot from failed, cancelled, disconnected, or abandoned runs is removed.
- Only loot belonging to a `success` run can be offered to the fence.
- Fence quotes are stable, expire after 30 seconds, and bind character, inventory row,
  item, run, and payment. Item consumption and cash credit use one database statement.
- Wanted state is persisted on the first smash, while police notification respects the
  hack delay and does not reveal the suspect early.
- Store doors retain collision, unlock for an active run, and relock afterward.
- `robbery_runs` and `robbery_audit` provide recovery and investigation history.

Migration `sql/16-robbery-security.sql` must be applied before this resource starts.
The container entrypoint applies it automatically during the next deployment.

## Admin verification

With robbery debug enabled, use `/robdebug reset`, `/robdebug points 5`, and
`/robdebug force`. Verify success, death/disconnect cleanup, cooldown persistence,
an expired fence quote, and two rapid clicks on the same loot item.
