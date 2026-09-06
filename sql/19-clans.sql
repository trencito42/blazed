CREATE TABLE IF NOT EXISTS `clans` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(48) NOT NULL,
    `tag` VARCHAR(8) NOT NULL,
    `description` TEXT NULL,
    `tag_color` VARCHAR(7) NOT NULL DEFAULT '#FF8C00',
    `tag_style` VARCHAR(24) NOT NULL DEFAULT 'brackets',
    `owner_character_id` INT UNSIGNED NOT NULL,
    `motd` TEXT NULL,
    `max_members` INT UNSIGNED NOT NULL DEFAULT 25,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_clans_name` (`name`),
    UNIQUE KEY `uk_clans_tag` (`tag`),
    KEY `idx_clans_owner` (`owner_character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `clan_members` (
    `clan_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `rank` ENUM('leader', 'officer', 'member') NOT NULL DEFAULT 'member',
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`clan_id`, `character_id`),
    UNIQUE KEY `uk_clan_member_char` (`character_id`),
    KEY `idx_clan_members_clan` (`clan_id`),
    CONSTRAINT `fk_clan_members_clan` FOREIGN KEY (`clan_id`) REFERENCES `clans` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `clan_invites` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `clan_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `invited_by` INT UNSIGNED NOT NULL,
    `expires_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_clan_invite` (`clan_id`, `character_id`),
    KEY `idx_clan_invite_char` (`character_id`),
    CONSTRAINT `fk_clan_invites_clan` FOREIGN KEY (`clan_id`) REFERENCES `clans` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `clan_audit_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `clan_id` INT UNSIGNED NOT NULL,
    `actor_character_id` INT UNSIGNED NULL,
    `action` VARCHAR(48) NOT NULL,
    `details` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_clan_audit_clan` (`clan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
