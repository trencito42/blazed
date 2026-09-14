-- 50-avatar.sql — persistent character avatar (ped headshot captured once at
-- first spawn, stored as base64 data URL, never changes on duty/uniform).
ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `avatar` LONGTEXT NULL AFTER `appearance`;
