local inventoryOpen = false
local tradeActive = false

local function openInventory()
    local data, err = Sunset.AwaitCallback('sunset:getInventory')
    if not data then
        return exports.sunset_ui:Notify(err or 'Inventory could not be loaded. Your character may still be loading; try again in a moment.', 'error')
    end
    inventoryOpen = true
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('inventoryShow', data)
end

local function closeInventory()
    if tradeActive then
        tradeActive = false
        CreateThread(function()
            Sunset.AwaitCallback('sunset:inventory:tradeCancel', {})
        end)
    end
    inventoryOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('inventoryHide', {})
end

RegisterNetEvent('sunset:client:inventoryUpdate', function(items, weight)
    if inventoryOpen then
        exports.sunset_ui:Send('inventoryUpdate', { items = items, weight = weight, maxWeight = Sunset.Config.MaxWeight })
    end
end)

AddEventHandler('sunset:client:playerSpawned', function()
    TriggerServerEvent('sunset:server:inventoryLoaded')
end)

AddEventHandler('sunset:nui:inventoryClose', function()
    closeInventory()
end)

RegisterNetEvent('sunset:client:inventoryForceClose', function()
    closeInventory()
end)

AddEventHandler('sunset:nui:inventoryUse', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:useItem', data.item)
    if not ok then exports.sunset_ui:Notify(err or 'Cannot use item', 'error') end
end)

local function inventoryAction(callbackName, data)
    CreateThread(function()
        local result, err = Sunset.AwaitCallback(callbackName, data or {})
        if not result then
            exports.sunset_ui:Notify(err or 'Inventory action failed. Reopen the inventory and try again.', 'error')
        elseif result.message then
            exports.sunset_ui:Notify(result.message, result.kind or 'success')
        end
    end)
end

AddEventHandler('sunset:nui:inventoryTradeRequest', function(data)
    inventoryAction('sunset:inventory:tradeRequest', data)
end)

AddEventHandler('sunset:nui:inventoryTradeOffer', function(data)
    inventoryAction('sunset:inventory:tradeOffer', data)
end)

AddEventHandler('sunset:nui:inventoryTradeRemove', function(data)
    inventoryAction('sunset:inventory:tradeRemove', data)
end)

AddEventHandler('sunset:nui:inventoryTradeConfirm', function(data)
    inventoryAction('sunset:inventory:tradeConfirm', data)
end)

AddEventHandler('sunset:nui:inventoryTradeCancel', function(data)
    inventoryAction('sunset:inventory:tradeCancel', data)
end)

AddEventHandler('sunset:nui:inventoryDrop', function(data)
    inventoryAction('sunset:inventory:drop', data)
end)

RegisterNetEvent('sunset:inventory:tradeState', function(data)
    tradeActive = data and data.active == true
    exports.sunset_ui:Send('inventoryTradeState', data or {})
end)

RegisterNetEvent('sunset:inventory:tradeEnded', function(message, kind)
    tradeActive = false
    exports.sunset_ui:Send('inventoryTradeEnded', {})
    if message then exports.sunset_ui:Notify(message, kind or 'info') end
end)

RegisterNetEvent('sunset:inventory:tradeInvite', function(requesterId, requesterName)
    exports.sunset_ui:Notify(('%s (#%d) wants to trade. Use /accepttrade or /declinetrade within 30 seconds.'):format(
        requesterName or 'A nearby player', tonumber(requesterId) or 0), 'info', 10000)
end)

RegisterCommand('accepttrade', function()
    inventoryAction('sunset:inventory:tradeAccept', {})
end, false)

RegisterCommand('declinetrade', function()
    inventoryAction('sunset:inventory:tradeDecline', {})
end, false)

RegisterCommand('inventory', function()
    if inventoryOpen then
        closeInventory()
        return
    end
    if IsNuiFocused() then return end
    if IsPauseMenuActive() then return end
    local ok, chatOpen = pcall(function() return exports.sunset_chat:IsChatOpen() end)
    if ok and chatOpen then return end
    openInventory()
end, false)
RegisterKeyMapping('inventory', 'Toggle inventory', 'keyboard', 'I')

CreateThread(function()
    while true do
        if inventoryOpen and IsPauseMenuActive() then
            closeInventory()
        end
        Wait(inventoryOpen and 50 or 250)
    end
end)

exports('Open', openInventory)
exports('Close', closeInventory)

local worldDrops = {}
local dropObjects = {}
local DROP_MODEL = `prop_cs_heist_bag_02`

local function removeDropObject(dropId)
    local object = dropObjects[dropId]
    if object and DoesEntityExist(object) then DeleteEntity(object) end
    dropObjects[dropId] = nil
end

local function createDropObject(drop)
    CreateThread(function()
        RequestModel(DROP_MODEL)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(DROP_MODEL) and GetGameTimer() < timeout do Wait(20) end
        if not HasModelLoaded(DROP_MODEL) or not worldDrops[drop.id] then return end
        local c = drop.coords
        local object = CreateObjectNoOffset(DROP_MODEL, c.x, c.y, c.z, false, false, false)
        PlaceObjectOnGroundProperly(object)
        FreezeEntityPosition(object, true)
        SetEntityCollision(object, true, true)
        dropObjects[drop.id] = object
        SetModelAsNoLongerNeeded(DROP_MODEL)
    end)
end

RegisterNetEvent('sunset:inventory:dropSync', function(action, drop)
    if type(drop) ~= 'table' or not tonumber(drop.id) then return end
    drop.id = tonumber(drop.id)
    if action == 'remove' then
        worldDrops[drop.id] = nil
        removeDropObject(drop.id)
        return
    end
    worldDrops[drop.id] = drop
    removeDropObject(drop.id)
    createDropObject(drop)
end)

local function drawDropText(coords, text)
    local visible, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 0.45)
    if not visible then return end
    SetTextFont(4)
    SetTextScale(0.0, 0.29)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 245)
    SetTextDropshadow(2, 0, 0, 0, 220)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('sunset:server:inventoryRequestDrops')
    while true do
        local wait = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local closestId, closestDistance
        for dropId, drop in pairs(worldDrops) do
            local c = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
            local distance = #(coords - c)
            if distance < 18.0 then
                wait = 0
                drawDropText(c, ('~b~[E]~s~ %s x%d'):format(drop.label or drop.item or 'Dropped item', tonumber(drop.count) or 1))
                if distance < 2.2 and (not closestDistance or distance < closestDistance) then
                    closestId, closestDistance = dropId, distance
                end
            end
        end
        if closestId and IsControlJustReleased(0, 38) then
            local result, err = Sunset.AwaitCallback('sunset:inventory:pickupDrop', closestId)
            if not result then
                exports.sunset_ui:Notify(err or 'Could not pick up this item.', 'error')
            elseif result.message then
                exports.sunset_ui:Notify(result.message, 'success')
            end
            Wait(350)
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for dropId in pairs(dropObjects) do removeDropObject(dropId) end
end)
