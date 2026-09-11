ALTER TABLE `characters`
    ADD COLUMN IF NOT EXISTS `active_minutes_since_payday` SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER `paydays_received`;

CREATE TABLE IF NOT EXISTS `payday_runs` (
    `character_id` INT UNSIGNED NOT NULL,
    `period_key` CHAR(10) NOT NULL,
    `played_minutes` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `status` VARCHAR(24) NOT NULL,
    `gross` INT UNSIGNED NOT NULL DEFAULT 0,
    `tax` INT UNSIGNED NOT NULL DEFAULT 0,
    `net` INT UNSIGNED NOT NULL DEFAULT 0,
    `rent` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`, `period_key`),
    KEY `idx_payday_period` (`period_key`, `status`),
    CONSTRAINT `fk_payday_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
