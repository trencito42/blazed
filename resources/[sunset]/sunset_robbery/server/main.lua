local function nearPoint(source, coords, radius)
    local pos = RobberyAdapter.playerCoords(source)
    return pos and RobberyAdapter.dist(pos, coords) <= (radius or 2.2)
end

local FenceOffers = {}
local FenceBusy = {}

CreateThread(function()
    -- Recover safely after an unclean FXServer/container stop. Successful runs are
    -- intentionally excluded, so unsold legitimate loot remains untouched.
    local ok, err = pcall(function()
        local abandoned = MySQL.query.await(
            "SELECT session_id, character_id, location_id FROM robbery_runs WHERE status = 'active'"
        ) or {}
        local now = os.time()
        for _, run in ipairs(abandoned) do
            RobberyAdapter.setCooldown('character', run.character_id, now + (SunsetRobbery.PlayerCooldownSec or 1800))
            RobberyAdapter.setCooldown('location', run.location_id, now + (SunsetRobbery.LocationCooldownSec or 2700))
        end
        MySQL.update.await([[
            DELETE ci FROM character_inventory ci
            INNER JOIN robbery_runs rr
                ON rr.session_id = JSON_UNQUOTE(JSON_EXTRACT(ci.metadata, '$.robbery'))
            WHERE rr.status = 'active'
              AND JSON_EXTRACT(ci.metadata, '$.stolen') = true
        ]])
        MySQL.update.await([[
            UPDATE robbery_runs
            SET status = 'cancelled', finished_at = CURRENT_TIMESTAMP
            WHERE status = 'active'
        ]])
        MySQL.update.await('DELETE FROM robbery_cooldowns WHERE expires_at <= ?', { os.time() })
    end)
    if not ok then print(('[sunset_robbery] recovery failed: %s'):format(tostring(err))) end
end)

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

local function hackPayload(session)
    return RobberySessions.hackPublic(session.hack)
end

local function sendHackProgress(source, hack, extra)
    local nextId = hack.path[hack.index + 1]
    local nextNode = nextId and hack.nodeById[nextId] or nil
    TriggerClientEvent('sunset:robbery:hackProgress', source, {
        index = hack.index,
        trace = hack.trace,
        currentNode = hack.path[hack.index],
        signal = nextNode and nextNode.frequency or nil,
        nodeId = extra and extra.nodeId or nil,
        errorNode = extra and extra.errorNode or nil,
        status = extra and extra.status or nil,
        lockArmed = extra and extra.lockArmed or false,
        burstMs = extra and extra.burstMs or nil,
    })
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
    local payload = hackPayload(session)
    payload.timeLimit = math.max(1, session.hack.timeLimit - (os.time() - session.hack.startedAt))
    TriggerClientEvent('sunset:robbery:hackOpenUi', source, payload)
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
    nodeId = tostring(nodeId or ''):sub(1, 12)
    local nowMs = GetGameTimer()
    local expected = hack.path[hack.index + 1]

    if hack.burstDeadline and nowMs > hack.burstDeadline then
        hack.burstDeadline = nil
        hack.trace = math.min(SunsetRobbery.HackTraceFail, hack.trace + 28)
        hack.mistakes = hack.mistakes + 1
        if hack.trace >= SunsetRobbery.HackTraceFail then
            applyHackResult(session, 'failed')
            TriggerClientEvent('sunset:robbery:hackResult', source, { result = 'failed', hud = RobberySessions.hud(session) })
            return
        end
        sendHackProgress(source, hack, { errorNode = nodeId, status = 'BURST WINDOW MISSED — SIGNAL RESET' })
        return
    end

    if nodeId == expected then
        local node = hack.nodeById[nodeId]
        if node and node.kind == 'locked' then
            if hack.lockNode ~= nodeId or not hack.lockExpiresAt or nowMs > hack.lockExpiresAt then
                hack.lockNode = nodeId
                hack.lockExpiresAt = nowMs + 2200
                sendHackProgress(source, hack, {
                    nodeId = nodeId,
                    lockArmed = true,
                    status = 'ENCRYPTED GATE ARMED — CONFIRM NODE AGAIN',
                    burstMs = 2200,
                })
                return
            end
            hack.lockNode = nil
            hack.lockExpiresAt = nil
        end

        hack.index = hack.index + 1
        hack.lastCorrectAt = nowMs
        hack.burstDeadline = node and node.kind == 'timed' and (nowMs + 3000) or nil
        if hack.index >= #hack.path then
            local result = hack.mistakes == 0 and 'perfect' or 'normal'
            applyHackResult(session, result)
            TriggerClientEvent('sunset:robbery:hackResult', source, { result = result, hud = RobberySessions.hud(session) })
            return
        end
        sendHackProgress(source, hack, {
            nodeId = nodeId,
            status = node and node.kind == 'timed' and 'BURST RELAY ACTIVE — ROUTE NEXT NODE NOW' or 'SIGNAL ACCEPTED',
            burstMs = hack.burstDeadline and 3000 or nil,
        })
        return
    end


    if hack.lockNode then
        hack.lockNode = nil
        hack.lockExpiresAt = nil
    end
    hack.mistakes = hack.mistakes + 1
    local clicked = hack.nodeById[nodeId]
    local penalty = SunsetRobbery.HackWrongClickTrace
    if clicked and clicked.kind == 'corrupted' then penalty = penalty + 10 end
    hack.trace = math.min(SunsetRobbery.HackTraceFail, hack.trace + penalty)
    if hack.trace >= SunsetRobbery.HackTraceFail then
        applyHackResult(session, 'failed')
        TriggerClientEvent('sunset:robbery:hackResult', source, { result = 'failed', hud = RobberySessions.hud(session) })
        return
    end
    sendHackProgress(source, hack, {
        errorNode = nodeId,
        status = clicked and clicked.kind == 'corrupted' and 'CORRUPTED NODE — TRACE SPIKE' or 'CHANNEL MISMATCH — TRACE INCREASED',
    })
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
            RobberyAdapter.issueWanted(source, 'robbery', true)
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
    if session.lootBusy then return end
    displayId = tostring(displayId or ''):sub(1, 24)
    uid = tostring(uid or ''):sub(1, 96)
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
    if not item or item.taken or item.taking then return end
    if session.bagUsed + (item.weight or 1) > session.bagCap then
        return RobberyAdapter.notify(source, 'Duffel bag is full — escape or drop the extra score', 'error')
    end
    -- Reserve before the database write yields so two concurrent NUI events cannot
    -- both receive the same item or race for the same inventory slot.
    session.lootBusy = true
    item.taking = true
    local streetValue, fenceOffer = RobberyLoot.stableOfferFor(item, tonumber(item.uid:match('(%d+)$')))
    if not RobberyAdapter.addItem(source, item.item, 1, {
        stolen = true,
        robbery = session.id,
        lootUid = item.uid,
        value = item.baseValue,
        family = item.family,
        streetValue = streetValue,
        fenceOffer = fenceOffer,
    }) then
        item.taking = nil
        session.lootBusy = nil
        return RobberyAdapter.notify(source, 'Inventory is full', 'error')
    end
    if RobberySessions.get(source) ~= session or session.stage ~= 'LOOTING' then
        item.taking = nil
        session.lootBusy = nil
        RobberyAdapter.removeRobberyLoot(source, session.characterId, session.id)
        return
    end
    item.taken = true
    item.taking = nil
    session.lootBusy = nil
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
    local issued = {}
    local char = RobberyAdapter.getCharacter(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and try again.' end
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
            if RobberyAdapter.isCompletedLoot(meta.robbery, char.id) then
                local street, offer
                if tonumber(meta.streetValue) and tonumber(meta.fenceOffer) then
                    street, offer = math.floor(tonumber(meta.streetValue)), math.floor(tonumber(meta.fenceOffer))
                else
                    street, offer = RobberyLoot.stableOfferFor({
                        baseValue = tonumber(meta.value) or 900,
                        family = meta.family or 'watch',
                    }, tonumber(row.id))
                end
                local offerId = ('%d:%d:%d'):format(tonumber(row.id) or 0, os.time(), math.random(100000, 999999))
                issued[offerId] = {
                    characterId = tonumber(char.id),
                    rowId = tonumber(row.id),
                    item = itemName,
                    robberyId = tostring(meta.robbery),
                    metadata = meta,
                    street = street,
                    offer = offer,
                    expiresAt = os.time() + 30,
                }
                offers[#offers + 1] = {
                    offerId = offerId,
                    item = itemName,
                    count = row.count,
                    label = (def and def.label) or itemName,
                    street = street,
                    offer = offer,
                }
            end
        end
    end
    FenceOffers[source] = issued
    return { offers = offers, demand = SunsetRobbery.Fence.demand }
end)

exports.sunset_core:RegisterCallback('sunset:robbery:fenceSell', function(source, offerId)
    if not nearPoint(source, SunsetRobbery.Fence.coords, SunsetRobbery.Fence.interact + 0.6) then
        return nil, 'Stay with the fence'
    end
    if FenceBusy[source] then return nil, 'The fence is already processing your previous item' end
    offerId = tostring(offerId or ''):sub(1, 64)
    local offer = FenceOffers[source] and FenceOffers[source][offerId]
    local char = RobberyAdapter.getCharacter(source)
    if not offer or offer.expiresAt < os.time() then return nil, 'That offer expired. Reopen the fence list.' end
    if not char or tonumber(char.id) ~= offer.characterId then return nil, 'That offer does not belong to this character' end
    if offer.item:sub(1, 7) ~= 'stolen_' then return nil, 'The fence only buys stolen goods' end
    if not RobberyAdapter.isCompletedLoot(offer.robberyId, offer.characterId) then
        return nil, 'This loot is tied to an unfinished or invalid robbery and cannot be sold.'
    end

    FenceBusy[source] = true
    FenceOffers[source][offerId] = nil
    if not RobberyAdapter.settleFenceSale(source, offer.rowId, offer.item, offer.offer) then
        FenceBusy[source] = nil
        return nil, 'That exact item changed or the payment could not be completed. Reopen the fence list.'
    end
    FenceBusy[source] = nil
    RobberyAdapter.audit({
        id = tostring(offer.metadata.robbery or ('fence_%d'):format(os.time())),
        characterId = offer.characterId,
        locationId = 'fence',
        bagUsed = 0,
        estimated = offer.offer,
    }, 'fence_sale', { rowId = offer.rowId, item = offer.item, paid = offer.offer })
    if GetResourceState('sunset_pass') == 'started' then
        exports.sunset_pass:AddMissionProgress(source, 'robbery_complete', 1)
    end
    return { paid = offer.offer, street = offer.street, remaining = 0 }
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
                    if not session.wantedIssued then
                        session.wantedIssued = true
                        RobberyAdapter.issueWanted(source, 'robbery')
                    end
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
    FenceOffers[source] = nil
    FenceBusy[source] = nil
    RobberySessions.lastEvent[source] = nil
    RobberySessions.starting[source] = nil
    for locationId, owner in pairs(RobberySessions.locationBusy) do
        if owner == source and not RobberySessions.get(source) then
            RobberySessions.locationBusy[locationId] = nil
        end
    end
    if RobberySessions.get(source) then
        RobberySessions.fail(source, 'Disconnected')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local active = {}
    for source in pairs(RobberySessions.bySource) do active[#active + 1] = source end
    for _, source in ipairs(active) do RobberySessions.cancel(source, 'Robbery system restarted') end
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
            stage = session.stage,
        })
    elseif action == 'points' then
        exports.sunset_core:AddRobPoints(source, tonumber(args[2]) or 5)
        RobberyAdapter.notify(source, 'Rob points granted', 'success')
    else
        RobberyAdapter.notify(source, 'Usage: /robdebug reset|force|points', 'info')
    end
end, false)
