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
    ('d7cyp', 'Cypher GTS Spec', 'Ubermacht', 'super', 380000, 5, 1, 1, 16),
    ('H4RxST2', 'Harx ST2 GT', 'Pfister', 'sports', 195000, 8, 1, 1, 17),
    ('toreroxoc', 'Torero XO Custom', 'Pegassi', 'super', 420000, 5, 1, 1, 18),
    ('tempesta2', 'Tempesta Widebody', 'Pegassi', 'super', 360000, 6, 1, 1, 19),
    ('mxls', 'Monarch XLS', 'Benefactor', 'sedans', 110000, 15, 1, 1, 20),
    ('schlagenstr', 'Schlagen STR', 'Benefactor', 'sports', 175000, 10, 1, 1, 21),
    ('pentro', 'Pentro Classic', 'Maibatsu', 'sports', 95000, 15, 1, 1, 22),
    ('pentro2', 'Pentro Type II', 'Maibatsu', 'sports', 105000, 12, 1, 1, 23),
    ('pentro3', 'Pentro GT Coupe', 'Maibatsu', 'coupe', 115000, 12, 1, 1, 24),
    ('pentrogpr', 'Pentro GPR', 'Maibatsu', 'super', 240000, 8, 1, 1, 25),
    ('pentrogpr2', 'Pentro GPR Evo', 'Maibatsu', 'super', 260000, 8, 1, 1, 26),
    ('scheisser', 'Scheisser Sport', 'Benefactor', 'sedans', 85000, 15, 1, 1, 27),
    ('severo', 'Severo Super V12', 'Pegassi', 'super', 450000, 5, 1, 1, 28),
    ('algoschafter', 'Schafter V12 LWB', 'Benefactor', 'sedans', 125000, 15, 1, 1, 29),
    ('hachurac', 'Hachura Custom', 'Vulcar', 'sports', 130000, 12, 1, 1, 30),
    ('sultan2c', 'Sultan Classic Custom', 'Karin', 'sports', 140000, 12, 1, 1, 31);

