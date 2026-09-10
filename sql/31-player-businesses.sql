-- Player-owned businesses (shops / locations — not inventory items)
CREATE TABLE IF NOT EXISTS `player_businesses` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `shop_key` VARCHAR(64) NOT NULL,
    `business_type` VARCHAR(16) NOT NULL DEFAULT 'shop',
    `label` VARCHAR(128) NOT NULL,
    `catalog_key` VARCHAR(64) NOT NULL DEFAULT '',
    `price` INT UNSIGNED NOT NULL DEFAULT 150000,
    `coords_x` DOUBLE NOT NULL DEFAULT 0,
    `coords_y` DOUBLE NOT NULL DEFAULT 0,
    `coords_z` DOUBLE NOT NULL DEFAULT 0,
    `owner_character_id` INT UNSIGNED NULL DEFAULT NULL,
    `for_sale` TINYINT(1) NOT NULL DEFAULT 1,
    `profit_percent` TINYINT UNSIGNED NOT NULL DEFAULT 70,
    `balance` INT UNSIGNED NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `shop_key` (`shop_key`),
    KEY `owner_character_id` (`owner_character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
