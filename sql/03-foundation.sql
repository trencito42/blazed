USE `sunsetmp`;

-- ═══ ACCOUNTS (SAMP-style username/password) ═══
CREATE TABLE IF NOT EXISTS `accounts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(32) NOT NULL,
    `password_hash` VARCHAR(128) NOT NULL,
    `password_salt` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `players`
    ADD COLUMN IF NOT EXISTS `account_id` INT UNSIGNED NULL AFTER `id`;

-- Character survival / progression
ALTER TABLE `characters`
    ADD COLUMN IF NOT EXISTS `hunger` FLOAT NOT NULL DEFAULT 100 AFTER `is_dead`,
    ADD COLUMN IF NOT EXISTS `thirst` FLOAT NOT NULL DEFAULT 100 AFTER `hunger`,
    ADD COLUMN IF NOT EXISTS `stress` FLOAT NOT NULL DEFAULT 0 AFTER `thirst`,
    ADD COLUMN IF NOT EXISTS `level` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `stress`,
    ADD COLUMN IF NOT EXISTS `xp` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `level`,
    ADD COLUMN IF NOT EXISTS `home_property_id` INT UNSIGNED NULL AFTER `xp`;

-- ═══ PROPERTIES ═══
CREATE TABLE IF NOT EXISTS `properties` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(64) NOT NULL,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `interior` VARCHAR(64) NOT NULL DEFAULT 'standard',
    `entry` JSON NOT NULL,
    `interior_pos` JSON NOT NULL,
    `garage_pos` JSON DEFAULT NULL,
    `owner_character_id` INT UNSIGNED NULL,
    `locked` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `owner_character_id` (`owner_character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══ SOCIETY ACCOUNTS (job businesses) ═══
CREATE TABLE IF NOT EXISTS `societies` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(32) NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `balance` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══ PERMISSIONS (beyond admin) ═══
CREATE TABLE IF NOT EXISTS `account_permissions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `permission` VARCHAR(64) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `account_perm` (`account_id`, `permission`),
    CONSTRAINT `fk_perm_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed societies for jobs
INSERT IGNORE INTO `societies` (`name`, `label`, `balance`) VALUES
    ('unemployed', 'Unemployed', 0),
    ('taxi', 'Taxi Co.', 5000),
    ('mechanic', 'Los Santos Customs', 10000),
    ('police', 'LSPD', 25000),
    ('medic', 'Pillbox EMS', 15000);

-- Seed starter properties (apartments near airport + city)
INSERT IGNORE INTO `properties` (`id`, `label`, `price`, `entry`, `interior_pos`) VALUES
    (1, 'LSIA Motel Room', 25000,
        '{"x":-1037.58,"y":-2737.58,"z":20.17,"w":328.0}',
        '{"x":-1037.58,"y":-2737.58,"z":20.17,"w":328.0}'),
    (2, 'Vespucci Studio', 75000,
        '{"x":-1151.0,"y":-1520.0,"z":10.6,"w":35.0}',
        '{"x":-1151.0,"y":-1520.0,"z":10.6,"w":35.0}'),
    (3, 'Vinewood Hills House', 250000,
        '{"x":-174.0,"y":497.0,"z":137.0,"w":90.0}',
        '{"x":-174.0,"y":497.0,"z":137.0,"w":90.0}');
