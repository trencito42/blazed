local cachedProperties = {}
local insideProperty = nil

local function refreshProperties()
    cachedProperties = Sunset.AwaitCallback('sunset:getProperties') or {}
    TriggerEvent('sunset:client:registerPropertyZones', cachedProperties)
    return cachedProperties
end

AddEventHandler('sunset:client:playerSpawned', function()
    Wait(2000)
    refreshProperties()
end)

AddEventHandler('sunset:world:propertyInteract', function(prop)
    if insideProperty then return end
    if prop.owned then
        Sunset.AwaitCallback('sunset:enterProperty', prop.id)
    else
        local ok, err = Sunset.AwaitCallback('sunset:buyProperty', prop.id)
        if ok then
            exports.sunset_ui:Notify('You bought ' .. prop.label, 'success')
            refreshProperties()
        else
            exports.sunset_ui:Notify(err or 'Purchase failed', 'error')
        end
    end
end)

RegisterNetEvent('sunset:client:propertyInterior', function(data)
    if not data or not data.interior then return end
    insideProperty = data
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(500)
    SetEntityCoordsNoOffset(ped, data.interior.x, data.interior.y, data.interior.z, false, false, false)
    SetEntityHeading(ped, data.interior.w or 0.0)
    DoScreenFadeIn(500)
    exports.sunset_ui:Notify('Inside ' .. (data.label or 'property') .. ' — [E] to exit', 'info', 4000)
end)

RegisterNetEvent('sunset:client:propertyExited', function(data)
    if not data or not data.entry then return end
    insideProperty = nil
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(500)
    SetEntityCoordsNoOffset(ped, data.entry.x, data.entry.y, data.entry.z, false, false, false)
    SetEntityHeading(ped, data.entry.w or 0.0)
    DoScreenFadeIn(500)
end)

CreateThread(function()
    while true do
        if insideProperty then
            if IsControlJustReleased(0, 38) and not IsNuiFocused() then
                TriggerServerEvent('sunset:server:exitProperty', insideProperty.id)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterCommand('sethome', function(_, args)
    local id = tonumber(args[1])
    if not id then
        exports.sunset_ui:Notify('Usage: /sethome [property id]', 'error')
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:setHome', id)
    if ok then exports.sunset_ui:Notify('Home spawn updated', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('properties', function()
    local props = refreshProperties()
    exports.sunset_ui:Send('propertiesShow', { properties = props })
    exports.sunset_ui:SetFocus(true, true)
end, false)

AddEventHandler('sunset:nui:propertiesClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('propertiesHide', {})
end)
