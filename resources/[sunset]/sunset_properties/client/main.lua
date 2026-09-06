local cachedProperties = {}
local insideProperty
local refreshPending = false

local function refreshProperties()
    cachedProperties = Sunset.AwaitCallback('sunset:getProperties') or {}
    TriggerEvent('sunset:client:registerPropertyZones', cachedProperties)
    return cachedProperties
end

local function refreshSoon()
    if refreshPending then return end
    refreshPending = true
    CreateThread(function()
        Wait(400)
        refreshProperties()
        refreshPending = false
    end)
end

AddEventHandler('sunset:client:playerSpawned', function() Wait(1500); refreshProperties() end)
RegisterNetEvent('sunset:client:propertiesChanged', refreshSoon)
RegisterNetEvent('sunset:client:propertyMessage', function(text, kind) exports.sunset_ui:Notify(text or 'House update', kind or 'info', 6500) end)

local function openProperties(properties, selectedId)
    exports.sunset_ui:Send('propertiesShow', { properties = properties or cachedProperties, selectedId = selectedId })
    exports.sunset_ui:SetFocus(true, true)
end

AddEventHandler('sunset:world:propertyInteract', function(prop)
    if insideProperty then return end
    local rows = refreshProperties()
    if prop and prop.id then
        local one = {}
        for _, row in ipairs(rows) do
            if tonumber(row.id) == tonumber(prop.id) then
                one[1] = row
                break
            end
        end
        openProperties(#one > 0 and one or { prop }, prop.id)
        return
    end
    openProperties(rows, prop and prop.id)
end)

local function runAction(action, propertyId)
    local callback = action == 'buy' and 'sunset:buyProperty'
        or action == 'rent' and 'sunset:rentProperty'
        or 'sunset:propertyAction'
    local ok, message
    if callback == 'sunset:propertyAction' then ok, message = Sunset.AwaitCallback(callback, action, propertyId)
    else ok, message = Sunset.AwaitCallback(callback, propertyId) end
    exports.sunset_ui:Notify(message or (ok and 'House updated.' or 'House action failed.'), ok and 'success' or 'error', 6500)
    if ok then
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:Send('propertiesHide', {})
        refreshSoon()
    end
end

AddEventHandler('sunset:nui:propertyAction', function(data)
    CreateThread(function() runAction(tostring(data and data.action or ''), tonumber(data and data.propertyId)) end)
end)

RegisterNetEvent('sunset:client:propertyInterior', function(data)
    if not data or not data.interior then return end
    insideProperty = data
    local ped = PlayerPedId()
    DoScreenFadeOut(400); Wait(500)
    SetEntityCoordsNoOffset(ped, data.interior.x, data.interior.y, data.interior.z, false, false, false)
    SetEntityHeading(ped, data.interior.w or 0.0)
    DisplayRadar(false)
    DoScreenFadeIn(500)
    exports.sunset_ui:Notify(('Inside %s — press E to exit. The radar is hidden indoors so it does not show the shared interior coordinates.'):format(data.label or 'house'), 'info', 6500)
end)

RegisterNetEvent('sunset:client:propertyExited', function(data)
    if not data or not data.entry then return end
    insideProperty = nil
    local ped = PlayerPedId()
    DoScreenFadeOut(400); Wait(500)
    SetEntityCoordsNoOffset(ped, data.entry.x, data.entry.y, data.entry.z, false, false, false)
    SetEntityHeading(ped, data.entry.w or 0.0)
    DisplayRadar(true)
    DoScreenFadeIn(500)
end)

CreateThread(function()
    while true do
        if insideProperty then
            DisplayRadar(false)
            if IsControlJustReleased(0, 38) and not IsNuiFocused() then TriggerServerEvent('sunset:server:exitProperty') end
            Wait(0)
        else Wait(500) end
    end
end)

RegisterCommand('sethome', function(_, args)
    local id = tonumber(args[1])
    if not id then return exports.sunset_ui:Notify('Usage: /sethome [house id]. You must own or rent it.', 'error') end
    CreateThread(function()
        local ok, message = Sunset.AwaitCallback('sunset:setHome', id)
        exports.sunset_ui:Notify(message or 'Home spawn update failed.', ok and 'success' or 'error')
    end)
end, false)

RegisterCommand('properties', function() openProperties(refreshProperties()) end, false)

AddEventHandler('sunset:nui:propertiesClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('propertiesHide', {})
end)
