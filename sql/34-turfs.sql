-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — 34-turfs.sql
--  Los Santos Clan Turf Wars Grid & Territory Control
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `turfs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(64) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `radius` FLOAT NOT NULL DEFAULT 110.0,
    `owner_clan_id` INT DEFAULT NULL,
    `payout` INT UNSIGNED NOT NULL DEFAULT 1500,
    `respect_payout` INT UNSIGNED NOT NULL DEFAULT 2,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_owner_clan` (`owner_clan_id`)
);

-- Seed 16 iconic Los Santos territories for competitive gang wars
INSERT IGNORE INTO `turfs` (`id`, `name`, `x`, `y`, `z`, `radius`, `payout`, `respect_payout`) VALUES
(1, 'Grove Street', 105.21, -1941.42, 20.80, 120.0, 2000, 3),
(2, 'Ballas Glen Park', 382.60, -1597.20, 29.29, 110.0, 1800, 2),
(3, 'Vagos Rancho', 337.80, -2043.10, 21.05, 115.0, 1750, 2),
(4, 'Chamberlain Hills', -178.40, -1612.30, 33.60, 110.0, 1600, 2),
(5, 'Strawberry Projects', 290.15, -1350.20, 31.85, 110.0, 1700, 2),
(6, 'Davis Mega Mall', 124.50, -1550.40, 29.20, 105.0, 1900, 3),
(7, 'Cypress Flats Industrial', 835.40, -2105.30, 29.80, 130.0, 1650, 2),
(8, 'El Burro Heights', 1335.20, -1580.40, 54.20, 120.0, 1600, 2),
(9, 'East Los Santos Motel', 980.20, -1250.50, 25.50, 105.0, 1750, 2),
(10, 'Mirror Park Lakes', 1045.30, -680.20, 56.80, 125.0, 1850, 3),
(11, 'Vespucci Beach Boardwalk', -1220.50, -1450.20, 4.30, 115.0, 1800, 2),
(12, 'Del Perro Pier Plaza', -1540.20, -1080.40, 13.00, 110.0, 1950, 3),
(13, 'Little Seoul Commercial', -685.20, -820.40, 24.80, 110.0, 1900, 3),
(14, 'Vinewood Downtown', 320.40, -220.50, 54.00, 115.0, 2200, 4),
(15, 'Port of Los Santos Docks', 160.20, -3150.40, 5.80, 140.0, 2100, 3),
(16, 'La Puerta Scrapyard', -480.20, -1720.50, 18.50, 110.0, 1700, 2);
