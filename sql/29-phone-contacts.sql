-- 29-phone-contacts.sql
-- Persistent phone contacts / friends book and character phone number column

ALTER TABLE `characters`
    ADD COLUMN IF NOT EXISTS `phone_number` VARCHAR(32) NULL AFTER `nationality`;

CREATE TABLE IF NOT EXISTS `phone_contacts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT UNSIGNED NOT NULL,
    `contact_name` VARCHAR(64) NOT NULL,
    `phone_number` VARCHAR(32) NOT NULL,
    `contact_character_id` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_char_contact_phone` (`character_id`, `phone_number`),
    KEY `idx_phone_contacts_char` (`character_id`),
    KEY `idx_phone_contacts_phone` (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
