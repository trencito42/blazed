# ROLLBACK — How to Undo a Bad Deploy

## Current deployed state (reference point)

- VPS: `193.33.167.216`, stack in `/opt/blazed`, Docker Compose (`blazed-fivem-1`, `blazed-mariadb-1`).
- Last known-good commit on `origin/main`: `2252885` (audit fixes + sql/42 applied, server healthy, 0 startup errors).
- DB schema: migrations 01–42 applied (recorded in `schema_migrations`).

## Scenario A — Bad CODE deploy (resources/logic broken, DB schema unchanged)

Fastest: roll the git tree back and restart FiveM only (DB untouched).

```bash
ssh -i ~/.ssh/sshxodo root@193.33.167.216
cd /opt/blazed
# 1. Find the last good commit (see "Current deployed state" or git log)
git log --oneline -10
# 2. Roll back the working tree to it
git fetch --depth 50 origin main
git reset --hard <last-good-sha>
# 3. Restart ONLY the fivem container (mariadb keeps running, data safe)
docker compose up -d --force-recreate fivem
# 4. Watch startup for errors
docker compose logs -f fivem | grep -iE 'error|exception|fail'
```

To redeploy the fixed code later: `git reset --hard origin/main && docker compose up -d --force-recreate fivem` (or `./deploy.sh`).

## Scenario B — Bad MIGRATION (sql/NN corrupts or breaks schema)

**Prevention (do this BEFORE any future destructive migration):**
```bash
ssh -i ~/.ssh/sshxodo root@193.33.167.216
cd /opt/blazed && set -a && . ./.env && set +a
docker compose exec -T -e MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb \
  mariadb-dump -uroot --single-transaction --routines "$MARIADB_DATABASE" \
  > /opt/backups/pre-migration-$(date +%F-%H%M).sql
```

**If a migration broke things and you have a backup:**
```bash
cd /opt/blazed && set -a && . ./.env && set +a
# restore (DESTRUCTIVE — replaces current DB with the backup)
docker compose exec -T -e MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb \
  mariadb -uroot "$MARIADB_DATABASE" < /opt/backups/pre-migration-<timestamp>.sql
# remove the bad migration's schema_migrations row so it can be re-attempted after fixing
# (only if you will re-run a corrected version)
```

**If a migration was additive and non-destructive** (like sql/42: ADD CONSTRAINT/KEY, column MODIFY): rolling back the *code* is usually enough; the extra constraints/indexes are harmless. To drop them explicitly:
```sql
ALTER TABLE turfs DROP FOREIGN KEY fk_turf_clan;
ALTER TABLE lottery_tickets DROP FOREIGN KEY fk_lottery_char;
ALTER TABLE player_businesses DROP FOREIGN KEY fk_business_owner;
ALTER TABLE properties DROP FOREIGN KEY fk_property_owner;
ALTER TABLE money_transactions DROP INDEX idx_reason;
ALTER TABLE container_inventory DROP INDEX uk_container_item;
DELETE FROM schema_migrations WHERE name = '42-audit-integrity.sql';
```
⚠️ Dropping `uk_container_item` re-opens the container dupe (INVARIANT I3). Only do this if the constraint itself is the problem.

## Scenario C — Full stack won't come up

```bash
ssh -i ~/.ssh/sshxodo root@193.33.167.216
cd /opt/blazed
docker compose ps                       # what's unhealthy?
docker compose logs --tail 100 mariadb  # DB up?
docker compose logs --tail 100 fivem    # resource error?
# nuclear option: rebuild fivem image from current tree
docker compose up -d --build --force-recreate fivem
```
MariaDB data lives in the `mariadb_data` volume — recreating containers does NOT touch it. Only `docker volume rm` loses data.

## Scenario D — Revert to a specific previous release (tag-based, recommended going forward)

Adopt release tags so rollback is exact:
```bash
# before each production deploy:
git tag -a rel-$(date +%F) -m "release" && git push origin --tags
# to roll back to a tag:
git reset --hard rel-<date> && docker compose up -d --force-recreate fivem
```

## Post-rollback verification

1. `docker compose ps` → both containers `Up (healthy)`.
2. `docker compose logs fivem | grep -i error` → none.
3. `curl -s http://127.0.0.1:30120/info.json` → returns resource list.
4. Connect in-game, confirm spawn + money + inventory load.
5. Re-run `scripts/apply-migrations.sh` → all "already applied" (no drift).

## What NOT to do

- Don't `git pull` a broken branch into prod without a backup if migrations are involved.
- Don't `docker volume rm mariadb_data` (that's the live DB).
- Don't hand-edit `server.cfg`/`.env` on the VPS to "fix" a deploy — change it in the repo/template and redeploy (secrets stay in `.env`, never committed).
- Don't skip the schema_migrations row cleanup if you restored a pre-migration backup, or the runner will think the migration is applied when the schema isn't.
