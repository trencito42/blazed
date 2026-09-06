CREATE TABLE IF NOT EXISTS `faction_grade_labels` (
    `faction_id` VARCHAR(32) NOT NULL,
    `grade` TINYINT UNSIGNED NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `updated_by` INT UNSIGNED NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`faction_id`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
