-- Durable robbery cooldowns and an audit trail for economy/security investigations.
CREATE TABLE IF NOT EXISTS `robbery_cooldowns` (
    `scope` ENUM('character', 'location') NOT NULL,
    `scope_key` VARCHAR(64) NOT NULL,
    `expires_at` BIGINT UNSIGNED NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`scope`, `scope_key`),
    KEY `idx_robbery_cooldown_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `robbery_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `session_id` VARCHAR(96) NOT NULL,
    `character_id` INT UNSIGNED NULL,
    `location_id` VARCHAR(64) NOT NULL,
    `event` VARCHAR(32) NOT NULL,
    `bag_used` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `estimated_value` INT UNSIGNED NOT NULL DEFAULT 0,
    `details` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_robbery_audit_session` (`session_id`),
    KEY `idx_robbery_audit_character` (`character_id`, `created_at`),
    KEY `idx_robbery_audit_location` (`location_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `robbery_runs` (
    `session_id` VARCHAR(96) NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `location_id` VARCHAR(64) NOT NULL,
    `status` ENUM('active', 'success', 'failed', 'cancelled') NOT NULL DEFAULT 'active',
    `bag_used` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `estimated_value` INT UNSIGNED NOT NULL DEFAULT 0,
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `finished_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`session_id`),
    KEY `idx_robbery_runs_status` (`status`, `started_at`),
    KEY `idx_robbery_runs_character` (`character_id`, `started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
