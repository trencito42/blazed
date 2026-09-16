-- Migration 53: Addon Vehicles Dealership Catalog Seed

INSERT IGNORE INTO `dealership_vehicles`
    (`model`, `label`, `brand`, `category`, `price`, `stock`, `available`, `test_drive_enabled`, `display_order`)
VALUES
    ('vd_tenfrally', '10F Rally Custom', 'Obey', 'sports', 185000, 10, 1, 1, 10),
    ('cometcup', 'Comet Cup Edition', 'Pfister', 'sports', 210000, 8, 1, 1, 11),
    ('sentinel_rts', 'Sentinel RTS Track', 'Ubermacht', 'coupe', 145000, 12, 1, 1, 12),
    ('vd_buffalo4', 'Buffalo STX Custom', 'Bravado', 'muscle', 165000, 15, 1, 1, 13),
    ('elegysa', 'Elegy SA Spec', 'Annis', 'sports', 135000, 10, 1, 1, 14),
    ('kurumac', 'Kuruma Custom', 'Karin', 'sports', 120000, 15, 1, 1, 15),
    ('d7cyp', 'D7 Cyber Spec', 'Dinka', 'super', 380000, 5, 1, 1, 16),
    ('H4RxST2', 'Harx ST2 GT', 'Annis', 'sports', 195000, 8, 1, 1, 17);
