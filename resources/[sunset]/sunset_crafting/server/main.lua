exports.sunset_core:RegisterCallback('sunset:getCraftingMenu', function(source, stationId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil end

    local station = Sunset.CraftingStations[stationId]
    if not station then return nil, 'Unknown station' end

    local factionId, grade = Sunset.GetCharacterFaction(char)

    if station.access == 'faction' then
        if factionId ~= station.faction then return nil, 'Faction members only' end
        if (grade or 0) < (station.minGrade or 0) then return nil, 'Rank too low' end
        if not exports.sunset_factions:IsOnDuty(source) then
            return nil, 'You must be ON DUTY to use this station'
        end
        if station.illegal then
            if not Sunset.HasFactionPerm(factionId, grade, 'craft_illegal') then
                return nil, 'Rank too low for this station'
            end
        end
    end

    local recipes = {}
    for recipeId, recipe in pairs(Sunset.CraftingRecipes) do
        if recipe.station == stationId then
            if recipe.faction and factionId ~= recipe.faction then goto continue end
            if recipe.minGrade and (grade or 0) < recipe.minGrade then goto continue end
            if recipe.illegal and factionId ~= recipe.faction then goto continue end
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
                        }
                    end
                    table.sort(list, function(a, b) return a.label < b.label end)
                    return list
                end)(),
                output = recipe.output,
                outputLabel = (Sunset.Items[recipe.output.item] and Sunset.Items[recipe.output.item].label) or recipe.output.item,
            }
            ::continue::
        end
    end

    if #recipes == 0 then
        return nil, 'No recipes available here (check rank / duty)'
    end

    return { stationId = stationId, stationLabel = station.label, recipes = recipes }
end)

exports.sunset_core:RegisterCallback('sunset:craftItem', function(source, stationId, recipeId)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil, 'No character' end

    local station = Sunset.CraftingStations[stationId]
    local recipe = Sunset.CraftingRecipes[recipeId]
    if not station or not recipe or recipe.station ~= stationId then
        return nil, 'Invalid recipe'
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
        if not exports.sunset_inventory:HasItem(source, item, need) then
            return nil, 'Missing ' .. (Sunset.Items[item] and Sunset.Items[item].label or item)
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
