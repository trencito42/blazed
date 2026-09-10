-- Business profit / balance / type columns (run once)
ALTER TABLE `player_businesses`
    ADD COLUMN `business_type` VARCHAR(16) NOT NULL DEFAULT 'shop' AFTER `shop_key`;

ALTER TABLE `player_businesses`
    ADD COLUMN `profit_percent` TINYINT UNSIGNED NOT NULL DEFAULT 70 AFTER `for_sale`;

ALTER TABLE `player_businesses`
    ADD COLUMN `balance` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `profit_percent`;
