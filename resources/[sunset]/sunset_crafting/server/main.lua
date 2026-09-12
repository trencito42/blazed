exports.sunset_core:RegisterCallback('sunset:getCraftingMenu', function(source, stationId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'Your character is not loaded. Reconnect and select it again.' end

    local station = Sunset.CraftingStations[stationId]
    if not station then return nil, 'This crafting station is not configured.' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - station.coords) > 4.0 then
        return nil, ('Stand inside the marker at %s to craft.'):format(station.label or 'the crafting station')
    end

    local factionId, grade = Sunset.GetCharacterFaction(char)

    if station.access == 'faction' then
        if factionId ~= station.faction then
            return nil, ('%s is available only to %s members.'):format(
                station.label or 'This station',
                Sunset.Factions[station.faction] and Sunset.Factions[station.faction].label or station.faction)
        end
        if (grade or 0) < (station.minGrade or 0) then
            return nil, ('Faction rank %d is required at this station; your rank is %d.'):format(
                station.minGrade or 0, grade or 0)
        end
        if not exports.sunset_factions:IsOnDuty(source) then
            return nil, 'You must be ON DUTY to use this station'
        end
        if station.illegal then
            if not Sunset.HasFactionPerm(factionId, grade, 'craft_illegal') then
                return nil, 'Rank too low for this station'
            end
        end
    end

    local owned = {}
    for _, row in ipairs(exports.sunset_inventory:GetInventory(source) or {}) do
        owned[row.item] = (owned[row.item] or 0) + (tonumber(row.count) or 0)
    end

    local recipes = {}
    for recipeId, recipe in pairs(Sunset.CraftingRecipes) do
        if recipe.station == stationId then
            local lockedReason
            if recipe.faction and factionId ~= recipe.faction then
                lockedReason = 'Wrong faction'
            elseif recipe.minGrade and (grade or 0) < recipe.minGrade then
                lockedReason = ('Requires faction rank %d (yours: %d)'):format(recipe.minGrade, grade or 0)
            elseif recipe.illegal and not Sunset.HasFactionPerm(factionId, grade, 'craft_illegal') then
                lockedReason = 'Your faction rank does not have illegal crafting permission'
            end
            local hasMaterials = true
            recipes[#recipes + 1] = {
                id = recipeId,
                label = recipe.label,
                time = recipe.time,
                inputs = recipe.inputs,
                inputList = (function()
                    local list = {}
                    for item, need in pairs(recipe.inputs) do
                        list[#list + 1] = {
                            item = item,
                            label = (Sunset.Items[item] and Sunset.Items[item].label) or item,
                            count = need,
                            owned = owned[item] or 0,
                        }
                        if (owned[item] or 0) < need then hasMaterials = false end
                    end
                    table.sort(list, function(a, b) return a.label < b.label end)
                    return list
                end)(),
                output = recipe.output,
                outputLabel = (Sunset.Items[recipe.output.item] and Sunset.Items[recipe.output.item].label) or recipe.output.item,
                canCraft = not lockedReason and hasMaterials,
                lockedReason = lockedReason,
            }
        end
    end

    if #recipes == 0 then
        return nil, 'No recipes available here (check rank / duty)'
    end

    return {
        stationId = stationId,
        stationLabel = station.label,
        stationHint = 'Materials are taken from your inventory. Green counts are ready; red counts are missing.',
        recipes = recipes,
    }
end)

local CraftLocks = {}

AddEventHandler('playerDropped', function()
    CraftLocks[source] = nil
end)

exports.sunset_core:RegisterCallback('sunset:craftItem', function(source, stationId, recipeId)
    if CraftLocks[source] then return nil, 'Your previous craft is still being processed. Wait a moment.' end
    CraftLocks[source] = true
    local function done(result, err)
        CraftLocks[source] = nil
        return result, err
    end
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return done(nil, 'Your character is not loaded. Reconnect and try again.') end

    local station = Sunset.CraftingStations[stationId]
    local recipe = Sunset.CraftingRecipes[recipeId]
    if not station or not recipe or recipe.station ~= stationId then
        return done(nil, 'That recipe does not belong to this crafting station. Close and reopen the menu.')
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - station.coords) > 4.0 then
        return done(nil, ('You moved too far away from %s. Return to its marker.'):format(station.label or 'the crafting station'))
    end

    local factionId, grade = Sunset.GetCharacterFaction(char)

    if station.access == 'faction' then
        if factionId ~= station.faction then return done(nil, 'This crafting station belongs to another faction.') end
        if (grade or 0) < (station.minGrade or 0) then return done(nil, 'Your faction rank is too low for this station.') end
        if not exports.sunset_factions:IsOnDuty(source) then return done(nil, 'Go on duty before using this faction station.') end
    end
    if recipe.faction and factionId ~= recipe.faction then return done(nil, 'This recipe belongs to another faction.') end
    if recipe.minGrade and (grade or 0) < recipe.minGrade then return done(nil, 'Your faction rank is too low for this recipe.') end
    if recipe.illegal then
        if not exports.sunset_factions:IsOnDuty(source) then return done(nil, 'Go on duty before crafting this item.') end
        if not Sunset.HasFactionPerm(factionId, grade, 'craft_illegal') then
            return done(nil, 'Your rank does not permit illegal crafting.')
        end
    end

    local out = recipe.output
    local outDef = Sunset.Items[out.item]
    if not outDef then return done(nil, 'This recipe output is not configured. Nothing was consumed.') end
    if outDef.weapon and GetResourceState('sunset_licenses') == 'started'
        and not exports.sunset_licenses:HasLicense(source, 'weapon') then
        return done(nil, 'A valid weapon license is required before crafting a firearm.')
    end

    local failure
    local crafted = MySQL.startTransaction(function(query)
        local rows = query.await(
            'SELECT id, item, count, slot, metadata FROM character_inventory WHERE character_id = ? ORDER BY id FOR UPDATE',
            { char.id }) or {}
        local totals, used, currentWeight = {}, {}, 0
        for _, row in ipairs(rows) do
            totals[row.item] = (totals[row.item] or 0) + (tonumber(row.count) or 0)
            used[tonumber(row.slot)] = true
            local def = Sunset.Items[row.item]
            currentWeight = currentWeight + ((def and tonumber(def.weight) or 0) * (tonumber(row.count) or 0))
        end
        local consumedWeight = 0
        for item, need in pairs(recipe.inputs) do
            need = math.floor(tonumber(need) or 0)
            if need < 1 or (totals[item] or 0) < need then
                failure = ('Missing %s: you have %d, but need %d.'):format(
                    Sunset.Items[item] and Sunset.Items[item].label or item, totals[item] or 0, need)
                error('missing_materials')
            end
            consumedWeight = consumedWeight + ((Sunset.Items[item] and tonumber(Sunset.Items[item].weight) or 0) * need)
        end
        local outCount = math.max(1, math.floor(tonumber(out.count) or 1))
        local finalWeight = currentWeight - consumedWeight + ((tonumber(outDef.weight) or 0) * outCount)
        if finalWeight > (tonumber(Sunset.Config.MaxWeight) or 30) then
            failure = 'Your inventory is too heavy for the crafted output. Nothing was consumed.'
            error('overweight')
        end

        for item, need in pairs(recipe.inputs) do
            local remaining = math.floor(tonumber(need) or 0)
            for _, row in ipairs(rows) do
                if remaining > 0 and row.item == item then
                    local take = math.min(remaining, tonumber(row.count) or 0)
                    if take > 0 then
                        if take == tonumber(row.count) then
                            if query.await('DELETE FROM character_inventory WHERE id = ? AND character_id = ?', { row.id, char.id }) ~= 1 then error('consume_failed') end
                            used[tonumber(row.slot)] = nil
                        else
                            if query.await('UPDATE character_inventory SET count = count - ? WHERE id = ? AND character_id = ? AND count >= ?', { take, row.id, char.id, take }) ~= 1 then error('consume_failed') end
                        end
                        remaining = remaining - take
                    end
                end
            end
            if remaining > 0 then error('consume_failed') end
        end

        local stack
        for _, row in ipairs(rows) do
            if row.item == out.item and (row.metadata == nil or row.metadata == '') then stack = row break end
        end
        if stack then
            if query.await('UPDATE character_inventory SET count = count + ? WHERE id = ? AND character_id = ?', { outCount, stack.id, char.id }) ~= 1 then error('output_failed') end
        else
            local freeSlot
            for slot = 1, tonumber(Sunset.Config.MaxSlots) or 30 do
                if not used[slot] then freeSlot = slot break end
            end
            if not freeSlot then
                failure = 'Your inventory has no free slot for the crafted output. Nothing was consumed.'
                error('no_slot')
            end
            if not query.insert.await('INSERT INTO character_inventory (character_id, item, count, slot) VALUES (?, ?, ?, ?)', { char.id, out.item, outCount, freeSlot }) then error('output_failed') end
        end
    end)
    if not crafted then
        return done(nil, failure or 'Crafting could not be committed. Nothing was consumed; try again.')
    end
    exports.sunset_inventory:ReloadInventory(source)

    return done(true)
end)
