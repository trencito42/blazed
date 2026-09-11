-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — 35-containers.sql
--  Vehicle Trunk, Glovebox and Property Stash storage
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `container_inventory` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `container_type` VARCHAR(32) NOT NULL,
    `container_id` VARCHAR(64) NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `count` INT NOT NULL DEFAULT 1,
    `slot` INT NOT NULL DEFAULT 1,
    `metadata` LONGTEXT DEFAULT NULL,
    KEY `idx_container` (`container_type`, `container_id`)
);
