CREATE TABLE IF NOT EXISTS `lottery_draws` (
    `period_key` CHAR(10) NOT NULL,
    `winning_number` TINYINT UNSIGNED NOT NULL,
    `prize` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_tickets` INT UNSIGNED NOT NULL DEFAULT 0,
    `winners_json` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`period_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
