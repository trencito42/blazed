-- Migration 53: Addon Vehicles Dealership Catalog Seed (Tempesta2 & BMWs)

INSERT IGNORE INTO `dealership_vehicles`
    (`model`, `label`, `brand`, `category`, `price`, `stock`, `available`, `test_drive_enabled`, `display_order`)
VALUES
    ('tempesta2', 'Tempesta Widebody', 'Pegassi', 'super', 360000, 6, 1, 1, 10),
    ('sentinel_rts', 'Sentinel RTS Track', 'Ubermacht', 'coupe', 145000, 12, 1, 1, 11),
    ('d7cyp', 'Cypher GTS Spec', 'Ubermacht', 'super', 380000, 5, 1, 1, 12);


