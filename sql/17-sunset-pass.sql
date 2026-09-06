-- Sunset Pass — per-character seasonal battle pass progress.
CREATE TABLE IF NOT EXISTS `character_pass_progress` (
    `character_id` INT UNSIGNED NOT NULL,
    `season_id` VARCHAR(32) NOT NULL DEFAULT 'season_01',
    `xp` INT UNSIGNED NOT NULL DEFAULT 0,
    `premium` TINYINT(1) NOT NULL DEFAULT 0,
    `claimed` JSON NULL,
    `mission_progress` JSON NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`, `season_id`),
    KEY `idx_pass_season` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
