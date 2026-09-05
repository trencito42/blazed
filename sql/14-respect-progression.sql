-- SA:MP-style account progression. Job skill XP remains in job_progress.
ALTER TABLE `characters`
    ADD COLUMN IF NOT EXISTS `respect_points` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `xp`,
    ADD COLUMN IF NOT EXISTS `paydays_received` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `respect_points`,
    ADD COLUMN IF NOT EXISTS `respect_backfilled` TINYINT(1) NOT NULL DEFAULT 0 AFTER `paydays_received`;

-- One-time conversion: preserve historical connected hours as earned RP.
UPDATE `characters` c
JOIN `players` p ON p.id = c.player_id
SET c.respect_points = c.respect_points + FLOOR(p.playtime / 60),
    c.paydays_received = GREATEST(c.paydays_received, FLOOR(p.playtime / 60)),
    c.respect_backfilled = 1
WHERE c.respect_backfilled = 0;
