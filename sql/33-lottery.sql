-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — 33-lottery.sql
--  Lottery state & tickets persistence
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `lottery_state` (
    `id` INT PRIMARY KEY DEFAULT 1,
    `jackpot` INT UNSIGNED NOT NULL DEFAULT 15000,
    `last_winner_name` VARCHAR(64) DEFAULT NULL,
    `last_winner_prize` INT UNSIGNED DEFAULT 0,
    `last_winning_number` INT DEFAULT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT IGNORE INTO `lottery_state` (`id`, `jackpot`) VALUES (1, 15000);

CREATE TABLE IF NOT EXISTS `lottery_tickets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `character_id` INT NOT NULL,
    `number` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_char_ticket` (`character_id`)
);
