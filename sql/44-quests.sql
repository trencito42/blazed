-- 44: Canonical quest/progression service (docs/product/RPG_PROGRESSION.md)
-- Owned by sunset_quests. One row per (character, quest) tracking stage/progress.

CREATE TABLE IF NOT EXISTS `character_quests` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `quest_key` VARCHAR(64) NOT NULL,
    `chain_key` VARCHAR(64) NOT NULL,
    `stage` INT NOT NULL DEFAULT 0,
    `progress` INT NOT NULL DEFAULT 0,
    `target` INT NOT NULL DEFAULT 1,
    `status` ENUM('active','complete','claimed') NOT NULL DEFAULT 'active',
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL DEFAULT NULL,
    `claimed_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_char_quest` (`character_id`, `quest_key`),
    KEY `idx_char_chain` (`character_id`, `chain_key`),
    CONSTRAINT `fk_quest_char` FOREIGN KEY (`character_id`)
        REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
