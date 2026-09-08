-- ═══ VEHICLE INSURANCE SYSTEM (SA:MP STYLE) ═══
USE `sunsetmp`;

ALTER TABLE `vehicles`
    ADD COLUMN IF NOT EXISTS `insurance_points` INT NOT NULL DEFAULT 5 AFTER `garage`,
    ADD COLUMN IF NOT EXISTS `insurance_level` INT NOT NULL DEFAULT 1 AFTER `insurance_points`,
    ADD COLUMN IF NOT EXISTS `destroyed` TINYINT(1) NOT NULL DEFAULT 0 AFTER `insurance_level`,
    ADD COLUMN IF NOT EXISTS `insurance_cost` INT NOT NULL DEFAULT 250 AFTER `destroyed`;
