INSERT IGNORE INTO `societies` (`name`, `label`, `balance`) VALUES
    ('lsfd', 'Los Santos Fire Dept', 12000),
    ('sunset_cartel', 'Sunset Cartel', 0),
    ('night_syndicate', 'Night Syndicate', 0);

CREATE TABLE IF NOT EXISTS `faction_fines` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `officer_character_id` INT UNSIGNED NOT NULL,
    `target_character_id` INT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL,
    `reason` VARCHAR(128) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
