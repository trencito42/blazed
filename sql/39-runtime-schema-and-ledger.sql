-- Move the last resource-owned schema changes into the checked migration path.
CREATE TABLE IF NOT EXISTS `money_transactions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `account` ENUM('cash', 'bank') NOT NULL DEFAULT 'bank',
    `direction` ENUM('in', 'out') NOT NULL,
    `amount` INT NOT NULL,
    `reason` VARCHAR(64) NOT NULL DEFAULT 'unknown',
    `balance_after` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_money_tx_char` (`character_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

UPDATE `characters`
SET `phone_number` = CONCAT('555-', LPAD(id, 4, '0'))
WHERE `phone_number` IS NULL OR `phone_number` = '';
