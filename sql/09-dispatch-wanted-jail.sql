-- Unified dispatch queue (schema matches sunset_dispatch/server/service_core.lua).
CREATE TABLE IF NOT EXISTS `service_calls` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `call_type` VARCHAR(32) NOT NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'OPEN',
    `caller_character_id` INT UNSIGNED NOT NULL,
    `responder_character_id` INT UNSIGNED NULL,
    `coords` JSON NOT NULL,
    `description` VARCHAR(512) NOT NULL DEFAULT '',
    `metadata` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    KEY `idx_status_type` (`status`, `call_type`),
    KEY `idx_caller` (`caller_character_id`),
    KEY `idx_responder` (`responder_character_id`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Wanted history / audit (active state in character_wanted via sql/10-police-persist.sql).
CREATE TABLE IF NOT EXISTS `wanted_records` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `reason_code` VARCHAR(32) NOT NULL,
    `reason_label` VARCHAR(128) NOT NULL,
    `issued_by_character_id` INT UNSIGNED NULL,
    `jail_minutes` SMALLINT UNSIGNED NOT NULL DEFAULT 2,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `expires_at` TIMESTAMP NULL,
    `cleared_at` TIMESTAMP NULL,
    `cleared_by_character_id` INT UNSIGNED NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_character_active` (`character_id`, `active`),
    KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Jail sentence history (active state in character_jail via sql/10-police-persist.sql).
CREATE TABLE IF NOT EXISTS `jail_sentences` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `officer_character_id` INT UNSIGNED NULL,
    `wanted_record_id` INT UNSIGNED NULL,
    `reason` VARCHAR(256) NOT NULL DEFAULT '',
    `duration_minutes` SMALLINT UNSIGNED NOT NULL,
    `started_at` TIMESTAMP NULL,
    `ends_at` TIMESTAMP NULL,
    `released_at` TIMESTAMP NULL,
    `status` ENUM('pending', 'active', 'served', 'escaped', 'pardoned') NOT NULL DEFAULT 'pending',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_character_status` (`character_id`, `status`),
    KEY `idx_active_ends` (`status`, `ends_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Citations / tickets (UI panel and /fine command).
CREATE TABLE IF NOT EXISTS `tickets` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `officer_character_id` INT UNSIGNED NOT NULL,
    `target_character_id` INT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL,
    `reason` VARCHAR(256) NOT NULL DEFAULT '',
    `reason_code` VARCHAR(32) NULL,
    `paid` TINYINT(1) NOT NULL DEFAULT 0,
    `paid_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_target` (`target_character_id`),
    KEY `idx_officer` (`officer_character_id`),
    KEY `idx_unpaid` (`target_character_id`, `paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
