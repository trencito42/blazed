-- 52-marriage.sql — marriage/partner system
CREATE TABLE IF NOT EXISTS `marriages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `partner1_id` INT UNSIGNED NOT NULL,
    `partner2_id` INT UNSIGNED NOT NULL,
    `married_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `status` ENUM('active','divorced') NOT NULL DEFAULT 'active',
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_marriage` (`partner1_id`, `partner2_id`),
    INDEX `idx_partner1` (`partner1_id`),
    INDEX `idx_partner2` (`partner2_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
