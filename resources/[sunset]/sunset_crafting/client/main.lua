local craftingOpen = false

local function hasOx()
    return GetResourceState('ox_lib') == 'started'
end

local function runCraftProgress(ms, label)
    if hasOx() then
        return exports.ox_lib:progressBar({
            duration = ms,
            label = label or 'Crafting...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
        })
    end
    Wait(ms)
    return true
end

AddEventHandler('sunset:world:openCrafting', function(stationId, station)
    if IsNuiFocused() then return end
    local data, err = Sunset.AwaitCallback('sunset:getCraftingMenu', stationId)
    if not data then
        exports.sunset_ui:Notify(err or 'Cannot open crafting', 'error')
        return
    end
    craftingOpen = true
    exports.sunset_ui:Send('craftingShow', data)
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:craftingCraft', function(data)
    if not data or not data.stationId or not data.recipeId then return end

    local recipe = Sunset.CraftingRecipes[data.recipeId]
    local duration = recipe and recipe.time or 5000
    local label = recipe and recipe.label or 'Crafting'

    if not runCraftProgress(duration, label) then
        exports.sunset_ui:Notify('Crafting cancelled', 'warning')
        return
    end

    local ok, err = Sunset.AwaitCallback('sunset:craftItem', data.stationId, data.recipeId)
    if ok then
        exports.sunset_ui:Notify('Crafted successfully', 'success')
        local refreshed = Sunset.AwaitCallback('sunset:getCraftingMenu', data.stationId)
        if refreshed then exports.sunset_ui:Send('craftingUpdate', refreshed) end
    else
        exports.sunset_ui:Notify(err or 'Craft failed', 'error')
    end
end)

AddEventHandler('sunset:nui:craftingClose', function()
    craftingOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('craftingHide', {})
end)

CreateThread(function()
    Wait(3500)
    for id, station in pairs(Sunset.CraftingStations or {}) do
        TriggerEvent('sunset:world:registerCraftingStation', id, station)
    end
end)
