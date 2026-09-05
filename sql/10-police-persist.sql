-- Police-specific tables (wanted/jail use sql/09-dispatch-wanted-jail.sql)

CREATE TABLE IF NOT EXISTS `police_confiscations` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `officer_character_id` INT UNSIGNED NOT NULL,
    `target_character_id` INT UNSIGNED NOT NULL,
    `items` JSON NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `target_character_id` (`target_character_id`),
    KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
