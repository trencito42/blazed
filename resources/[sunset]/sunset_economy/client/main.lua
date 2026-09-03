local paydayTimer = 0
local nearShop = nil
local nearAtm = false

RegisterNetEvent('sunset:client:paydayTimer', function(seconds)
    paydayTimer = seconds
end)

RegisterNetEvent('sunset:client:payday', function(net, tax)
    exports.sunset_ui:Notify(('Payday: +$%s (tax: $%s)'):format(net, tax), 'success', 6000)
end)

exports('GetPaydaySeconds', function() return paydayTimer end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        nearShop = nil
        nearAtm = false

        for id, shop in pairs(Sunset.Shops) do
            if #(coords - shop.coords) < 2.5 then
                nearShop = id
                break
            end
        end

        for _, atm in ipairs(Sunset.ATMs) do
            if #(coords - atm) < 2.0 then nearAtm = true break end
        end

        Wait(500)
    end
end)

CreateThread(function()
    while true do
        if nearShop then
            local shop = Sunset.Shops[nearShop]
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to open ' .. shop.label)
            EndTextCommandDisplayHelp(0, false, true, -1)
            if IsControlJustReleased(0, 38) then
                exports.sunset_ui:Send('shopShow', { shopId = nearShop, shop = shop })
                exports.sunset_ui:SetFocus(true, true)
            end
            Wait(0)
        elseif nearAtm then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to use ATM')
            EndTextCommandDisplayHelp(0, false, true, -1)
            if IsControlJustReleased(0, 38) then
                exports.sunset_ui:Send('atmShow', {})
                exports.sunset_ui:SetFocus(true, true)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
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

exports('GetPaydaySeconds', function() return paydayTimer end)

AddEventHandler('sunset:client:playerSpawned', function()
    TriggerServerEvent('sunset:server:playerSpawned')
    paydayTimer = Sunset.Config.PaydayInterval
end)
