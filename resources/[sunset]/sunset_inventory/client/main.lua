local inventoryOpen = false

local function openInventory()
    local data = Sunset.AwaitCallback('sunset:getInventory')
    if not data then return end
    inventoryOpen = true
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('inventoryShow', data)
end

local function closeInventory()
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

RegisterCommand('inventory', function()
    if inventoryOpen then
        closeInventory()
        return
    end
    if IsNuiFocused() then return end
    local ok, chatOpen = pcall(function() return exports.sunset_chat:IsChatOpen() end)
    if ok and chatOpen then return end
    openInventory()
end, false)
RegisterKeyMapping('inventory', 'Toggle inventory', 'keyboard', 'I')

exports('Open', openInventory)
exports('Close', closeInventory)
