-- 45: Saved outfits (wardrobe) — docs/clothing/CLOTHING_STATE.md C8
-- Full clothing snapshot per outfit; owned by sunset_clothing.

CREATE TABLE IF NOT EXISTS `character_outfits` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(32) NOT NULL,
    `appearance` JSON NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_char_outfit_name` (`character_id`, `name`),
    KEY `idx_outfit_char` (`character_id`),
    CONSTRAINT `fk_outfit_char` FOREIGN KEY (`character_id`)
        REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
