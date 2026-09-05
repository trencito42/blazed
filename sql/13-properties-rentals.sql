-- Full SA:MP-style house ownership and rental model.
ALTER TABLE `properties`
    ADD COLUMN IF NOT EXISTS `minimum_level` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `price`,
    ADD COLUMN IF NOT EXISTS `description` VARCHAR(160) NULL AFTER `minimum_level`,
    ADD COLUMN IF NOT EXISTS `for_sale` TINYINT(1) NOT NULL DEFAULT 1 AFTER `locked`,
    ADD COLUMN IF NOT EXISTS `rent_enabled` TINYINT(1) NOT NULL DEFAULT 0 AFTER `for_sale`,
    ADD COLUMN IF NOT EXISTS `rent_price` INT UNSIGNED NOT NULL DEFAULT 100 AFTER `rent_enabled`,
    ADD COLUMN IF NOT EXISTS `max_renters` TINYINT UNSIGNED NOT NULL DEFAULT 3 AFTER `rent_price`,
    ADD COLUMN IF NOT EXISTS `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `max_renters`,
    ADD COLUMN IF NOT EXISTS `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `enabled`,
    ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`;

CREATE TABLE IF NOT EXISTS `property_rentals` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `property_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `rent_price` INT UNSIGNED NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_paid_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `one_rental_per_character` (`character_id`),
    KEY `active_property` (`property_id`, `active`),
    CONSTRAINT `fk_property_rental_property` FOREIGN KEY (`property_id`) REFERENCES `properties` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_property_rental_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The old seed data placed players back at the exterior and was never a real interior.
UPDATE `properties`
SET `interior` = 'standard',
    `interior_pos` = '{"x":266.03,"y":-1007.26,"z":-101.01,"w":357.0}'
WHERE `id` IN (1, 2, 3);
