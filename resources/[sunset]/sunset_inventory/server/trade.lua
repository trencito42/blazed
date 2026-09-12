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

local function offeredCash(trade, owner)
    if not trade or not trade.cash then return 0 end
    return math.max(0, math.floor(tonumber(trade.cash[owner]) or 0))
end

local ASSET_TYPES = { vehicle = true, property = true, business = true }

local function assetsMap(trade, owner)
    return (trade and trade.assets and trade.assets[owner]) or {}
end

local function assetsArray(trade, owner)
    local rows = {}
    for _, asset in pairs(assetsMap(trade, owner)) do
        rows[#rows + 1] = asset
    end
    table.sort(rows, function(a, b)
        local order = { vehicle = 1, property = 2, business = 3 }
        return (order[a.assetType] or 99) < (order[b.assetType] or 99)
    end)
    return rows
end

local function countAssets(trade, owner)
    local count = 0
    for _ in pairs(assetsMap(trade, owner)) do count = count + 1 end
    return count
end

local function tradeSideHasOffer(trade, owner)
    for _ in pairs(trade.offers[owner] or {}) do return true end
    if offeredCash(trade, owner) > 0 then return true end
    if countAssets(trade, owner) > 0 then return true end
    return false
end

local function assetAlreadyOffered(trade, owner, assetType, assetId)
    local offered = assetsMap(trade, owner)[assetType]
    return offered and tonumber(offered.id) == tonumber(assetId)
end

local function validateAssetOwnership(source, asset)
    local char = character(source)
    if not char or not asset or not ASSET_TYPES[asset.assetType] then
        return nil, 'Invalid trade asset.'
    end
    local assetId = tonumber(asset.id)
    if not assetId then return nil, 'Invalid trade asset.' end

    if asset.assetType == 'vehicle' then
        local row = MySQL.single.await(
            'SELECT id, stored, destroyed FROM vehicles WHERE id = ? AND character_id = ?',
            { assetId, char.id }
        )
        if not row then return nil, ('%s no longer owns that vehicle.'):format(displayName(source)) end
        if row.destroyed == 1 or row.destroyed == true or row.destroyed == '1' then
            return nil, 'Destroyed vehicles cannot be traded.'
        end
        if tonumber(row.stored) ~= 1 then
            return nil, 'Only garage-stored vehicles can be traded.'
        end
    elseif asset.assetType == 'property' then
        local row = MySQL.single.await(
            'SELECT id FROM properties WHERE id = ? AND owner_character_id = ? AND enabled = 1',
            { assetId, char.id }
        )
        if not row then return nil, ('%s no longer owns that house.'):format(displayName(source)) end
    elseif asset.assetType == 'business' then
        if GetResourceState('sunset_businesses') ~= 'started' then
            return nil, 'Business trading is unavailable.'
        end
        local row = exports.sunset_businesses:GetBusinessRow(assetId)
        if not row or tonumber(row.ownerCharacterId) ~= tonumber(char.id) then
            return nil, ('%s no longer owns that business.'):format(displayName(source))
        end
    end
    return true
end

local function receiverCanTakeAsset(receiverSource, asset)
    local char = character(receiverSource)
    if not char then return nil, 'Both characters must remain loaded.' end

    if asset.assetType == 'property' then
        local maxOwned = 0
        if GetResourceState('sunset_properties') == 'started' then
            maxOwned = tonumber(exports.sunset_properties:GetMaxOwnedPerCharacter()) or 0
        end
        if maxOwned > 0 then
            local owned = tonumber(MySQL.scalar.await(
                'SELECT COUNT(*) FROM properties WHERE owner_character_id = ?',
                { char.id }
            )) or 0
            if owned >= maxOwned then
                return nil, ('%s cannot own more than %d houses.'):format(displayName(receiverSource), maxOwned)
            end
        end
    elseif asset.assetType == 'business' then
        if GetResourceState('sunset_businesses') ~= 'started' then
            return nil, 'Business trading is unavailable.'
        end
        local maxOwned = 0
        if GetResourceState('sunset_businesses') == 'started' then
            maxOwned = tonumber(exports.sunset_businesses:GetMaxOwnedPerCharacter()) or 0
        end
        if maxOwned > 0 then
            local owned = tonumber(MySQL.scalar.await(
                'SELECT COUNT(*) FROM player_businesses WHERE owner_character_id = ?',
                { char.id }
            )) or 0
            if owned >= maxOwned then
                return nil, ('%s cannot own more than %d businesses.'):format(displayName(receiverSource), maxOwned)
            end
        end
    end
    return true
end

-- [AUDIT P5-06] Removed dead `transferTradeAsset`: a divergent non-transactional
-- asset transfer implementation that was never called (completeTrade uses
-- transferAssets inside the settlement transaction). Kept deleted to prevent
-- future misuse of the unsafe path.

local function buildTradeCatalog(source)
    local char = character(source)
    if not char then return { vehicles = {}, properties = {}, businesses = {} } end
    local trade = TradesByPlayer[source]
    local offered = trade and assetsMap(trade, source) or {}

    local vehicles = {}
    local vehicleRows = MySQL.query.await([[
        SELECT id, plate, model FROM vehicles
        WHERE character_id = ? AND stored = 1 AND (destroyed IS NULL OR destroyed = 0)
        ORDER BY model ASC, plate ASC
    ]], { char.id }) or {}
    for _, row in ipairs(vehicleRows) do
        if not assetAlreadyOffered(trade, source, 'vehicle', row.id) then
            vehicles[#vehicles + 1] = {
                assetType = 'vehicle',
                id = tonumber(row.id),
                label = ('%s · %s'):format(string.upper(row.model or 'vehicle'), row.plate or '?'),
                detail = 'Garage stored',
            }
        end
    end

    local properties = {}
    local propertyRows = MySQL.query.await(
        'SELECT id, label FROM properties WHERE owner_character_id = ? AND enabled = 1 ORDER BY label ASC',
        { char.id }
    ) or {}
    for _, row in ipairs(propertyRows) do
        if not assetAlreadyOffered(trade, source, 'property', row.id) then
            properties[#properties + 1] = {
                assetType = 'property',
                id = tonumber(row.id),
                label = row.label or ('House #%d'):format(row.id),
                detail = 'Owned property',
            }
        end
    end

    local businesses = {}
    if GetResourceState('sunset_businesses') == 'started' then
        for _, row in ipairs(exports.sunset_businesses:GetOwnedBusinesses(source) or {}) do
            if not assetAlreadyOffered(trade, source, 'business', row.id) then
                businesses[#businesses + 1] = {
                    assetType = 'business',
                    id = tonumber(row.id),
                    label = row.label or ('Business #%d'):format(row.id),
                    detail = row.catalogKey or 'Player business',
                }
            end
        end
    end

    return { vehicles = vehicles, properties = properties, businesses = businesses }
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
                myCash = offeredCash(trade, source),
                theirCash = offeredCash(trade, other),
                myAssets = assetsArray(trade, source),
                theirAssets = assetsArray(trade, other),
                myAccepted = trade.accepted[source] == true,
                theirAccepted = trade.accepted[other] == true,
                countdown = trade.countdown or 0,
                finalizing = trade.finalizing == true,
            })
        end
    end
end

local function endTrade(trade, message, kind)
    if not trade then return end
    trade.finalizing = false
    -- [BUGFIX] Reset accept flags: a trade object reused/re-offered with the
    -- same players kept accepted=true and jumped straight to finalizing.
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    trade.busy = false
    trade.countdown = 0
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
        local char = character(owner)
        local cashOffer = offeredCash(trade, owner)
        if cashOffer > 0 and (not char or cashOffer > (tonumber(char.cash) or 0)) then
            return nil, ('%s no longer has enough cash for this trade.'):format(displayName(owner))
        end
        for _, asset in pairs(assetsMap(trade, owner)) do
            local assetOk, assetErr = validateAssetOwnership(owner, asset)
            if not assetOk then return nil, assetErr end
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
    local aCash, bCash = offeredCash(trade, trade.a), offeredCash(trade, trade.b)
    local aAssets, bAssets = assetsArray(trade, trade.a), assetsArray(trade, trade.b)
    if not tradeSideHasOffer(trade, trade.a) and not tradeSideHasOffer(trade, trade.b) then
        return nil, 'Add at least one item, cash, or asset before accepting the trade.'
    end

    for _, asset in ipairs(bAssets) do
        local canTake, takeErr = receiverCanTakeAsset(trade.a, asset)
        if not canTake then return nil, takeErr end
    end
    for _, asset in ipairs(aAssets) do
        local canTake, takeErr = receiverCanTakeAsset(trade.b, asset)
        if not canTake then return nil, takeErr end
    end

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
    -- All offered value is committed on one database connection. Returning false
    -- rolls the complete exchange back; no compensation chain can leave half a
    -- trade behind after a query failure or disconnect.
    -- [BUGFIX "redo the trade"] Two-phase row transfer. The old single-pass
    -- inserted the INCOMING items before the receiver's OUTGOING rows were
    -- deleted, while the pre-computed free-slot list counted slots that only
    -- became free after those deletes -> UNIQUE (character_id, slot) collision
    -- -> whole transaction rolled back ("Trade could not be committed").
    -- Phase 1 consumes both sides; phase 2 inserts both sides into truly free
    -- slots. Fresh metadata is re-read FOR UPDATE per row (P5-06 preserved).
    local function consumeRows(query, rows, fromCharId, collected)
        for _, row in ipairs(rows) do
            local freshRows = query.await(
                'SELECT metadata FROM character_inventory WHERE id = ? AND character_id = ? AND item = ? FOR UPDATE',
                { row.id, fromCharId, row.item })
            local fresh = freshRows and freshRows[1]
            if not fresh then return false end
            local changed = query.await(
                'UPDATE character_inventory SET count = count - ? WHERE id = ? AND character_id = ? AND item = ? AND count >= ?',
                { row.count, row.id, fromCharId, row.item, row.count })
            if tonumber(changed) ~= 1 then return false end
            query.await('DELETE FROM character_inventory WHERE id = ? AND character_id = ? AND count <= 0',
                { row.id, fromCharId })
            local freshMeta = fresh.metadata
            if type(freshMeta) == 'table' then
                freshMeta = next(freshMeta) ~= nil and json.encode(freshMeta) or nil
            elseif freshMeta == '' then
                freshMeta = nil
            end
            collected[#collected + 1] = { item = row.item, count = row.count, metadata = freshMeta }
        end
        return true
    end

    local function insertRows(query, collected, toCharId, slots)
        for index, row in ipairs(collected) do
            local inserted = query.await(
                'INSERT INTO character_inventory (character_id, item, count, slot, metadata) VALUES (?, ?, ?, ?, ?)',
                { toCharId, row.item, row.count, slots[index], row.metadata })
            if not inserted then return false end
        end
        return true
    end

    local function transferAssets(query, rows, fromCharId, toCharId)
        for _, asset in ipairs(rows) do
            local changed
            if asset.assetType == 'vehicle' then
                changed = query.await([[UPDATE vehicles SET character_id = ?, stored = 1
                    WHERE id = ? AND character_id = ? AND stored = 1 AND (destroyed IS NULL OR destroyed = 0)]],
                    { toCharId, asset.id, fromCharId })
            elseif asset.assetType == 'property' then
                changed = query.await('UPDATE properties SET owner_character_id = ? WHERE id = ? AND owner_character_id = ? AND enabled = 1',
                    { toCharId, asset.id, fromCharId })
                if tonumber(changed) == 1 then
                    query.await('UPDATE property_rentals SET active = 0 WHERE property_id = ?', { asset.id })
                    query.await('UPDATE characters SET home_property_id = NULL WHERE home_property_id = ?', { asset.id })
                end
            elseif asset.assetType == 'business' then
                changed = query.await('UPDATE player_businesses SET owner_character_id = ?, for_sale = 0 WHERE id = ? AND owner_character_id = ?',
                    { toCharId, asset.id, fromCharId })
            end
            if tonumber(changed) ~= 1 then return false end
        end
        return true
    end

    local transactionOk = MySQL.startTransaction(function(query)
        -- Phase 1: consume BOTH sides first (frees the receiver's outgoing slots)
        local toB, toA = {}, {}
        if not consumeRows(query, aOut, aChar.id, toB) then return false end
        if not consumeRows(query, bOut, bChar.id, toA) then return false end

        local aDelta, bDelta = bCash - aCash, aCash - bCash
        if aDelta ~= 0 then
            local changed = query.await('UPDATE characters SET cash = cash + ? WHERE id = ? AND cash + ? >= 0',
                { aDelta, aChar.id, aDelta })
            if tonumber(changed) ~= 1 then return false end
        end
        if bDelta ~= 0 then
            local changed = query.await('UPDATE characters SET cash = cash + ? WHERE id = ? AND cash + ? >= 0',
                { bDelta, bChar.id, bDelta })
            if tonumber(changed) ~= 1 then return false end
        end

        -- Phase 2: insert into now-truly-free slots
        if not insertRows(query, toB, bChar.id, bSlots) then return false end
        if not insertRows(query, toA, aChar.id, aSlots) then return false end

        if not transferAssets(query, aAssets, aChar.id, bChar.id) then return false end
        if not transferAssets(query, bAssets, bChar.id, aChar.id) then return false end
        return true
    end)
    if not transactionOk then
        return nil, 'Trade could not be committed because an offer changed. Nothing was moved; review both offers and retry.'
    end

    ReloadInventory(trade.a)
    ReloadInventory(trade.b)
    exports.sunset_core:RefreshMoney(trade.a)
    exports.sunset_core:RefreshMoney(trade.b)
    -- [AUDIT P1-02] The transaction writes characters.cash directly (atomic, guarded);
    -- record it in the money ledger so trade cash is audited like every other flow.
    local cashDelta = (bCash or 0) - (aCash or 0) -- cash received by side A
    if cashDelta ~= 0 then
        local aAfter = character(trade.a)
        local bAfter = character(trade.b)
        exports.sunset_core:LogMoneyTransaction(aChar.id, 'cash',
            cashDelta > 0 and 'in' or 'out', math.abs(cashDelta), 'player_trade',
            aAfter and tonumber(aAfter.cash) or nil)
        exports.sunset_core:LogMoneyTransaction(bChar.id, 'cash',
            cashDelta > 0 and 'out' or 'in', math.abs(cashDelta), 'player_trade',
            bAfter and tonumber(bAfter.cash) or nil)
    end
    if #aAssets + #bAssets > 0 then
        TriggerClientEvent('sunset:client:propertiesChanged', -1)
        TriggerClientEvent('sunset:client:businessesChanged', -1)
    end
    -- [QUESTS] social chain: first completed trade counts for BOTH parties.
    TriggerEvent('sunset:quest:progress', aChar.id, 'first_trade', 1)
    TriggerEvent('sunset:quest:progress', bChar.id, 'first_trade', 1)
    return true
end

exports.sunset_core:RegisterCallback('sunset:inventory:tradeRequest', function(source, data)
    local target = tonumber(type(data) == 'table' and data.targetId)
    if not target or target == source then return nil, 'Choose another nearby player.' end
    -- [AUDIT P6-05] Downed/jailed players cannot trade (neither side).
    if exports.sunset_core:IsIncapacitated(source) or exports.sunset_core:IsIncapacitated(target) then
        return nil, 'One of the players cannot trade right now.'
    end
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
    local trade = { id = nextTradeId, a = invite.from, b = source, offers = {}, cash = {}, assets = {}, accepted = {}, busy = false }
    trade.offers[trade.a], trade.offers[trade.b] = {}, {}
    trade.cash[trade.a], trade.cash[trade.b] = 0, 0
    trade.assets[trade.a], trade.assets[trade.b] = {}, {}
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
    trade.finalizing = false
    trade.countdown = 0
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    return { message = 'Item added to your offer.', kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeRemove', function(source, data)
    local trade = TradesByPlayer[source]
    if not trade then return nil, 'No active trade.' end
    trade.offers[source][tonumber(type(data) == 'table' and data.rowId)] = nil
    trade.finalizing = false
    trade.countdown = 0
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    return { message = 'Item removed from your offer.', kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeOfferCash', function(source, data)
    local trade = TradesByPlayer[source]
    local valid, err = validateTrade(trade)
    if not valid then if trade then endTrade(trade, err, 'error') end return nil, err end
    local char = character(source)
    if not char then return nil, 'Character not loaded.' end
    local amount = math.floor(tonumber(type(data) == 'table' and data.amount) or 0)
    if amount < 0 then return nil, 'Invalid cash amount.' end
    if amount > (tonumber(char.cash) or 0) then return nil, 'You do not have that much cash.' end
    trade.cash[source] = amount
    trade.finalizing = false
    trade.countdown = 0
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    if amount > 0 then
        return { message = ('$%s added to your offer.'):format(amount), kind = 'info' }
    end
    return { message = 'Cash removed from your offer.', kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeCatalog', function(source)
    local trade = TradesByPlayer[source]
    if not trade then return nil, 'No active trade.' end
    return buildTradeCatalog(source)
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeOfferAsset', function(source, data)
    local trade = TradesByPlayer[source]
    local valid, err = validateTrade(trade)
    if not valid then if trade then endTrade(trade, err, 'error') end return nil, err end

    local assetType = type(data) == 'table' and data.assetType
    local assetId = tonumber(type(data) == 'table' and data.id)
    if not ASSET_TYPES[assetType] or not assetId then return nil, 'Invalid trade asset.' end
    if assetsMap(trade, source)[assetType] then
        return nil, 'Remove your current asset offer of that type first.'
    end

    local catalog = buildTradeCatalog(source)
    local match
    for _, list in ipairs({ catalog.vehicles, catalog.properties, catalog.businesses }) do
        for _, entry in ipairs(list or {}) do
            if entry.assetType == assetType and tonumber(entry.id) == assetId then
                match = entry
                break
            end
        end
        if match then break end
    end
    if not match then return nil, 'That asset is no longer available to trade.' end

    local assetOk, assetErr = validateAssetOwnership(source, match)
    if not assetOk then return nil, assetErr end

    trade.assets[source][assetType] = match
    trade.finalizing = false
    trade.countdown = 0
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    return { message = ('%s added to your offer.'):format(match.label), kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeRemoveAsset', function(source, data)
    local trade = TradesByPlayer[source]
    if not trade then return nil, 'No active trade.' end
    local assetType = type(data) == 'table' and data.assetType
    if not ASSET_TYPES[assetType] then return nil, 'Invalid trade asset.' end
    trade.assets[source][assetType] = nil
    trade.finalizing = false
    trade.countdown = 0
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    return { message = 'Asset removed from your offer.', kind = 'info' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeRemoveCash', function(source)
    local trade = TradesByPlayer[source]
    if not trade then return nil, 'No active trade.' end
    trade.cash[source] = 0
    trade.finalizing = false
    trade.countdown = 0
    trade.accepted[trade.a], trade.accepted[trade.b] = false, false
    sendTradeState(trade)
    return { message = 'Cash removed from your offer.', kind = 'info' }
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

    -- Both players have accepted! Initiate 5-second final review & decline countdown
    if not trade.finalizing then
        trade.finalizing = true
        trade.countdown = 5
        sendTradeState(trade)
        CreateThread(function()
            local currentTradeId = trade.id
            for c = 4, 0, -1 do
                Wait(1000)
                if TradesByPlayer[trade.a] ~= trade or TradesByPlayer[trade.b] ~= trade or trade.id ~= currentTradeId then
                    return
                end
                if not trade.finalizing or not (trade.accepted[trade.a] and trade.accepted[trade.b]) then
                    return
                end
                trade.countdown = c
                sendTradeState(trade)
            end

            -- 5 seconds completed without cancellation! Complete trade!
            if TradesByPlayer[trade.a] ~= trade or TradesByPlayer[trade.b] ~= trade or trade.id ~= currentTradeId then
                return
            end
            if not trade.finalizing or not (trade.accepted[trade.a] and trade.accepted[trade.b]) then
                return
            end

            trade.busy = true
            local completed, completeErr = completeTrade(trade)
            if not completed then
                trade.busy = false
                trade.finalizing = false
                trade.countdown = 0
                trade.accepted[trade.a], trade.accepted[trade.b] = false, false
                sendTradeState(trade)
                for _, src in ipairs({ trade.a, trade.b }) do
                    TriggerClientEvent('sunset:client:notify', src, completeErr or 'Trade failed to process.', 'error')
                end
                return
            end
            endTrade(trade, 'Trade completed securely.', 'success')
        end)
        return { message = 'Both accepted! Finalizing in 5 seconds (Cancel anytime).', kind = 'info' }
    end
    return { message = 'Offer locked.' }
end)

exports.sunset_core:RegisterCallback('sunset:inventory:tradeCancel', function(source)
    local trade = TradesByPlayer[source]
    if not trade then return nil, 'No active trade.' end
    trade.finalizing = false
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
    -- [AUDIT P2-10] Throttle the full drop-table dump to prevent DoS amplification.
    if not exports.sunset_core:RateLimit(source, 'requestDrops', 5000) then return end
    for _, drop in pairs(Drops) do TriggerClientEvent('sunset:inventory:dropSync', source, 'add', drop) end
end)

AddEventHandler('playerDropped', function()
    local source = source
    TradeInvites[source] = nil
    for target, invite in pairs(TradeInvites) do if invite.from == source then TradeInvites[target] = nil end end
    local trade = TradesByPlayer[source]
    if trade then endTrade(trade, 'Trade cancelled because a player disconnected.', 'error') end
end)

-- [AUDIT P8-14] End any active trade when a party is downed or jailed, so the
-- trade modal + NUI focus do not survive death/arrest (previously only distance
-- or disconnect ended it).
local function endTradeForSource(src, reason)
    local trade = TradesByPlayer[src]
    if trade then endTrade(trade, reason, 'error') end
    TradeInvites[src] = nil
    for target, invite in pairs(TradeInvites) do if invite.from == src then TradeInvites[target] = nil end end
end

AddEventHandler('sunset:death:playerDowned', function(src)
    endTradeForSource(src, 'Trade cancelled because a player was downed.')
end)

AddEventHandler('sunset:faction:playerJailed', function(src)
    endTradeForSource(src, 'Trade cancelled because a player was jailed.')
end)
