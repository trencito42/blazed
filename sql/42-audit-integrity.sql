-- 42: Audit integrity hardening (docs/audit/MASTER_AUDIT.md Phase 5)
-- Adds missing constraints found by the production-readiness audit.
-- Safe to re-run only if the guards below pass; run once on live DB.

-- P5-03/P5-25: container_inventory had no uniqueness: concurrent deposits of a
-- new item created duplicate rows and racing slot numbers.
-- Merge any pre-existing duplicate rows before adding the constraint.
UPDATE `container_inventory` c
JOIN (
    SELECT `container_type`, `container_id`, `item`, MIN(`id`) AS keep_id, SUM(`count`) AS total
    FROM `container_inventory`
    GROUP BY `container_type`, `container_id`, `item`
    HAVING COUNT(*) > 1
) d ON c.`id` = d.keep_id
SET c.`count` = d.total;

DELETE c FROM `container_inventory` c
JOIN (
    SELECT `container_type`, `container_id`, `item`, MIN(`id`) AS keep_id
    FROM `container_inventory`
    GROUP BY `container_type`, `container_id`, `item`
    HAVING COUNT(*) > 1
) d ON c.`container_type` = d.`container_type` AND c.`container_id` = d.`container_id`
    AND c.`item` = d.`item` AND c.`id` <> d.keep_id;

ALTER TABLE `container_inventory`
    ADD UNIQUE KEY `uk_container_item` (`container_type`, `container_id`, `item`);

-- P5-25: index for audit queries filtering by reason (money_transactions scans).
ALTER TABLE `money_transactions`
    ADD KEY `idx_reason` (`reason`);

-- P5-09: orphan-prone ownership columns. SET NULL keeps rows alive but frees
-- them for re-sale instead of being ghost-owned by deleted characters.
-- Clear pre-existing dangling references first or the FK creation fails.
UPDATE `properties` p LEFT JOIN `characters` c ON c.`id` = p.`owner_character_id`
SET p.`owner_character_id` = NULL WHERE p.`owner_character_id` IS NOT NULL AND c.`id` IS NULL;

UPDATE `player_businesses` b LEFT JOIN `characters` c ON c.`id` = b.`owner_character_id`
SET b.`owner_character_id` = NULL WHERE b.`owner_character_id` IS NOT NULL AND c.`id` IS NULL;

DELETE t FROM `lottery_tickets` t LEFT JOIN `characters` c ON c.`id` = t.`character_id`
WHERE c.`id` IS NULL;

UPDATE `turfs` t LEFT JOIN `clans` cl ON cl.`id` = t.`owner_clan_id`
SET t.`owner_clan_id` = NULL WHERE t.`owner_clan_id` IS NOT NULL AND cl.`id` IS NULL;

ALTER TABLE `properties`
    ADD CONSTRAINT `fk_property_owner` FOREIGN KEY (`owner_character_id`)
    REFERENCES `characters` (`id`) ON DELETE SET NULL;

ALTER TABLE `player_businesses`
    ADD CONSTRAINT `fk_business_owner` FOREIGN KEY (`owner_character_id`)
    REFERENCES `characters` (`id`) ON DELETE SET NULL;

ALTER TABLE `lottery_tickets`
    ADD CONSTRAINT `fk_lottery_char` FOREIGN KEY (`character_id`)
    REFERENCES `characters` (`id`) ON DELETE CASCADE;

ALTER TABLE `turfs`
    ADD CONSTRAINT `fk_turf_clan` FOREIGN KEY (`owner_clan_id`)
    REFERENCES `clans` (`id`) ON DELETE SET NULL;
