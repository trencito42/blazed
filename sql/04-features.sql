USE `sunsetmp`;

ALTER TABLE `accounts`
    ADD COLUMN IF NOT EXISTS `premium_points` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `password_salt`,
    ADD COLUMN IF NOT EXISTS `admin_level` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `premium_points`;

ALTER TABLE `properties`
    ADD COLUMN IF NOT EXISTS `exit_pos` JSON NULL AFTER `interior_pos`;

UPDATE `properties` SET `exit_pos` = `entry` WHERE `exit_pos` IS NULL;

-- Phone messages
CREATE TABLE IF NOT EXISTS `phone_messages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sender_character_id` INT UNSIGNED NOT NULL,
    `receiver_character_id` INT UNSIGNED NOT NULL,
    `message` VARCHAR(256) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `read_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `receiver_character_id` (`receiver_character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Character licenses (beyond inventory items)
CREATE TABLE IF NOT EXISTS `character_licenses` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `license_type` VARCHAR(32) NOT NULL,
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `char_license` (`character_id`, `license_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
