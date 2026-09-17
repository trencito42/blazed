Config = {}

Config.WheelModel = `vw_prop_vw_luckywheel_02a`
Config.Vehicle = 	'tempesta'
Config.Amount = 100 -- Chips required if not free spin
Config.WheelPos = vector3(1111.052, 229.84, -50.38)
Config.SpinPos = vector3(1110.88, 228.87, -49.85)
Config.VehPos = vector4(1100.22, 220.04, -49.44, 0.0)
Config.SpinCooldownMinutes = 60
Config.VideoType = 'CASINO_DIA_PL'

Config.Prizes = {
    [1]  = { type = 'chips',   amount = 500,    label = '500 Chips' },
    [2]  = { type = 'item',    item = 'bandage', count = 5, label = '5x Bandages' },
    [3]  = { type = 'cash',    amount = 5000,   label = '$5,000 Cash' },
    [4]  = { type = 'chips',   amount = 1000,   label = '1,000 Chips' },
    [5]  = { type = 'cash',    amount = 25000,  label = '$25,000 Cash' },
    [6]  = { type = 'item',    item = 'repairkit', count = 2, label = '2x Repair Kits' },
    [7]  = { type = 'cash',    amount = 10000,  label = '$10,000 Cash' },
    [8]  = { type = 'chips',   amount = 2500,   label = '2,500 Chips' },
    [9]  = { type = 'cash',    amount = 15000,  label = '$15,000 Cash' },
    [10] = { type = 'item',    item = 'duffel_bag', count = 1, label = 'Duffel Bag' },
    [11] = { type = 'chips',   amount = 5000,   label = '5,000 Chips' },
    [12] = { type = 'cash',    amount = 50000,  label = '$50,000 Cash' },
    [13] = { type = 'chips',   amount = 7500,   label = '7,500 Chips' },
    [14] = { type = 'item',    item = 'radio', count = 1, label = 'Radio' },
    [15] = { type = 'cash',    amount = 20000,  label = '$20,000 Cash' },
    [16] = { type = 'chips',   amount = 10000,  label = '10,000 Chips' },
    [17] = { type = 'cash',    amount = 35000,  label = '$35,000 Cash' },
    [18] = { type = 'item',    item = 'armor', count = 2, label = '2x Heavy Armor' },
    [19] = { type = 'vehicle', model = 'tempesta', label = 'Pegassi Tempesta (Jackpot Vehicle!)' },
    [20] = { type = 'cash',    amount = 100000, label = '$100,000 GRAND PRIZE' },
}
