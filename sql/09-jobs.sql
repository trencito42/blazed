-- Civilian job skill progress (XP per job, separate from character level)
CREATE TABLE IF NOT EXISTS `job_progress` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `job_id` VARCHAR(32) NOT NULL,
    `xp` INT UNSIGNED NOT NULL DEFAULT 0,
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `completed_tasks` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_earned` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_char_job` (`character_id`, `job_id`),
    KEY `idx_job` (`job_id`),
    CONSTRAINT `fk_job_progress_char` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
