-- Economy rebalance: dealership catalog + starter properties (2026-09-07)

UPDATE `dealership_vehicles` SET `price` = 16500 WHERE `model` = 'blista';
UPDATE `dealership_vehicles` SET `price` = 18000 WHERE `model` = 'issi2';
UPDATE `dealership_vehicles` SET `price` = 22000 WHERE `model` = 'prairie';
UPDATE `dealership_vehicles` SET `price` = 28000 WHERE `model` = 'asea';
UPDATE `dealership_vehicles` SET `price` = 48000 WHERE `model` = 'tailgater';
UPDATE `dealership_vehicles` SET `price` = 42000 WHERE `model` = 'bati';
UPDATE `dealership_vehicles` SET `price` = 72000 WHERE `model` = 'buffalo';
UPDATE `dealership_vehicles` SET `price` = 82000 WHERE `model` = 'sultan';
UPDATE `dealership_vehicles` SET `price` = 95000 WHERE `model` = 'baller2';
UPDATE `dealership_vehicles` SET `price` = 105000 WHERE `model` = 'dubsta';
UPDATE `dealership_vehicles` SET `price` = 165000 WHERE `model` = 'comet2';
UPDATE `dealership_vehicles` SET `price` = 480000 WHERE `model` = 'adder';

UPDATE `properties` SET `price` = 32000 WHERE `id` = 1;
UPDATE `properties` SET `price` = 90000 WHERE `id` = 2;
UPDATE `properties` SET `price` = 320000 WHERE `id` = 3;

UPDATE `properties`
SET `rent_price` = 150
WHERE `rent_enabled` = 1 AND `rent_price` = 100;

INSERT IGNORE INTO `dealership_meta` (`meta_key`, `meta_value`)
VALUES ('economy_rebalance_v1', '2026-09-07');
