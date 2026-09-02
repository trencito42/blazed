CREATE DATABASE IF NOT EXISTS `sunsetmp` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `sunsetmp`;

-- ═══ JUCĂTORI ═══
CREATE TABLE IF NOT EXISTS `players` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license` VARCHAR(64) NOT NULL,
    `steam` VARCHAR(64) DEFAULT NULL,
    `discord` VARCHAR(64) DEFAULT NULL,
    `name` VARCHAR(128) NOT NULL,
    `playtime` INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══ PERSONAJE ═══
CREATE TABLE IF NOT EXISTS `characters` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id` INT UNSIGNED NOT NULL,
    `slot` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `firstname` VARCHAR(32) NOT NULL,
    `lastname` VARCHAR(32) NOT NULL,
    `dateofbirth` DATE NOT NULL,
    `gender` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `nationality` VARCHAR(32) NOT NULL DEFAULT 'Romanian',
    `cash` INT UNSIGNED NOT NULL DEFAULT 500,
    `bank` INT UNSIGNED NOT NULL DEFAULT 2500,
    `job` VARCHAR(32) NOT NULL DEFAULT 'unemployed',
    `job_grade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `position` JSON NOT NULL,
    `appearance` JSON NOT NULL,
    `metadata` JSON NOT NULL DEFAULT ('{}'),
    `is_dead` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_played` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `player_slot` (`player_id`, `slot`),
    CONSTRAINT `fk_characters_player` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══ INVENTAR (viitor) ═══
CREATE TABLE IF NOT EXISTS `character_inventory` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `count` INT UNSIGNED NOT NULL DEFAULT 1,
    `metadata` JSON DEFAULT NULL,
    `slot` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `character_id` (`character_id`),
    CONSTRAINT `fk_inventory_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
