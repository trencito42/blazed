-- Migration 53: Addon Vehicles Dealership Catalog Seed (Tempesta2, BMWs, AMG GT, Porsche 911s)

INSERT IGNORE INTO `dealership_vehicles`
    (`model`, `label`, `brand`, `category`, `price`, `stock`, `available`, `test_drive_enabled`, `display_order`)
VALUES
    ('tempesta2', 'Tempesta Widebody', 'Pegassi', 'super', 360000, 6, 1, 1, 10),
    ('sentinel_rts', 'Sentinel RTS Track', 'Ubermacht', 'coupe', 145000, 12, 1, 1, 11),
    ('d7cyp', 'Cypher GTS Spec', 'Ubermacht', 'super', 380000, 5, 1, 1, 12),
    ('schlagenstr', 'Schlagen STR AMG', 'Benefactor', 'sports', 175000, 10, 1, 1, 13),
    ('cometcup', 'Comet Cup Edition', 'Pfister', 'sports', 210000, 8, 1, 1, 14),
    ('H4RxST2', 'Harx ST2 GT', 'Pfister', 'sports', 195000, 8, 1, 1, 15);



