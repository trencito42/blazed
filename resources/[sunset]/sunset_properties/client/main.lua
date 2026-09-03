local cachedProperties = {}
local cacheTime = 0

local function refreshProperties()
    if GetGameTimer() - cacheTime < 30000 and #cachedProperties > 0 then return cachedProperties end
    cachedProperties = Sunset.AwaitCallback('sunset:getProperties') or {}
    cacheTime = GetGameTimer()
    return cachedProperties
end

local nearProperty = nil

CreateThread(function()
    while true do
        nearProperty = nil
        local coords = GetEntityCoords(PlayerPedId())
        for _, prop in ipairs(refreshProperties()) do
            local entry = prop.entry
            if type(entry) == 'string' then entry = json.decode(entry) end
            if entry and entry.x and #(coords - vector3(entry.x, entry.y, entry.z)) < 2.5 then
                nearProperty = prop
                break
            end
        end
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        if nearProperty then
            local label = nearProperty.label
            local owned = nearProperty.owner_character_id ~= nil
            BeginTextCommandDisplayHelp('STRING')
            if owned then
                AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ — ' .. label .. ' (owned)')
            else
                AddTextComponentSubstringPlayerName(('Press ~INPUT_CONTEXT~ — Buy %s ($%s)'):format(label, nearProperty.price))
            end
            EndTextCommandDisplayHelp(0, false, true, -1)
            if IsControlJustReleased(0, 38) then
                if owned then
                    Sunset.AwaitCallback('sunset:setHome', nearProperty.id)
                    exports.sunset_ui:Notify('Home spawn set to ' .. label, 'success')
                else
                    local ok, err = Sunset.AwaitCallback('sunset:buyProperty', nearProperty.id)
                    if ok then
                        exports.sunset_ui:Notify('You bought ' .. label, 'success')
                        cacheTime = 0
                    else
                        exports.sunset_ui:Notify(err or 'Purchase failed', 'error')
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterCommand('properties', function()
    local props = Sunset.AwaitCallback('sunset:getProperties') or {}
    exports.sunset_ui:Send('propertiesShow', { properties = props })
    exports.sunset_ui:SetFocus(true, true)
end, false)

AddEventHandler('sunset:nui:propertiesClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('propertiesHide', {})
end)

