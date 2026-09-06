local function nearPoint(source, coords, radius)
    local pos = RobberyAdapter.playerCoords(source)
    return pos and RobberyAdapter.dist(pos, coords) <= (radius or 2.2)
end

local function pushHud(source)
    local session = RobberySessions.get(source)
    if not session then return end
    TriggerClientEvent('sunset:robbery:hud', source, RobberySessions.hud(session))
end

local function applyHackResult(session, result)
    session.hackResult = result
    local delay = SunsetRobbery.FailedHackDelaySec
    if result == 'perfect' then
        delay = SunsetRobbery.PerfectHackDelaySec
    elseif result == 'normal' then
        delay = SunsetRobbery.NormalHackDelaySec
    end
    session.alertAt = os.time() + delay
    session.escalateAt = session.alertAt + (SunsetRobbery.PoliceEscalateSec or 20)
    session.vehicleAt = session.alertAt + (SunsetRobbery.PoliceVehicleSec or 40)
    RobberySessions.setStage(session, 'LOOTING')
end

RegisterNetEvent('sunset:robbery:tryStart', function(locationId)
    local source = source
    if not RobberySessions.rateOk(source) then return end
    locationId = type(locationId) == 'string' and locationId or 'luxury_store'
    local loc = SunsetRobbery.Locations[locationId]
    if not loc then return RobberyAdapter.notify(source, 'Unknown robbery location', 'error') end
    if not nearPoint(source, loc.coords, loc.radius or SunsetRobbery.StartRadius) then
        return RobberyAdapter.notify(source, 'You are not at a robbery location', 'error')
    end
    local session, err = RobberySessions.begin(source, locationId, false)
    if not session then return RobberyAdapter.notify(source, err, 'error') end
    TriggerClientEvent('sunset:robbery:started', source, {
        locationId = locationId,
        location = loc,
        bagCap = session.bagCap,
        hack = { nodes = session.hack.nodes, timeLimit = session.hack.timeLimit },
        stage = session.stage,
    })
    RobberyAdapter.notify(source, 'Security live — reach the terminal and bypass it.', 'warning', 6000)
end)

exports.sunset_core:RegisterCallback('sunset:robbery:start', function(source, locationId)
    locationId = type(locationId) == 'string' and locationId or 'luxury_store'
    local loc = SunsetRobbery.Locations[locationId]
    if not loc then return nil, 'Unknown location' end
    if not nearPoint(source, loc.coords, loc.radius or SunsetRobbery.StartRadius) then
        return nil, 'You are not at a robbery location'
    end
    local session, err = RobberySessions.begin(source, locationId, false)
    if not session then return nil, err end
    TriggerClientEvent('sunset:robbery:started', source, {
        locationId = locationId,
        location = loc,
        bagCap = session.bagCap,
        hack = { nodes = session.hack.nodes, timeLimit = session.hack.timeLimit },
        stage = session.stage,
    })
    return { stage = 'HACKING', bagCap = session.bagCap }
end)

RegisterNetEvent('sunset:robbery:hackOpen', function()
    local source = source
    local session = RobberySessions.get(source)
    if not session or session.stage ~= 'HACKING' then return end
    if not nearPoint(source, session.location.hackTerminal.coords, 2.6) then
        return RobberyAdapter.notify(source, 'Stay at the security terminal', 'error')
    end
    if not session.hack.startedAt then
        session.hack.startedAt = os.time()
    end
end)

RegisterNetEvent('sunset:robbery:hackClick', function(nodeId)
    local source = source
    if not RobberySessions.rateOk(source) then return end
    local session = RobberySessions.get(source)
    if not session or session.stage ~= 'HACKING' then return end
    if not nearPoint(source, session.location.hackTerminal.coords, 2.6) then
        return RobberyAdapter.notify(source, 'Stay at the security terminal', 'error')
    end
    local hack = session.hack
    if not hack.startedAt then
        hack.startedAt = os.time()
    end
    if os.time() - hack.startedAt >= hack.timeLimit then
        applyHackResult(session, 'failed')
        TriggerClientEvent('sunset:robbery:hackResult', source, { result = 'failed', hud = RobberySessions.hud(session) })
        return
    end
    nodeId = tostring(nodeId or '')
    local expected = hack.path[hack.index + 1]
    if nodeId == expected then
        hack.index = hack.index + 1
        if hack.index >= #hack.path then
            local result = hack.mistakes == 0 and 'perfect' or 'normal'
            applyHackResult(session, result)
            TriggerClientEvent('sunset:robbery:hackResult', source, { result = result, hud = RobberySessions.hud(session) })
            return
        end
        TriggerClientEvent('sunset:robbery:hackProgress', source, {
            index = hack.index,
            nodeId = nodeId,
            trace = hack.mistakes * SunsetRobbery.HackWrongClickTrace,
        })
        return
    end
    hack.mistakes = hack.mistakes + 1
    local trace = hack.mistakes * SunsetRobbery.HackWrongClickTrace
    if trace >= SunsetRobbery.HackTraceFail then
        applyHackResult(session, 'failed')
        TriggerClientEvent('sunset:robbery:hackResult', source, { result = 'failed', hud = RobberySessions.hud(session) })
        return
    end
    TriggerClientEvent('sunset:robbery:hackProgress', source, { index = hack.index, nodeId = nil, trace = trace })
end)

RegisterNetEvent('sunset:robbery:smash', function(displayId)
    local source = source
    if not RobberySessions.rateOk(source) then return end
    local session = RobberySessions.get(source)
    if not session or (session.stage ~= 'LOOTING' and session.stage ~= 'ESCAPING') then return end
    displayId = tostring(displayId or '')
    local displayCfg
    for _, row in ipairs(session.location.displays) do
        if row.id == displayId then displayCfg = row break end
    end
    if not displayCfg then return end
    if not nearPoint(source, displayCfg.coords, SunsetRobbery.StoreInteractRadius + 0.4) then
        return RobberyAdapter.notify(source, 'Get closer to the display', 'error')
    end
    local slot = session.displays[displayId]
    if slot.smashed then
        return TriggerClientEvent('sunset:robbery:displayLoot', source, { displayId = displayId, items = slot.items, already = true })
    end
    local count = math.random(SunsetRobbery.DisplayLootCount.min, SunsetRobbery.DisplayLootCount.max)
    slot.items = RobberyLoot.generateDisplay(displayCfg.lootTable, count)
    slot.smashed = true
    if not session.firstSmashAt then
        session.firstSmashAt = os.time()
        if not session.alertAt then
            session.alertAt = os.time() + (session.hackResult == 'perfect' and SunsetRobbery.PerfectHackDelaySec or SunsetRobbery.NormalHackDelaySec)
        end
        if not session.wantedIssued then
            session.wantedIssued = true
            RobberyAdapter.issueWanted(source, 'robbery')
        end
    end
    TriggerClientEvent('sunset:robbery:displayLoot', source, {
        displayId = displayId,
        label = displayCfg.label,
        items = slot.items,
        bagUsed = session.bagUsed,
        bagCap = session.bagCap,
        estimated = session.estimated,
    })
    pushHud(source)
end)

RegisterNetEvent('sunset:robbery:takeItem', function(displayId, uid)
    local source = source
    if not RobberySessions.rateOk(source) then return end
    local session = RobberySessions.get(source)
    if not session or session.stage ~= 'LOOTING' then return end
    displayId = tostring(displayId or '')
    uid = tostring(uid or '')
    local slot = session.displays[displayId]
    if not slot or not slot.smashed or not slot.items then return end
    local displayCfg
    for _, row in ipairs(session.location.displays) do
        if row.id == displayId then displayCfg = row break end
    end
    if not displayCfg or not nearPoint(source, displayCfg.coords, 2.8) then return end
    local item
    for _, row in ipairs(slot.items) do
        if row.uid == uid then item = row break end
    end
    if not item or item.taken then return end
    if session.bagUsed + (item.weight or 1) > session.bagCap then
        return RobberyAdapter.notify(source, 'Duffel bag is full — escape or drop the extra score', 'error')
    end
    if not RobberyAdapter.addItem(source, item.item, 1, { stolen = true, robbery = session.id, value = item.baseValue, family = item.family }) then
        return RobberyAdapter.notify(source, 'Inventory is full', 'error')
    end
    item.taken = true
    session.bagUsed = session.bagUsed + (item.weight or 1)
    session.estimated = session.estimated + (item.baseValue or 0)
    session.generatedLoot[#session.generatedLoot + 1] = item.item
    TriggerClientEvent('sunset:robbery:itemTaken', source, {
        displayId = displayId,
        uid = uid,
        bagUsed = session.bagUsed,
        bagCap = session.bagCap,
        estimated = session.estimated,
        label = item.label,
        value = item.baseValue,
    })
end)

RegisterNetEvent('sunset:robbery:leaveStore', function()
    local source = source
    local session = RobberySessions.get(source)
    if not session then return end
    if session.bagUsed <= 0 then
        RobberySessions.cancel(source, 'You left without loot')
        return
    end
    RobberySessions.setStage(session, 'ESCAPING')
    TriggerClientEvent('sunset:robbery:escaping', source, {
        radius = SunsetRobbery.EscapeRadius,
        origin = session.location.coords,
        hud = RobberySessions.hud(session),
    })
end)

RegisterNetEvent('sunset:robbery:escaped', function()
    local source = source
    local session = RobberySessions.get(source)
    if not session or session.stage ~= 'ESCAPING' then return end
    local pos = RobberyAdapter.playerCoords(source)
    if not pos or RobberyAdapter.dist(pos, session.location.coords) < (SunsetRobbery.EscapeRadius - 8.0) then
        return
    end
    RobberySessions.success(source)
end)

exports.sunset_core:RegisterCallback('sunset:robbery:fencePreview', function(source)
    if not nearPoint(source, SunsetRobbery.Fence.coords, SunsetRobbery.Fence.interact + 0.6) then
        return nil, 'Talk to the fence at the docks warehouse'
    end
    local offers = {}
    local okInv, inv = pcall(function()
        return exports.sunset_inventory:GetInventory(source)
    end)
    if not okInv then
        return nil, 'The fence cannot read your pockets right now. Try again.'
    end
    for _, row in ipairs(inv or {}) do
        local itemName = tostring(row.item or '')
        if itemName:sub(1, 7) == 'stolen_' and (tonumber(row.count) or 0) > 0 then
            local items = Sunset.Items or {}
            local def = items[itemName]
            local meta = row.metadata
            if type(meta) == 'string' then
                local decodedOk, decoded = pcall(json.decode, meta)
                meta = decodedOk and decoded or {}
            end
            if type(meta) ~= 'table' then meta = {} end
            local street, offer = RobberyLoot.offerFor({
                baseValue = tonumber(meta.value) or 900,
                family = meta.family or 'watch',
            })
            offers[#offers + 1] = {
                item = itemName,
                count = row.count,
                label = (def and def.label) or itemName,
                street = street,
                offer = offer,
            }
        end
    end
    return { offers = offers, demand = SunsetRobbery.Fence.demand }
end)

exports.sunset_core:RegisterCallback('sunset:robbery:fenceSell', function(source, itemName)
    if not nearPoint(source, SunsetRobbery.Fence.coords, SunsetRobbery.Fence.interact + 0.6) then
        return nil, 'Stay with the fence'
    end
    itemName = tostring(itemName or '')
    if itemName:sub(1, 7) ~= 'stolen_' then return nil, 'The fence only buys stolen goods' end
    local inv = exports.sunset_inventory:GetInventory(source)
    local row
    for _, entry in ipairs(inv or {}) do
        if entry.item == itemName and (entry.count or 0) > 0 then row = entry break end
    end
    if not row then return nil, 'You do not have that item' end
    local meta = type(row.metadata) == 'table' and row.metadata or {}
    local street, offer = RobberyLoot.offerFor({
        baseValue = meta.value or 900,
        family = meta.family or 'watch',
    })
    if not RobberyAdapter.removeItem(source, itemName, 1) then return nil, 'Could not take the item' end
    RobberyAdapter.addCash(source, offer)
    return { paid = offer, street = street, remaining = (row.count or 1) - 1 }
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for source, session in pairs(RobberySessions.bySource) do
            if RobberyAdapter.isDead(source) then
                RobberySessions.fail(source, 'You went down — robbery over')
            elseif session.stage == 'HACKING' and session.hack and session.hack.startedAt
                and now - session.hack.startedAt >= session.hack.timeLimit then
                applyHackResult(session, 'failed')
                TriggerClientEvent('sunset:robbery:hackResult', source, { result = 'failed', hud = RobberySessions.hud(session) })
            else
                if session.alertAt and not session.policeAlerted and now >= session.alertAt then
                    session.policeAlerted = true
                    RobberyPolice.alert(session, 'first')
                    TriggerClientEvent('sunset:robbery:alarm', source)
                end
                if session.escalateAt and not session.descAlerted and now >= session.escalateAt then
                    session.descAlerted = true
                    RobberyPolice.alert(session, 'desc')
                end
                if session.vehicleAt and not session.vehicleAlerted and now >= session.vehicleAt then
                    session.vehicleAlerted = true
                    RobberyPolice.alert(session, 'vehicle')
                end
                pushHud(source)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    if RobberySessions.get(source) then
        RobberySessions.fail(source, 'Disconnected')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for source in pairs(RobberySessions.bySource) do
        RobberySessions.cancel(source, 'Robbery system restarted')
    end
end)

AddEventHandler('sunset:death:playerDowned', function(source)
    if RobberySessions.get(source) then
        RobberySessions.fail(source, 'You went down — robbery over')
    end
end)

RegisterCommand('rob', function(source)
    if source == 0 then return end
    TriggerClientEvent('sunset:robbery:tryCommand', source)
end, false)

RegisterCommand('robdebug', function(source, args)
    if source == 0 then return end
    if not SunsetRobbery.Debug then
        return RobberyAdapter.notify(source, 'Robbery debug is disabled', 'error')
    end
    if not RobberyAdapter.isAdmin(source) then
        return RobberyAdapter.notify(source, 'Robbery debug requires administrator access', 'error')
    end
    local action = string.lower(tostring(args[1] or ''))
    if action == 'reset' then
        RobberySessions.resetCooldowns(source, 'luxury_store')
        RobberyAdapter.notify(source, 'Cooldowns cleared', 'success')
    elseif action == 'force' then
        local session, err = RobberySessions.begin(source, 'luxury_store', true)
        if not session then return RobberyAdapter.notify(source, err, 'error') end
        TriggerClientEvent('sunset:robbery:started', source, {
            locationId = 'luxury_store',
            location = session.location,
            bagCap = session.bagCap,
            hack = { nodes = session.hack.nodes, timeLimit = session.hack.timeLimit },
            stage = session.stage,
        })
    elseif action == 'points' then
        exports.sunset_core:AddRobPoints(source, tonumber(args[2]) or 5)
        RobberyAdapter.notify(source, 'Rob points granted', 'success')
    else
        RobberyAdapter.notify(source, 'Usage: /robdebug reset|force|points', 'info')
    end
end, false)
