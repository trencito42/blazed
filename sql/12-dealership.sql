CREATE TABLE IF NOT EXISTS `dealership_vehicles` (
    `model` VARCHAR(64) NOT NULL,
    `label` VARCHAR(80) NOT NULL,
    `brand` VARCHAR(48) NOT NULL DEFAULT 'Other',
    `category` VARCHAR(32) NOT NULL DEFAULT 'other',
    `price` INT UNSIGNED NOT NULL,
    `stock` INT UNSIGNED NOT NULL DEFAULT 0,
    `available` TINYINT(1) NOT NULL DEFAULT 1,
    `test_drive_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `display_order` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`model`),
    KEY `catalog` (`available`, `category`, `brand`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dealership_sales` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `vehicle_id` INT UNSIGNED NOT NULL,
    `model` VARCHAR(64) NOT NULL,
    `plate` VARCHAR(8) NOT NULL,
    `price` INT UNSIGNED NOT NULL,
    `payment_account` ENUM('cash', 'bank') NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `character_id` (`character_id`),
    KEY `vehicle_id` (`vehicle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dealership_admin_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `admin_name` VARCHAR(128) NOT NULL,
    `character_id` INT UNSIGNED DEFAULT NULL,
    `action` VARCHAR(32) NOT NULL,
    `model` VARCHAR(64) DEFAULT NULL,
    `payload` JSON DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `model` (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dealership_meta` (
    `meta_key` VARCHAR(64) NOT NULL,
    `meta_value` VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (`meta_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `dealership_vehicles`
    (`model`, `label`, `brand`, `category`, `price`, `stock`, `available`, `test_drive_enabled`, `display_order`)
SELECT seed.* FROM (
    SELECT
        'blista' AS `model`,
        'Blista' AS `label`,
        'Dinka' AS `brand`,
        'compact' AS `category`,
        12000 AS `price`,
        12 AS `stock`,
        1 AS `available`,
        1 AS `test_drive_enabled`,
        10 AS `display_order`
    UNION ALL SELECT 'issi2', 'Issi', 'Weeny', 'compact', 14500, 10, 1, 1, 20
    UNION ALL SELECT 'prairie', 'Prairie', 'Bollokan', 'compact', 18000, 8, 1, 1, 30
    UNION ALL SELECT 'asea', 'Asea', 'Declasse', 'sedan', 22000, 10, 1, 1, 40
    UNION ALL SELECT 'tailgater', 'Tailgater', 'Obey', 'sedan', 42000, 6, 1, 1, 50
    UNION ALL SELECT 'buffalo', 'Buffalo', 'Bravado', 'sport', 65000, 5, 1, 1, 60
    UNION ALL SELECT 'sultan', 'Sultan', 'Karin', 'sport', 72000, 5, 1, 1, 70
    UNION ALL SELECT 'baller2', 'Baller', 'Gallivanter', 'suv', 85000, 4, 1, 1, 80
    UNION ALL SELECT 'dubsta', 'Dubsta', 'Benefactor', 'suv', 95000, 4, 1, 1, 90
    UNION ALL SELECT 'bati', 'Bati 801', 'Pegassi', 'motorcycle', 38000, 6, 1, 1, 100
    UNION ALL SELECT 'comet2', 'Comet', 'Pfister', 'sport', 145000, 3, 1, 1, 110
    UNION ALL SELECT 'adder', 'Adder', 'Truffade', 'super', 850000, 1, 1, 1, 120
) AS seed
WHERE NOT EXISTS (
    SELECT 1 FROM `dealership_meta` WHERE `meta_key` = 'initial_catalog_v1'
);

INSERT IGNORE INTO `dealership_meta` (`meta_key`, `meta_value`)
VALUES ('initial_catalog_v1', '2026-09-05');
