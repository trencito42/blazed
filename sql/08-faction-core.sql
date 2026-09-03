USE `sunsetmp`;

CREATE TABLE IF NOT EXISTS `faction_leaders` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `faction_id` VARCHAR(32) NOT NULL,
    `assigned_by` VARCHAR(64) NOT NULL DEFAULT 'console',
    `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `char_faction` (`character_id`, `faction_id`),
    KEY `faction_id` (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `faction_audit_log` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `faction_id` VARCHAR(32) NOT NULL,
    `actor_character_id` INT UNSIGNED NULL,
    `action` VARCHAR(64) NOT NULL,
    `target_character_id` INT UNSIGNED NULL,
    `details` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `faction_id` (`faction_id`),
    KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `faction_warnings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `faction_id` VARCHAR(32) NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `issued_by` INT UNSIGNED NOT NULL,
    `reason` VARCHAR(256) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `faction_character` (`faction_id`, `character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `faction_motd` (
    `faction_id` VARCHAR(32) NOT NULL,
    `message` VARCHAR(512) NOT NULL DEFAULT '',
    `updated_by` INT UNSIGNED NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
