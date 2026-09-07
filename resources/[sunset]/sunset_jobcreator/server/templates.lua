local function seedJob(jobId, meta, definition)
    if JCStorage_Get(jobId) then return false end
    JCStorage_Save(jobId, meta, definition, 'system')
    print(('[sunset_jobcreator] Seeded template %s'):format(jobId))
    return true
end

local function courierTemplate()
    return {
        startStage = 'init_total',
        timeoutSec = 1200,
        salary = 140,
        ui = { title = 'Courier', key = 'E' },
        progression = { xpPerTask = 18, payPerTask = 75 },
        variables = { done = 0, total = 4, leg = 1 },
        locations = {
            hub = {
                x = 78.45, y = 112.22, z = 81.17, radius = 3.5, zTolerance = 5.0,
                label = 'Courier Warehouse',
                blip = { sprite = 478, color = 3, scale = 0.85 },
            },
        },
        pools = {
            deliveries = {
                { x = -47.22, y = -1758.45, z = 29.42, label = 'Davis Ave', weight = 1 },
                { x = 213.88, y = -810.45, z = 30.73, label = 'Legion Square', weight = 1 },
                { x = 373.12, y = -126.45, z = 62.45, label = 'Vinewood', weight = 1 },
                { x = -128.55, y = -1415.22, z = 29.35, label = 'South LS', weight = 1 },
                { x = 120.55, y = -1688.22, z = 29.30, label = 'Strawberry', weight = 1 },
            },
        },
        stages = {
            {
                id = 'init_total',
                type = 'scale_from_level',
                label = 'Prepare route',
                var = 'total',
                resetVar = 'done',
                base = 4,
                perLevel = 1,
                max = 10,
                onSuccess = 'to_hub',
            },
            {
                id = 'to_hub',
                type = 'goto_zone',
                label = 'Go to warehouse',
                location = 'hub',
                message = 'Go to the warehouse loading dock',
                onSuccess = 'load',
            },
            {
                id = 'load',
                type = 'zone_interact',
                label = 'Load package',
                location = 'hub',
                message = 'Press {key} to load a package',
                onSuccess = 'pick_delivery',
            },
            {
                id = 'pick_delivery',
                type = 'pick_random',
                label = 'Route assigned',
                pool = 'deliveries',
                storeAs = 'target',
                onSuccess = 'deliver',
            },
            {
                id = 'deliver',
                type = 'zone_interact',
                label = 'Deliver package',
                locationVar = 'target',
                message = 'Press {key} to deliver the package',
                actions = { { type = 'increment', var = 'done', value = 1 } },
                onSuccess = 'pay_leg',
            },
            {
                id = 'pay_leg',
                type = 'give_reward',
                label = 'Payment',
                onSuccess = 'check_done',
            },
            {
                id = 'check_done',
                type = 'branch',
                label = 'More packages?',
                condition = { var = 'done', op = '<', valueRef = 'total' },
                ifTrue = 'to_hub',
                ifFalse = 'finish',
            },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function routeTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1800,
        salary = 180,
        ui = { title = 'Trucker', key = 'E' },
        progression = { xpPerTask = 45, payPerTask = 0 },
        variables = { done = 0, total = 3 },
        locations = {
            depot = {
                x = 1208.77, y = -3114.84, z = 5.54, radius = 8.0, zTolerance = 6.0,
                label = 'Trucker Depot',
                blip = { sprite = 477, color = 5, scale = 0.85 },
            },
            truck_spawn = {
                x = 1245.58, y = -3135.42, z = 5.54, heading = 90.0, radius = 8.0, zTolerance = 6.0,
                label = 'Truck spawn',
            },
            trailer_spawn = {
                x = 1255.0, y = -3135.42, z = 5.54, heading = 90.0, radius = 8.0, zTolerance = 6.0,
                label = 'Trailer spawn',
            },
        },
        pools = {
            routes = {
                {
                    weight = 1,
                    label = 'Terminal → Harmony',
                    pay = 650,
                    pickup = { x = 892.15, y = -3204.55, z = 5.90, radius = 12.0, zTolerance = 8.0, label = 'Cargo pickup' },
                    delivery = { x = 2673.27, y = 3513.14, z = 52.71, radius = 18.0, zTolerance = 10.0, label = 'Harmony delivery' },
                },
                {
                    weight = 1,
                    label = 'Docks → Paleto',
                    pay = 900,
                    pickup = { x = -424.88, y = -2789.33, z = 6.0, radius = 12.0, zTolerance = 8.0, label = 'Dock pickup' },
                    delivery = { x = 1702.55, y = 6416.12, z = 32.76, radius = 18.0, zTolerance = 10.0, label = 'Paleto delivery' },
                },
                {
                    weight = 1,
                    label = 'Sandy → South Docks',
                    pay = 750,
                    pickup = { x = 2747.32, y = 3472.88, z = 55.67, radius = 12.0, zTolerance = 8.0, label = 'Sandy pickup' },
                    delivery = { x = -219.45, y = -2419.88, z = 6.0, radius = 18.0, zTolerance = 10.0, label = 'South Docks delivery' },
                },
            },
        },
        stages = {
            {
                id = 'init',
                type = 'scale_from_level',
                var = 'total',
                resetVar = 'done',
                base = 2,
                perLevel = 1,
                max = 5,
                onSuccess = 'to_depot',
            },
            {
                id = 'to_depot',
                type = 'goto_zone',
                label = 'Go to depot',
                location = 'depot',
                message = 'Drive to the trucker depot',
                onSuccess = 'spawn_truck',
            },
            {
                id = 'spawn_truck',
                type = 'spawn_vehicle',
                label = 'Spawn rig',
                model = 'phantom',
                location = 'truck_spawn',
                warp = true,
                storeAs = 'vehicle',
                onSuccess = 'attach_trailer',
            },
            {
                id = 'attach_trailer',
                type = 'attach_trailer',
                label = 'Attach trailer',
                vehicleVar = 'vehicle',
                trailerModel = 'trailers2',
                location = 'trailer_spawn',
                storeAs = 'trailer',
                onSuccess = 'enter_truck',
            },
            {
                id = 'enter_truck',
                type = 'enter_vehicle',
                label = 'Enter truck',
                vehicleVar = 'vehicle',
                message = 'Enter your truck',
                onSuccess = 'pick_route',
            },
            {
                id = 'pick_route',
                type = 'pick_random',
                pool = 'routes',
                storeAs = 'route',
                onSuccess = 'to_pickup',
            },
            {
                id = 'to_pickup',
                type = 'goto_zone',
                label = 'Drive to pickup',
                locationVar = 'route',
                locationField = 'pickup',
                message = 'Drive to the cargo pickup point',
                onSuccess = 'pickup',
            },
            {
                id = 'pickup',
                type = 'zone_interact',
                label = 'Load cargo',
                locationVar = 'route',
                locationField = 'pickup',
                message = 'Press {key} to load cargo',
                onSuccess = 'to_delivery',
            },
            {
                id = 'to_delivery',
                type = 'goto_zone',
                label = 'Drive to destination',
                locationVar = 'route',
                locationField = 'delivery',
                message = 'Deliver the cargo to the marked destination',
                onSuccess = 'deliver',
            },
            {
                id = 'deliver',
                type = 'zone_interact',
                label = 'Unload cargo',
                locationVar = 'route',
                locationField = 'delivery',
                message = 'Press {key} to unload cargo',
                actions = { { type = 'increment', var = 'done', value = 1 } },
                onSuccess = 'pay',
            },
            {
                id = 'pay',
                type = 'give_reward',
                payVar = 'route',
                xp = 45,
                onSuccess = 'check',
            },
            {
                id = 'check',
                type = 'branch',
                condition = { var = 'done', op = '<', valueRef = 'total' },
                ifTrue = 'pick_route',
                ifFalse = 'return_depot',
            },
            {
                id = 'return_depot',
                type = 'goto_zone',
                label = 'Return to depot',
                location = 'depot',
                message = 'Return the truck to the depot',
                onSuccess = 'return_truck',
            },
            {
                id = 'return_truck',
                type = 'return_vehicle',
                label = 'Park truck',
                vehicleVar = 'vehicle',
                location = 'depot',
                message = 'Park the truck at the depot',
                onSuccess = 'delete_truck',
            },
            {
                id = 'delete_truck',
                type = 'delete_vehicle',
                label = 'End shift',
                onSuccess = 'finish',
            },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function gatherTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1500,
        salary = 120,
        ui = { title = 'Fisherman', key = 'E' },
        progression = { xpPerTask = 12, payPerTask = 55 },
        variables = { caught = 0, total = 5 },
        locations = {
            sell = {
                x = -1845.22, y = -1195.45, z = 14.30, radius = 5.0, zTolerance = 4.0,
                label = 'Fish Buyer — Del Perro Pier',
                blip = { sprite = 280, color = 46, scale = 0.8 },
            },
        },
        pools = {
            spots = {
                { x = -1850.32, y = -1248.03, z = 8.62, radius = 2.5, zTolerance = 1.5, label = 'Del Perro Pier', weight = 1 },
                { x = 1300.88, y = 4225.45, z = 33.91, radius = 2.5, zTolerance = 1.5, label = 'Alamo Sea', weight = 1 },
                { x = -1598.22, y = 5200.45, z = 4.31, radius = 2.5, zTolerance = 1.5, label = 'Paleto Cove', weight = 1 },
            },
        },
        stages = {
            {
                id = 'init',
                type = 'scale_from_level',
                var = 'total',
                resetVar = 'caught',
                base = 4,
                perLevel = 1,
                max = 12,
                onSuccess = 'pick_spot',
            },
            {
                id = 'pick_spot',
                type = 'pick_random',
                pool = 'spots',
                storeAs = 'spot',
                onSuccess = 'to_spot',
            },
            {
                id = 'to_spot',
                type = 'goto_zone',
                label = 'Go fishing',
                locationVar = 'spot',
                message = 'Go to the fishing spot',
                onSuccess = 'fish',
            },
            {
                id = 'fish',
                type = 'zone_interact',
                label = 'Cast line',
                locationVar = 'spot',
                message = 'Press {key} to fish',
                actions = { { type = 'increment', var = 'caught', value = 1 } },
                onSuccess = 'pay_catch',
            },
            {
                id = 'pay_catch',
                type = 'give_reward',
                onSuccess = 'check_caught',
            },
            {
                id = 'check_caught',
                type = 'branch',
                condition = { var = 'caught', op = '<', valueRef = 'total' },
                ifTrue = 'pick_spot',
                ifFalse = 'to_sell',
            },
            {
                id = 'to_sell',
                type = 'goto_zone',
                label = 'Sell catch',
                location = 'sell',
                message = 'Take your catch to the fish buyer',
                onSuccess = 'sell',
            },
            {
                id = 'sell',
                type = 'zone_interact',
                label = 'Sell fish',
                location = 'sell',
                message = 'Press {key} to sell your catch',
                onSuccess = 'bonus',
            },
            {
                id = 'bonus',
                type = 'give_reward',
                pay = 120,
                xp = 25,
                onSuccess = 'finish',
            },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function garbageTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1500,
        salary = 130,
        ui = { title = 'Garbage', key = 'E' },
        progression = { xpPerTask = 12, payPerTask = 48 },
        variables = { done = 0, total = 6 },
        locations = {
            depot = {
                x = -321.70, y = -1545.94, z = 27.72, radius = 6.0, zTolerance = 5.0,
                label = 'Garbage Depot',
                blip = { sprite = 318, color = 2, scale = 0.85 },
            },
            truck_spawn = {
                x = -341.12, y = -1530.45, z = 27.72, heading = 270.0, radius = 6.0, zTolerance = 5.0,
                label = 'Truck spawn',
            },
            unload = {
                x = -350.45, y = -1560.22, z = 25.22, radius = 5.0, zTolerance = 5.0,
                label = 'Unload bay',
            },
        },
        pools = {
            bins = {
                { x = -128.45, y = -1415.22, z = 29.35, radius = 3.0, zTolerance = 4.0, label = 'Bin — South LS', weight = 1 },
                { x = 45.12, y = -1398.55, z = 29.35, radius = 3.0, zTolerance = 4.0, label = 'Bin — Strawberry', weight = 1 },
                { x = 180.88, y = -1315.45, z = 29.22, radius = 3.0, zTolerance = 4.0, label = 'Bin — Downtown', weight = 1 },
                { x = 295.45, y = -1270.12, z = 29.45, radius = 3.0, zTolerance = 4.0, label = 'Bin — Pillbox', weight = 1 },
                { x = -55.22, y = -1755.88, z = 29.42, radius = 3.0, zTolerance = 4.0, label = 'Bin — Davis', weight = 1 },
                { x = 380.12, y = -1512.45, z = 29.28, radius = 3.0, zTolerance = 4.0, label = 'Bin — La Mesa', weight = 1 },
            },
        },
        stages = {
            {
                id = 'init',
                type = 'scale_from_level',
                var = 'total',
                resetVar = 'done',
                base = 5,
                perLevel = 1,
                max = 10,
                onSuccess = 'to_depot',
            },
            {
                id = 'to_depot',
                type = 'goto_zone',
                label = 'Start shift',
                location = 'depot',
                message = 'Go to the garbage depot to start your route',
                onSuccess = 'spawn_truck',
            },
            {
                id = 'spawn_truck',
                type = 'spawn_vehicle',
                model = 'trash',
                location = 'truck_spawn',
                warp = true,
                storeAs = 'vehicle',
                onSuccess = 'enter_truck',
            },
            {
                id = 'enter_truck',
                type = 'enter_vehicle',
                vehicleVar = 'vehicle',
                message = 'Enter the garbage truck',
                onSuccess = 'start_route',
            },
            {
                id = 'start_route',
                type = 'zone_interact',
                label = 'Begin route',
                location = 'depot',
                message = 'Press {key} to start collecting',
                onSuccess = 'pick_bin',
            },
            {
                id = 'pick_bin',
                type = 'pick_random',
                pool = 'bins',
                storeAs = 'bin',
                onSuccess = 'to_bin',
            },
            {
                id = 'to_bin',
                type = 'goto_zone',
                label = 'Collect trash',
                locationVar = 'bin',
                message = 'Go to the marked bin',
                onSuccess = 'collect',
            },
            {
                id = 'collect',
                type = 'zone_interact',
                label = 'Pick up trash',
                locationVar = 'bin',
                message = 'Press {key} to collect trash',
                actions = { { type = 'increment', var = 'done', value = 1 } },
                onSuccess = 'pay_bin',
            },
            {
                id = 'pay_bin',
                type = 'give_reward',
                onSuccess = 'check_bins',
            },
            {
                id = 'check_bins',
                type = 'branch',
                condition = { var = 'done', op = '<', valueRef = 'total' },
                ifTrue = 'pick_bin',
                ifFalse = 'return_truck',
            },
            {
                id = 'return_truck',
                type = 'return_vehicle',
                vehicleVar = 'vehicle',
                location = 'unload',
                message = 'Return truck to unload bay',
                onSuccess = 'unload',
            },
            {
                id = 'to_unload',
                type = 'goto_zone',
                label = 'Return to depot',
                location = 'unload',
                message = 'Unload at the depot bay',
                onSuccess = 'unload',
            },
            {
                id = 'unload',
                type = 'zone_interact',
                label = 'Unload truck',
                location = 'unload',
                message = 'Press {key} to unload',
                onSuccess = 'bonus',
            },
            {
                id = 'bonus',
                type = 'give_reward',
                pay = 120,
                xp = 30,
                onSuccess = 'delete_truck',
            },
            {
                id = 'delete_truck',
                type = 'delete_vehicle',
                onSuccess = 'finish',
            },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function minerTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1500,
        salary = 125,
        ui = { title = 'Miner', key = 'E' },
        progression = { xpPerTask = 14, payPerTask = 65 },
        variables = { mined = 0, total = 6 },
        locations = {
            quarry = { x = 2952.45, y = 2788.22, z = 41.50, radius = 12.0, zTolerance = 8.0, label = 'Quarry', blip = { sprite = 618, color = 46, scale = 0.85 } },
            sell = { x = 1087.22, y = -1988.45, z = 31.02, radius = 5.0, zTolerance = 5.0, label = 'Ore Buyer' },
        },
        pools = {
            veins = {
                { x = 2945.12, y = 2795.45, z = 40.88, radius = 3.5, zTolerance = 4.0, label = 'Ore vein A', weight = 1 },
                { x = 2968.88, y = 2775.22, z = 41.12, radius = 3.5, zTolerance = 4.0, label = 'Ore vein B', weight = 1 },
                { x = 2938.55, y = 2768.45, z = 40.55, radius = 3.5, zTolerance = 4.0, label = 'Ore vein C', weight = 1 },
            },
        },
        stages = {
            { id = 'init', type = 'scale_from_level', var = 'total', resetVar = 'mined', base = 5, perLevel = 1, max = 12, onSuccess = 'to_quarry' },
            { id = 'to_quarry', type = 'goto_zone', location = 'quarry', message = 'Go to the quarry', onSuccess = 'pick_vein' },
            { id = 'pick_vein', type = 'pick_random', pool = 'veins', storeAs = 'vein', onSuccess = 'to_vein' },
            { id = 'to_vein', type = 'goto_zone', locationVar = 'vein', message = 'Go to the ore vein', onSuccess = 'mine' },
            { id = 'mine', type = 'skill_check', locationVar = 'vein', windowMs = 1800, message = 'Press {key} when the bar is green!', onSuccess = 'pay_ore', onFailure = 'pick_vein' },
            { id = 'pay_ore', type = 'give_reward', onSuccess = 'inc_mined' },
            { id = 'inc_mined', type = 'set_variable', actions = { { type = 'increment', var = 'mined', value = 1 } }, onSuccess = 'check_mined' },
            { id = 'check_mined', type = 'branch', condition = { var = 'mined', op = '<', valueRef = 'total' }, ifTrue = 'pick_vein', ifFalse = 'to_sell' },
            { id = 'to_sell', type = 'goto_zone', location = 'sell', message = 'Sell ore at the buyer', onSuccess = 'sell' },
            { id = 'sell', type = 'zone_interact', location = 'sell', message = 'Press {key} to sell ore', onSuccess = 'bonus' },
            { id = 'bonus', type = 'give_reward', pay = 150, xp = 30, onSuccess = 'finish' },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function lumberTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1500,
        salary = 120,
        ui = { title = 'Lumberjack', key = 'E', bagLabel = 'Logs' },
        progression = { xpPerTask = 16, payPerTask = 70 },
        variables = { logs = 0, total = 4 },
        locations = {
            mill = {
                x = -552.45, y = 5328.22, z = 74.65, radius = 8.0, zTolerance = 6.0,
                label = 'Paleto Sawmill',
                blip = { sprite = 477, color = 25, scale = 0.9 },
            },
        },
        pools = {
            trees = {
                { id = 'pine_a', x = -501.2, y = 5390.5, z = 75.2, radius = 3.5, zTolerance = 4.0, label = 'Pine A', weight = 1 },
                { id = 'pine_b', x = -520.8, y = 5415.3, z = 74.8, radius = 3.5, zTolerance = 4.0, label = 'Pine B', weight = 1 },
                { id = 'pine_c', x = -545.1, y = 5430.2, z = 73.5, radius = 3.5, zTolerance = 4.0, label = 'Pine C', weight = 1 },
                { id = 'cedar_a', x = -578.3, y = 5398.7, z = 72.1, radius = 3.5, zTolerance = 4.0, label = 'Cedar A', weight = 1 },
                { id = 'cedar_b', x = -610.5, y = 5375.4, z = 71.8, radius = 3.5, zTolerance = 4.0, label = 'Cedar B', weight = 1 },
                { id = 'oak_a', x = -635.2, y = 5350.1, z = 70.5, radius = 3.5, zTolerance = 4.0, label = 'Oak A', weight = 1 },
                { id = 'pine_d', x = -565.8, y = 5362.4, z = 73.2, radius = 3.5, zTolerance = 4.0, label = 'Pine D', weight = 1 },
                { id = 'pine_e', x = -588.4, y = 5345.6, z = 72.0, radius = 3.5, zTolerance = 4.0, label = 'Pine E', weight = 1 },
                { id = 'pine_f', x = -512.3, y = 5368.9, z = 75.0, radius = 3.5, zTolerance = 4.0, label = 'Pine F', weight = 1 },
                { id = 'pine_g', x = -548.7, y = 5388.2, z = 73.8, radius = 3.5, zTolerance = 4.0, label = 'Pine G', weight = 1 },
            },
        },
        stages = {
            { id = 'init', type = 'scale_from_level', var = 'total', resetVar = 'logs', base = 4, perLevel = 1, max = 10, onSuccess = 'to_mill' },
            { id = 'to_mill', type = 'goto_zone', label = 'Start shift', location = 'mill', message = 'Go to the Paleto sawmill', onSuccess = 'pick_tree' },
            { id = 'pick_tree', type = 'pick_random', pool = 'trees', storeAs = 'tree', respectCooldown = true, onSuccess = 'spawn_tree' },
            { id = 'spawn_tree', type = 'spawn_prop', locationVar = 'tree', model = 'prop_tree_pine_02', storeAs = 'treeProp', onSuccess = 'to_tree' },
            { id = 'to_tree', type = 'goto_zone', label = 'Find tree', locationVar = 'tree', message = 'Go to the marked tree', onSuccess = 'chop' },
            {
                id = 'chop', type = 'chop_prop', label = 'Chopping...', locationVar = 'tree', propVar = 'treeProp',
                model = 'prop_tree_pine_02', swings = 5, durationMs = 6000,
                message = 'Press {key} to chop the tree', regenerateSec = 50, onSuccess = 'pay_log',
            },
            { id = 'pay_log', type = 'give_reward', onSuccess = 'inc_logs' },
            { id = 'inc_logs', type = 'set_variable', actions = { { type = 'increment', var = 'logs', value = 1 } }, onSuccess = 'check_logs' },
            { id = 'check_logs', type = 'branch', condition = { var = 'logs', op = '<', valueRef = 'total' }, ifTrue = 'pick_tree', ifFalse = 'deliver' },
            { id = 'deliver', type = 'zone_interact', label = 'Deliver logs', location = 'mill', message = 'Press {key} to deliver logs at the sawmill', onSuccess = 'bonus' },
            { id = 'bonus', type = 'give_reward', pay = 130, xp = 28, onSuccess = 'finish' },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function constructionTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1800,
        salary = 160,
        ui = { title = 'Construction', key = 'E' },
        progression = { xpPerTask = 20, payPerTask = 85 },
        variables = { tasks = 0, total = 4 },
        party = { soloEnabled = true, partyEnabled = true, minPlayers = 1, maxPlayers = 4 },
        locations = {
            site = { x = 138.45, y = -378.22, z = 43.25, radius = 10.0, zTolerance = 6.0, label = 'Construction Site', blip = { sprite = 566, color = 5, scale = 0.85 } },
            material = { x = 125.22, y = -365.45, z = 43.25, radius = 4.0, zTolerance = 5.0, label = 'Material pile' },
            build = { x = 152.88, y = -392.12, z = 43.25, radius = 4.0, zTolerance = 5.0, label = 'Build zone' },
        },
        stages = {
            { id = 'init', type = 'scale_from_level', var = 'total', resetVar = 'tasks', base = 3, perLevel = 1, max = 8, onSuccess = 'spawn_foreman' },
            { id = 'spawn_foreman', type = 'spawn_npc', model = 's_m_y_construct_01', location = 'site', heading = 160.0, scenario = 'WORLD_HUMAN_CLIPBOARD', storeAs = 'foreman', onSuccess = 'to_site' },
            { id = 'to_site', type = 'goto_zone', location = 'site', message = 'Go to the construction site', onSuccess = 'party_check' },
            { id = 'party_check', type = 'party_gate', minPlayers = 1, radius = 30.0, message = 'Waiting for crew...', onSuccess = 'briefing' },
            { id = 'briefing', type = 'talk_to_npc', npcVar = 'foreman', message = 'Press {key} to get assignment', onSuccess = 'get_materials' },
            { id = 'get_materials', type = 'progress', location = 'material', durationMs = 5000, label = 'Loading materials...', message = 'Press {key} to load', onSuccess = 'place' },
            { id = 'place', type = 'zone_interact', location = 'build', message = 'Press {key} to place materials', actions = { { type = 'increment', var = 'tasks', value = 1 } }, onSuccess = 'pay_task' },
            { id = 'pay_task', type = 'give_reward', onSuccess = 'check_tasks' },
            { id = 'check_tasks', type = 'branch', condition = { var = 'tasks', op = '<', valueRef = 'total' }, ifTrue = 'get_materials', ifFalse = 'cleanup_npc' },
            { id = 'cleanup_npc', type = 'remove_npc', npcVar = 'foreman', onSuccess = 'finish' },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function warehouseTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1200,
        salary = 135,
        ui = { title = 'Warehouse', key = 'E' },
        progression = { xpPerTask = 12, payPerTask = 55 },
        variables = { sorted = 0, total = 6 },
        locations = {
            dock = { x = 1005.22, y = -3102.45, z = 5.90, radius = 8.0, zTolerance = 6.0, label = 'Warehouse Dock', blip = { sprite = 478, color = 3, scale = 0.85 } },
            scan = { x = 1028.45, y = -3095.22, z = 5.90, radius = 3.5, zTolerance = 4.0, label = 'Scan station' },
        },
        pools = {
            shelves = {
                { x = 1012.88, y = -3110.45, z = 5.90, radius = 3.0, zTolerance = 4.0, label = 'Shelf A', weight = 1 },
                { x = 1045.22, y = -3105.12, z = 5.90, radius = 3.0, zTolerance = 4.0, label = 'Shelf B', weight = 1 },
                { x = 1062.55, y = -3088.88, z = 5.90, radius = 3.0, zTolerance = 4.0, label = 'Shelf C', weight = 1 },
            },
        },
        stages = {
            { id = 'init', type = 'scale_from_level', var = 'total', resetVar = 'sorted', base = 5, perLevel = 1, max = 12, onSuccess = 'to_dock' },
            { id = 'to_dock', type = 'goto_zone', location = 'dock', message = 'Go to the warehouse dock', onSuccess = 'pick_shelf' },
            { id = 'pick_shelf', type = 'pick_random', pool = 'shelves', storeAs = 'shelf', onSuccess = 'to_shelf' },
            { id = 'to_shelf', type = 'goto_zone', locationVar = 'shelf', message = 'Pick up a pallet', onSuccess = 'pickup' },
            { id = 'pickup', type = 'zone_interact', locationVar = 'shelf', message = 'Press {key} to pick up pallet', onSuccess = 'to_scan' },
            { id = 'to_scan', type = 'goto_zone', location = 'scan', message = 'Bring pallet to scan station', onSuccess = 'scan' },
            { id = 'scan', type = 'progress', location = 'scan', durationMs = 4000, label = 'Scanning...', message = 'Press {key} to scan', onSuccess = 'inc_sorted' },
            { id = 'inc_sorted', type = 'set_variable', actions = { { type = 'increment', var = 'sorted', value = 1 } }, onSuccess = 'pay_sort' },
            { id = 'pay_sort', type = 'give_reward', onSuccess = 'check_sorted' },
            { id = 'check_sorted', type = 'branch', condition = { var = 'sorted', op = '<', valueRef = 'total' }, ifTrue = 'pick_shelf', ifFalse = 'finish' },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

local function farmerTemplate()
    return {
        startStage = 'init',
        timeoutSec = 1500,
        salary = 115,
        ui = { title = 'Farmer', key = 'E' },
        progression = { xpPerTask = 10, payPerTask = 50 },
        variables = { harvested = 0, total = 6 },
        locations = {
            market = { x = 1961.22, y = 5184.45, z = 47.95, radius = 6.0, zTolerance = 5.0, label = 'Grapeseed Market', blip = { sprite = 85, color = 25, scale = 0.85 } },
        },
        pools = {
            fields = {
                { x = 2220.45, y = 5576.22, z = 53.85, radius = 4.0, zTolerance = 4.0, label = 'Field A', weight = 1 },
                { x = 2255.88, y = 5548.12, z = 53.12, radius = 4.0, zTolerance = 4.0, label = 'Field B', weight = 1 },
                { x = 2188.22, y = 5520.45, z = 53.45, radius = 4.0, zTolerance = 4.0, label = 'Field C', weight = 1 },
            },
        },
        stages = {
            { id = 'init', type = 'scale_from_level', var = 'total', resetVar = 'harvested', base = 5, perLevel = 1, max = 12, onSuccess = 'pick_field' },
            { id = 'pick_field', type = 'pick_random', pool = 'fields', storeAs = 'field', onSuccess = 'to_field' },
            { id = 'to_field', type = 'goto_zone', locationVar = 'field', message = 'Go to the crop field', onSuccess = 'harvest' },
            { id = 'harvest', type = 'progress', locationVar = 'field', durationMs = 5500, label = 'Harvesting...', message = 'Press {key} to harvest', onSuccess = 'inc_harvest' },
            { id = 'inc_harvest', type = 'set_variable', actions = { { type = 'increment', var = 'harvested', value = 1 } }, onSuccess = 'pay_crop' },
            { id = 'pay_crop', type = 'give_reward', onSuccess = 'check_harvest' },
            { id = 'check_harvest', type = 'branch', condition = { var = 'harvested', op = '<', valueRef = 'total' }, ifTrue = 'pick_field', ifFalse = 'to_market' },
            { id = 'to_market', type = 'goto_zone', location = 'market', message = 'Sell crops at the market', onSuccess = 'sell' },
            { id = 'sell', type = 'zone_interact', location = 'market', message = 'Press {key} to sell crops', onSuccess = 'bonus' },
            { id = 'bonus', type = 'give_reward', pay = 110, xp = 22, onSuccess = 'finish' },
            { id = 'finish', type = 'complete', label = 'Shift complete' },
        },
    }
end

function JCTemplates_Seed()
    local seeded = 0
    if seedJob('jc_tpl_courier', {
        label = 'Courier (Creator)',
        description = 'Load packages at the warehouse and deliver across the city.',
        category = 'delivery',
        icon = 'package',
        status = 'published',
    }, courierTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_route', {
        label = 'Trucker (Creator)',
        description = 'Pick up cargo and deliver across San Andreas. Route-based trucking template.',
        category = 'transport',
        icon = 'truck',
        status = 'published',
    }, routeTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_gather', {
        label = 'Fisherman (Creator)',
        description = 'Fish at marked spots and sell your catch at the pier.',
        category = 'gathering',
        icon = 'fish',
        status = 'published',
    }, gatherTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_garbage', {
        label = 'Garbage (Creator)',
        description = 'Collect trash from bins across the city and unload at the depot.',
        category = 'service',
        icon = 'trash',
        status = 'published',
    }, garbageTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_miner', {
        label = 'Miner (Creator)',
        description = 'Mine ore veins at the quarry and sell to the buyer.',
        category = 'gathering',
        icon = 'pickaxe',
        status = 'published',
    }, minerTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_lumber', {
        label = 'Lumberjack (Creator)',
        description = 'Chop trees and deliver logs to the sawmill.',
        category = 'gathering',
        icon = 'axe',
        status = 'published',
    }, lumberTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_construction', {
        label = 'Construction (Creator)',
        description = 'Work the construction site with foreman briefing and material placement.',
        category = 'service',
        icon = 'hardhat',
        status = 'published',
    }, constructionTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_warehouse', {
        label = 'Warehouse (Creator)',
        description = 'Pick pallets, scan, and sort at the dock warehouse.',
        category = 'logistics',
        icon = 'box',
        status = 'published',
    }, warehouseTemplate()) then seeded = seeded + 1 end

    if seedJob('jc_tpl_farmer', {
        label = 'Farmer (Creator)',
        description = 'Harvest crops in Grapeseed fields and sell at market.',
        category = 'gathering',
        icon = 'wheat',
        status = 'published',
    }, farmerTemplate()) then seeded = seeded + 1 end

    if seeded > 0 then
        print(('[sunset_jobcreator] Seeded %d template(s).'):format(seeded))
    end

    -- Always refresh lumber template (gameplay upgrades)
    local lumberMeta = {
        label = 'Lumberjack (Creator)',
        description = 'Chop spawned trees in Paleto Forest and deliver logs to the sawmill.',
        category = 'gathering',
        icon = 'axe',
        status = 'published',
    }
    if JCStorage_Get('jc_tpl_lumber') then
        local row = JCStorage_Get('jc_tpl_lumber')
        lumberMeta.status = row.status
        JCStorage_Save('jc_tpl_lumber', lumberMeta, lumberTemplate(), 'system-upgrade')
        print('[sunset_jobcreator] Refreshed jc_tpl_lumber template.')
    end
end
