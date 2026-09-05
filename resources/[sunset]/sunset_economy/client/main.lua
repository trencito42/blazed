local nextPaydayLabel = '--:--'

RegisterNetEvent('sunset:client:serverTime', function(data)
    if data and data.nextPayday then nextPaydayLabel = data.nextPayday end
end)

RegisterNetEvent('sunset:client:payday', function(net, tax, breakdown)
    breakdown = type(breakdown) == 'table' and breakdown or {}
    local details = ''
    if (breakdown.civilian or 0) > 0 then details = details .. (' | job $%s'):format(breakdown.civilian) end
    if (breakdown.faction or 0) > 0 then details = details .. (' | faction $%s'):format(breakdown.faction) end
    if (breakdown.rent or 0) > 0 then details = details .. (' | rent -$%s%s'):format(breakdown.rent, breakdown.rentProperty and (' (' .. breakdown.rentProperty .. ')') or '') end
    if (breakdown.respect or 0) > 0 then details = details .. (' | +%s RP'):format(breakdown.respect) end
    exports.sunset_ui:Notify(('Payday: +$%s (tax: $%s)%s'):format(net, tax, details), 'success', 8000)
end)

exports('GetNextPayday', function() return nextPaydayLabel end)

local function enrichShop(shop)
    local items = {}
    for _, row in ipairs(shop.items or {}) do
        local def = Sunset.Items[row.item] or {}
        items[#items + 1] = {
            item = row.item,
            price = row.price,
            label = def.label or row.item,
            category = def.category or 'misc',
            icon = def.icon or 'backpack',
            weight = def.weight,
        }
    end
    return {
        label = shop.label,
        items = items,
    }
end

AddEventHandler('sunset:world:openShop', function(shopId, shop)
    if IsNuiFocused() then return end
    exports.sunset_ui:Send('shopShow', { shopId = shopId, shop = enrichShop(shop) })
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:world:openAtm', function()
    if IsNuiFocused() then return end
    exports.sunset_ui:Send('atmShow', {})
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:shopBuy', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:buyItem', data.shopId, data.item, data.amount or 1)
    if ok then
        exports.sunset_ui:Notify('Purchase successful', 'success')
    else
        exports.sunset_ui:Notify(err or 'Purchase failed', 'error')
    end
end)

AddEventHandler('sunset:nui:shopClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('shopHide', {})
end)

AddEventHandler('sunset:nui:atmAction', function(data)
    local result, err = Sunset.AwaitCallback('sunset:atmTransfer', data.action, tonumber(data.amount))
    if result then
        exports.sunset_ui:Notify('Transaction complete', 'success')
        exports.sunset_ui:Send('atmUpdate', result)
    else
        exports.sunset_ui:Notify(err or 'Transaction failed', 'error')
    end
end)

AddEventHandler('sunset:nui:atmClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('atmHide', {})
end)

AddEventHandler('sunset:client:playerSpawned', function()
    TriggerServerEvent('sunset:server:playerSpawned')
end)
