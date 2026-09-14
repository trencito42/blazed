-- 51-impound.sql — vehicle impound system
CREATE TABLE IF NOT EXISTS `impounded_vehicles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `vehicle_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `impounded_by` INT UNSIGNED NULL,
    `impounded_by_name` VARCHAR(64) NULL,
    `reason` VARCHAR(255) NOT NULL DEFAULT 'No reason given',
    `fee` INT UNSIGNED NOT NULL DEFAULT 500,
    `daily_fee` INT UNSIGNED NOT NULL DEFAULT 100,
    `impounded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `released_at` TIMESTAMP NULL DEFAULT NULL,
    `status` ENUM('impounded','released','sold') NOT NULL DEFAULT 'impounded',
    PRIMARY KEY (`id`),
    INDEX `idx_vehicle` (`vehicle_id`),
    INDEX `idx_character` (`character_id`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
