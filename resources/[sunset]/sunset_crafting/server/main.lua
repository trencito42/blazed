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

exports.sunset_core:RegisterCallback('sunset:craftItem', function(source, stationId, recipeId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local station = Sunset.CraftingStations[stationId]
    local recipe = Sunset.CraftingRecipes[recipeId]
    if not station or not recipe or recipe.station ~= stationId then
        return nil, 'That recipe does not belong to this crafting station. Close and reopen the menu.'
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - station.coords) > 4.0 then
        return nil, ('You moved too far away from %s. Return to its marker.'):format(station.label or 'the crafting station')
    end

    local factionId, grade = Sunset.GetCharacterFaction(char)

    if station.access == 'faction' then
        if factionId ~= station.faction then return nil, 'Faction only' end
        if (grade or 0) < (station.minGrade or 0) then return nil, 'Rank too low' end
        if not exports.sunset_factions:IsOnDuty(source) then return nil, 'Must be on duty' end
    end
    if recipe.faction and factionId ~= recipe.faction then return nil, 'Wrong faction' end
    if recipe.minGrade and (grade or 0) < recipe.minGrade then return nil, 'Rank too low' end
    if recipe.illegal then
        if not exports.sunset_factions:IsOnDuty(source) then return nil, 'Must be on duty' end
        if not Sunset.HasFactionPerm(factionId, grade, 'craft_illegal') then
            return nil, 'Rank too low'
        end
    end

    for item, need in pairs(recipe.inputs) do
        local have = exports.sunset_inventory:CountItem(source, item) or 0
        if have < need then
            return nil, ('Missing %s: you have %d, but need %d.'):format(
                Sunset.Items[item] and Sunset.Items[item].label or item, have, need)
        end
    end

    for item, need in pairs(recipe.inputs) do
        exports.sunset_inventory:RemoveItem(source, item, need)
    end

    local out = recipe.output
    if not exports.sunset_inventory:AddItem(source, out.item, out.count or 1) then
        for item, need in pairs(recipe.inputs) do
            exports.sunset_inventory:AddItem(source, item, need)
        end
        return nil, 'Inventory full'
    end

    return true
end)
