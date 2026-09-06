-- Five-star wanted model: surrender rights, online-only decay and exact jail time.
ALTER TABLE `wanted_records`
    ADD COLUMN IF NOT EXISTS `surrenderable` TINYINT(1) NOT NULL DEFAULT 1 AFTER `jail_minutes`,
    ADD COLUMN IF NOT EXISTS `decay_remaining_seconds` SMALLINT UNSIGNED NOT NULL DEFAULT 900 AFTER `surrenderable`;

ALTER TABLE `jail_sentences`
    ADD COLUMN IF NOT EXISTS `duration_seconds` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `duration_minutes`;

UPDATE `wanted_records`
SET `decay_remaining_seconds` = 900
WHERE `active` = 1 AND (`decay_remaining_seconds` IS NULL OR `decay_remaining_seconds` = 0);

UPDATE `wanted_records`
SET `surrenderable` = 0
WHERE `active` = 1 AND `reason_code` IN ('robbery', 'murder', 'evading');

UPDATE `jail_sentences`
SET `duration_seconds` = `duration_minutes` * 60
WHERE `duration_seconds` = 0;
