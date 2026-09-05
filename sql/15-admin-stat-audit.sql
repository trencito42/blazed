-- Permanent audit trail for direct administrative changes to player progression.
CREATE TABLE IF NOT EXISTS `admin_stat_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `admin_account_id` INT UNSIGNED NULL,
    `admin_name` VARCHAR(64) NOT NULL,
    `target_character_id` INT UNSIGNED NOT NULL,
    `target_name` VARCHAR(80) NOT NULL,
    `stat_name` VARCHAR(48) NOT NULL,
    `old_value` BIGINT NOT NULL,
    `new_value` BIGINT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_admin_stat_target` (`target_character_id`, `created_at`),
    KEY `idx_admin_stat_admin` (`admin_account_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
