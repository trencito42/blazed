DELIMITER $$

DROP PROCEDURE IF EXISTS sunset_migrate_clan_ranks$$
CREATE PROCEDURE sunset_migrate_clan_ranks()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clans' AND COLUMN_NAME = 'rank_labels'
    ) THEN
        ALTER TABLE `clans` ADD COLUMN `rank_labels` JSON NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clan_members' AND COLUMN_NAME = 'warns'
    ) THEN
        ALTER TABLE `clan_members` ADD COLUMN `warns` TINYINT UNSIGNED NOT NULL DEFAULT 0;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clan_members'
        AND COLUMN_NAME = 'rank' AND COLUMN_TYPE LIKE 'enum%'
    ) THEN
        ALTER TABLE `clan_members` ADD COLUMN `rank_num` TINYINT UNSIGNED NOT NULL DEFAULT 1;
        UPDATE `clan_members` SET `rank_num` = CASE `rank`
            WHEN 'leader' THEN 7
            WHEN 'officer' THEN 5
            ELSE 1
        END;
        ALTER TABLE `clan_members` DROP COLUMN `rank`;
        ALTER TABLE `clan_members` CHANGE COLUMN `rank_num` `rank` TINYINT UNSIGNED NOT NULL DEFAULT 1;
    END IF;
END$$

DELIMITER ;

CALL sunset_migrate_clan_ranks();
DROP PROCEDURE IF EXISTS sunset_migrate_clan_ranks;
