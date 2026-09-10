local nextPaydayLabel = '--:--'
local shopOpen = false
local lastShopOpenAt = 0

RegisterNetEvent('sunset:client:serverTime', function(data)
    if data and data.nextPayday then nextPaydayLabel = data.nextPayday end
end)

local activeWeather = nil

RegisterNetEvent('sunset:client:serverWeather', function(data)
    if not data then return end
    if data.reset then
        activeWeather = nil
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        return
    end
    local weather = string.upper(tostring(data.weather or ''))
    if weather == '' then return end
    activeWeather = weather
    SetWeatherTypeOvertimePersist(weather, 8.0)
end)

CreateThread(function()
    while true do
        if activeWeather then
            SetWeatherTypeNowPersist(activeWeather)
            Wait(5000)
        else
            Wait(2000)
        end
    end
end)

RegisterNetEvent('sunset:client:payday', function(net, tax, breakdown)
    breakdown = type(breakdown) == 'table' and breakdown or {}
    local details = ''
    if (breakdown.civilian or 0) > 0 then details = details .. (' | job $%s'):format(breakdown.civilian) end
    if (breakdown.faction or 0) > 0 then details = details .. (' | faction $%s'):format(breakdown.faction) end
    if (breakdown.rent or 0) > 0 then details = details .. (' | rent -$%s%s'):format(breakdown.rent, breakdown.rentProperty and (' (' .. breakdown.rentProperty .. ')') or '') end
    if (breakdown.respect or 0) > 0 then details = details .. (' | +%s RP'):format(breakdown.respect) end
    if (breakdown.robPoints or 0) > 0 then details = details .. (' | +%s rob points'):format(breakdown.robPoints) end
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
    local now = GetGameTimer()
    if shopOpen or (now - lastShopOpenAt) < 400 then return end
    if GetResourceState('sunset_fishingshop') == 'started' and exports.sunset_fishingshop:IsMenuOpen() then
        return
    end
    shopOpen = true
    lastShopOpenAt = now
    local businessId = nil
    if GetResourceState('sunset_businesses') == 'started' then
        businessId = Sunset.AwaitCallback('sunset:getBusinessForShop', shopId)
    end
    exports.sunset_ui:Send('shopShow', { shopId = shopId, businessId = businessId, shop = enrichShop(shop) })
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:shopClose', function()
    shopOpen = false
end)

AddEventHandler('sunset:world:openAtm', function()
    if IsNuiFocused() then return end
    local char = exports.sunset_core:GetCharacter()
    local name = 'Citizen'
    if char then
        local first = char.first_name or ''
        local last = char.last_name or ''
        if first ~= '' or last ~= '' then
            name = (first .. ' ' .. last):gsub('^%s*(.-)%s*$', '%1')
        end
    end
    local cash = (char and tonumber(char.cash)) or 0
    local bank = (char and tonumber(char.bank)) or 0
    local cid = (char and tonumber(char.id)) or 1
    exports.sunset_ui:Send('atmShow', {
        name = name,
        cash = cash,
        bank = bank,
        cid = cid,
        account = string.format('LS%02d-FLCA-%04d', cid % 100, (cid * 137) % 9000 + 1000),
        card = string.format('4532 88%02d %04d %04d', cid % 100, (cid * 311) % 9000 + 1000, (cid * 743) % 9000 + 1000)
    })
    exports.sunset_ui:SetFocus(true, true)
end)

AddEventHandler('sunset:nui:shopBuy', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:buyItem', data.shopId, data.item, data.amount or 1, data.businessId)
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
        result.ok = true
        result.action = data.action
        result.amount = tonumber(data.amount)
        result.txId = string.format('TX-%d', math.random(100000, 999999))
        exports.sunset_ui:Send('atmUpdate', result)
    else
        exports.sunset_ui:Notify(err or 'Transaction failed', 'error')
        exports.sunset_ui:Send('atmUpdate', { error = err or 'Transaction failed' })
    end
end)

AddEventHandler('sunset:nui:atmClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('atmHide', {})
end)

AddEventHandler('sunset:client:playerSpawned', function()
    TriggerServerEvent('sunset:server:playerSpawned')
end)
