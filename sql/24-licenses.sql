DELIMITER $$

DROP PROCEDURE IF EXISTS sunset_migrate_licenses_v2$$
CREATE PROCEDURE sunset_migrate_licenses_v2()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_licenses' AND COLUMN_NAME = 'issued_at_payday'
    ) THEN
        ALTER TABLE `character_licenses`
            ADD COLUMN `issued_at_payday` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `issued_at`;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_licenses' AND COLUMN_NAME = 'expires_at_payday'
    ) THEN
        ALTER TABLE `character_licenses`
            ADD COLUMN `expires_at_payday` INT UNSIGNED NULL AFTER `issued_at_payday`;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_licenses' AND COLUMN_NAME = 'issued_by_character_id'
    ) THEN
        ALTER TABLE `character_licenses`
            ADD COLUMN `issued_by_character_id` INT UNSIGNED NULL AFTER `expires_at_payday`;
    END IF;
END$$

DELIMITER ;

CALL sunset_migrate_licenses_v2();
DROP PROCEDURE IF EXISTS sunset_migrate_licenses_v2;
