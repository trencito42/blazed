CREATE TABLE IF NOT EXISTS `admins` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(64) NOT NULL,
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `name` VARCHAR(128) NOT NULL,
    `granted_by` VARCHAR(64) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bans` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(64) NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `banned_by` VARCHAR(64) NOT NULL,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vehicles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `plate` VARCHAR(8) NOT NULL,
    `model` VARCHAR(64) NOT NULL,
    `props` JSON DEFAULT NULL,
    `fuel` FLOAT NOT NULL DEFAULT 100.0,
    `engine` FLOAT NOT NULL DEFAULT 1000.0,
    `body` FLOAT NOT NULL DEFAULT 1000.0,
    `stored` TINYINT(1) NOT NULL DEFAULT 1,
    `garage` VARCHAR(32) DEFAULT 'legion',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `plate` (`plate`),
    KEY `character_id` (`character_id`),
    CONSTRAINT `fk_vehicles_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
