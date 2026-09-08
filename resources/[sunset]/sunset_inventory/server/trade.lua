local TradeInvites = {}
local TradesByPlayer = {}
local Drops = {}
local DropLocks = {}
local nextTradeId = 0
local nextDropId = 0

local TRADE_RANGE = 3.5
local INVITE_SECONDS = 30
local DROP_SECONDS = 300
local LICENSE_EXEMPT_WEAPONS = {
    WEAPON_UNARMED = true, WEAPON_KNIFE = true, WEAPON_SWITCHBLADE = true,
    WEAPON_BAT = true, WEAPON_CROWBAR = true, WEAPON_FLASHLIGHT = true,
    WEAPON_NIGHTSTICK = true, WEAPON_HAMMER = true, WEAPON_GOLFCLUB = true,
    WEAPON_BOTTLE = true, WEAPON_DAGGER = true, WEAPON_HATCHET = true,
    WEAPON_KNUCKLE = true, WEAPON_MACHETE = true, WEAPON_WRENCH = true,
    WEAPON_POOLCUE = true, WEAPON_BATTLEAXE = true, WEAPON_STONE_HATCHET = true,
    WEAPON_FIREEXTINGUISHER = true, WEAPON_PETROLCAN = true,
}

function IsInventoryTradeLocked(source)
    return TradesByPlayer[tonumber(source)] ~= nil
end

local function character(source)
    return exports.sunset_core:GetCharacter(source)
end

local function displayName(source)
    local char = character(source)
    if not char then return GetPlayerName(source) or ('Player #%d'):format(source) end
    if char.name and char.name ~= '' then return char.name end
    local full = (('%s %s'):format(char.firstname or '', char.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return full ~= '' and full or GetPlayerName(source) or ('Player #%d'):format(source)
end

local function closeEnough(a, b, range)
    if not GetPlayerName(a) or not GetPlayerName(b) then return false end
    local ap, bp = GetPlayerPed(a), GetPlayerPed(b)
    if not ap or ap == 0 or not bp or bp == 0 then return false end
    return #(GetEntityCoords(ap) - GetEntityCoords(bp)) <= (range or TRADE_RANGE)
end

local function findRow(source, rowId)
    rowId = tonumber(rowId)
    for _, row in ipairs(GetInventory(source) or {}) do
        if tonumber(row.id) == rowId then return row end
    end
    return nil
end

local function itemView(row, count)
    local def = Sunset.Items[row.item] or {}
    return {
        id = tonumber(row.id),
        item = row.item,
        count = math.floor(tonumber(count) or tonumber(row.count) or 0),
        slot = tonumber(row.slot),
        metadata = row.metadata,
        label = def.label or row.item,
        icon = def.icon,
    }
end

local function offerArray(trade, owner)
    local rows = {}
    for _, offered in pairs(trade.offers[owner] or {}) do rows[#rows + 1] = offered end
    table.sort(rows, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return rows
end

local function otherParty(trade, source)
    return source == trade.a and trade.b or trade.a
end

local function sendTradeState(trade)
    for _, source in ipairs({ trade.a, trade.b }) do
        if GetPlayerName(source) then
            local other = otherParty(trade, source)
            TriggerClientEvent('sunset:inventory:tradeState', source, {
                active = true,
                tradeId = trade.id,
                target = { id = other, name = displayName(other) },
                myOffer = offerArray(trade, source),
                theirOffer = offerArray(trade, other),
                myAccepted = trade.accepted[source] == true,
                theirAccepted = trade.accepted[other] == true,
            })
        end
    end
end

local function endTrade(trade, message, kind)
    if not trade then return end
    TradesByPlayer[trade.a] = nil
    TradesByPlayer[trade.b] = nil
    for _, source in ipairs({ trade.a, trade.b }) do
        if GetPlayerName(source) then
            TriggerClientEvent('sunset:inventory:tradeEnded', source, message, kind or 'info')
        end
    end
end

local function validateTrade(trade)
    if not trade or TradesByPlayer[trade.a] ~= trade or TradesByPlayer[trade.b] ~= trade then
        return nil, 'This trade is no longer active.'
    end
    if not closeEnough(trade.a, trade.b) then
        return nil, 'Trade cancelled because the players moved more than 3.5 metres apart.'
    end
    for _, owner in ipairs({ trade.a, trade.b }) do
        for rowId, offered in pairs(trade.offers[owner]) do
            local row = findRow(owner, rowId)
            if not row or row.item ~= offered.item or (tonumber(row.count) or 0) < offered.count then
                return nil, ('%s inventory changed. Reopen the trade.'):format(displayName(owner))
            end
        end
    end
    return true
end

local function inventoryWeightAfter(source, outgoing, incoming)
    local weight = 0
    for _, row in ipairs(GetInventory(source) or {}) do
        weight = weight + ((Sunset.Items[row.item] and Sunset.Items[row.item].weight or 0) * (tonumber(row.count) or 0))
    end
    for _, row in ipairs(outgoing) do
        weight = weight - ((Sunset.Items[row.item] and Sunset.Items[row.item].weight or 0) * row.count)
    end
    for _, row in ipairs(incoming) do
        weight = weight + ((Sunset.Items[row.item] and Sunset.Items[row.item].weight or 0) * row.count)
    end
    return weight
end

local function canReceiveItems(source, rows)
    if GetResourceState('sunset_licenses') ~= 'started' then return true end
    for _, row in ipairs(rows) do
        local def = Sunset.Items[row.item]
        local weapon = def and def.weapon and string.upper(def.weapon)
        if weapon and not LICENSE_EXEMPT_WEAPONS[weapon]
            and not exports.sunset_licenses:HasLicense(source, 'weapon') then
            return nil, ('%s cannot receive %s without a valid Firearm License.'):format(
                displayName(source), def.label or row.item)
        end
    end
    return true
end

local function freeSlotsAfter(source, outgoing)
    local freed = {}
    for _, row in ipairs(outgoing) do
        local current = findRow(source, row.id)
        if current and row.count >= (tonumber(current.count) or 0) then freed[tonumber(current.slot)] = true end
    end
    local used = {}
    for _, row in ipairs(GetInventory(source) or {}) do
        if not freed[tonumber(row.slot)] then used[tonumber(row.slot)] = true end
    end
    local slots = {}
    for i = 1, tonumber(Sunset.Config.MaxSlots) or 30 do
        if not used[i] then slots[#slots + 1] = i end
    end
    return slots
end

local function completeTrade(trade)
    local valid, err = validateTrade(trade)
    if not valid then return nil, err end
    local aOut, bOut = offerArray(trade, trade.a), offerArray(trade, trade.b)
    if #aOut == 0 and #bOut == 0 then return nil, 'Add at least one item before accepting the trade.' end

    local maxWeight = tonumber(Sunset.Config.MaxWeight) or 30
    if inventoryWeightAfter(trade.a, aOut, bOut) > maxWeight then return nil, ('%s has insufficient carry capacity.'):format(displayName(trade.a)) end
    if inventoryWeightAfter(trade.b, bOut, aOut) > maxWeight then return nil, ('%s has insufficient carry capacity.'):format(displayName(trade.b)) end
    local receiveOk, receiveErr = canReceiveItems(trade.a, bOut)
    if not receiveOk then return nil, receiveErr end
    receiveOk, receiveErr = canReceiveItems(trade.b, aOut)
    if not receiveOk then return nil, receiveErr end

    local aSlots, bSlots = freeSlotsAfter(trade.a, aOut), freeSlotsAfter(trade.b, bOut)
    if #aSlots < #bOut then return nil, ('%s needs more free inventory slots.'):format(displayName(trade.a)) end
    if #bSlots < #aOut then return nil, ('%s needs more free inventory slots.'):format(displayName(trade.b)) end

    local aChar, bChar = character(trade.a), character(trade.b)
    if not aChar or not bChar then return nil, 'Both characters must remain loaded.' end
    local queries = {}
    local function transfer(rows, fromCharId, toCharId, slots)
        for index, row in ipairs(rows) do
            queries[#queries + 1] = {
                query = 'UPDATE character_inventory SET count = count - ? WHERE id = ? AND character_id = ? AND item = ? AND count >= ?',
                values = { row.count, row.id, fromCharId, row.item, row.count },
            }
            queries[#queries + 1] = {
                query = 'DELETE FROM character_inventory WHERE id = ? AND character_id = ? AND count <= 0',
                values = { row.id, fromCharId },
            }
            queries[#queries + 1] = {
                query = 'INSERT INTO character_inventory (character_id, item, count, slot, metadata) VALUES (?, ?, ?, ?, ?)',
                values = { toCharId, row.item, row.count, slots[index], row.metadata and json.encode(row.metadata) or nil },
            }
        end
    end
    transfer(aOut, aChar.id, bChar.id, bSlots)
    transfer(bOut, bChar.id, aChar.id, aSlots)
    local ok = MySQL.transaction.await(queries)
    if not ok then return nil, 'The database rejected the exchange. No items were moved.' end
    ReloadInventory(trade.a)
    ReloadInventory(trade.b)
    return true
end

exports.sunset_core:RegisterCallback('sunset:inventory:tradeRequest', function(source, data)
    local target = tonumber(type(data) == 'table' and data.targetId)
    if not target or target == source then return nil, 'Choose another nearby player.' end
    if TradesByPlayer[source] or TradesByPlayer[target] then return nil, 'One of the players already has an active trade.' end
    if not closeEnough(source, target) then return nil, 'Move within 3.5 metres of that player.' end
    TradeInvites[target] = { from = source, expiresAt = os.time() + INVITE_SECONDS }
    TriggerClientEvent('sunset:inventory:tradeInvite', target, source, displayName(source))
    return { message = ('Trade request sent to %s.'):format(displayName(target)), kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeAccept', function(source)
    local invite = TradeInvites[source]
    TradeInvites[source] = nil
    if not invite or invite.expiresAt < os.time() or not closeEnough(source, invite.from) then
        return nil, 'No valid nearby trade request is waiting.'
    end
    if TradesByPlayer[source] or TradesByPlayer[invite.from] then return nil, 'One of the players already has an active trade.' end
    nextTradeId = nextTradeId + 1
    local trade = { id = nextTradeId, a = invite.from, b = source, offers = {}, accepted = {}, busy = false }
    trade.offers[trade.a], trade.offers[trade.b] = {}, {}
    TradesByPlayer[trade.a], TradesByPlayer[trade.b] = trade, trade
    sendTradeState(trade)
    return { message = ('Trade opened with %s.'):format(displayName(invite.from)) }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeDecline', function(source)
    local invite = TradeInvites[source]
    TradeInvites[source] = nil
    if not invite then return nil, 'No trade request is waiting.' end
    if GetPlayerName(invite.from) then
        TriggerClientEvent('sunset:client:notify', invite.from, ('%s declined your trade request.'):format(displayName(source)), 'info')
    end
    return { message = 'Trade request declined.', kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeOffer', function(source, data)
    local trade = TradesByPlayer[source]
    local valid, err = validateTrade(trade)
    if not valid then if trade then endTrade(trade, err, 'error') end return nil, err end
    local rowId = tonumber(type(data) == 'table' and data.rowId)
    local row = findRow(source, rowId)
    if not row then return nil, 'That item is no longer in your inventory.' end
    local count = math.floor(tonumber(data.count) or tonumber(row.count) or 1)
    if count < 1 or count > (tonumber(row.count) or 0) then return nil, 'Invalid item amount.' end
    trade.offers[source][rowId] = itemView(row, count)
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    return { message = 'Item added to your offer.', kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeRemove', function(source, data)
    local trade = TradesByPlayer[source]
    if not trade then return nil, 'No active trade.' end
    trade.offers[source][tonumber(type(data) == 'table' and data.rowId)] = nil
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    return { message = 'Item removed from your offer.', kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeConfirm', function(source)
    local trade = TradesByPlayer[source]
    local valid, err = validateTrade(trade)
    if not valid then if trade then endTrade(trade, err, 'error') end return nil, err end
    if trade.busy then return nil, 'Trade is already processing.' end
    trade.accepted[source] = true
    if not (trade.accepted[trade.a] and trade.accepted[trade.b]) then
        sendTradeState(trade)
        return { message = 'Offer locked. Waiting for the other player.', kind = 'info' }
    end
    trade.busy = true
    local completed, completeErr = completeTrade(trade)
    if not completed then
        trade.busy = false
        trade.accepted[trade.a], trade.accepted[trade.b] = false, false
        sendTradeState(trade)
        return nil, completeErr
    end
    endTrade(trade, 'Trade completed securely.', 'success')
    return { message = 'Trade completed securely.' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeCancel', function(source)
    local trade = TradesByPlayer[source]
    if not trade then return nil, 'No active trade.' end
    endTrade(trade, ('Trade cancelled by %s.'):format(displayName(source)), 'info')
    return { message = 'Trade cancelled.', kind = 'info' }
end)

local function broadcastDrop(action, drop)
    TriggerClientEvent('sunset:inventory:dropSync', -1, action, drop)
end

exports.sunset_core:RegisterCallback('sunset:inventory:drop', function(source, data)
    local rowId = tonumber(type(data) == 'table' and data.rowId)
    local row = findRow(source, rowId)
    if not row then return nil, 'That item is no longer in your inventory.' end
    local count = math.floor(tonumber(data.count) or tonumber(row.count) or 1)
    if count < 1 or count > (tonumber(row.count) or 0) then return nil, 'Invalid drop amount.' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Your character is not available.' end
    local coords = GetEntityCoords(ped)
    if not RemoveItemById(source, row.id, row.item, count) then return nil, 'Inventory changed before the item could be dropped.' end
    nextDropId = nextDropId + 1
    local drop = {
        id = nextDropId,
        item = row.item,
        label = (Sunset.Items[row.item] and Sunset.Items[row.item].label) or row.item,
        icon = Sunset.Items[row.item] and Sunset.Items[row.item].icon,
        count = count,
        metadata = row.metadata,
        coords = { x = coords.x, y = coords.y, z = coords.z - 0.85 },
        expiresAt = os.time() + DROP_SECONDS,
    }
    Drops[drop.id] = drop
    broadcastDrop('add', drop)
    SetTimeout(DROP_SECONDS * 1000, function()
        if Drops[drop.id] then
            Drops[drop.id] = nil
            DropLocks[drop.id] = nil
            broadcastDrop('remove', { id = drop.id })
        end
    end)
    return { message = ('Dropped %s x%d for 5 minutes.'):format(drop.label, count) }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:pickupDrop', function(source, dropId)
    dropId = tonumber(dropId)
    local drop = dropId and Drops[dropId]
    if not drop or drop.expiresAt <= os.time() then return nil, 'That drop expired or was already collected.' end
    if DropLocks[dropId] then return nil, 'Another player is collecting this drop.' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Your character is not available.' end
    local c = drop.coords
    if #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) > 2.5 then return nil, 'Move closer to the dropped bag.' end
    DropLocks[dropId] = true
    if not TryAddItem(source, drop.item, drop.count, nil, drop.metadata) then
        DropLocks[dropId] = nil
        return nil, 'Not enough inventory weight or free slots for this drop.'
    end
    Drops[dropId] = nil
    DropLocks[dropId] = nil
    broadcastDrop('remove', { id = dropId })
    return { message = ('Picked up %s x%d.'):format(drop.label, drop.count) }
end)

RegisterNetEvent('sunset:server:inventoryRequestDrops', function()
    local source = source
    for _, drop in pairs(Drops) do TriggerClientEvent('sunset:inventory:dropSync', source, 'add', drop) end
end)

AddEventHandler('playerDropped', function()
    local source = source
    TradeInvites[source] = nil
    for target, invite in pairs(TradeInvites) do if invite.from == source then TradeInvites[target] = nil end end
    local trade = TradesByPlayer[source]
    if trade then endTrade(trade, 'Trade cancelled because a player disconnected.', 'error') end
end)
