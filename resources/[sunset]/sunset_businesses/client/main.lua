local cachedBusinesses = {}

local function notify(msg, kind)
    exports.sunset_ui:Notify(msg, kind or 'info')
end

local function refreshBusinesses()
    cachedBusinesses = Sunset.AwaitCallback('sunset:getBusinesses') or {}
end

CreateThread(function()
    Wait(1500)
    refreshBusinesses()
end)

RegisterNetEvent('sunset:client:businessesChanged', function()
    refreshBusinesses()
end)

RegisterNetEvent('sunset:client:businessTeleport', function(coords)
    if type(coords) ~= 'table' then return end
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x or 0.0, coords.y or 0.0, (coords.z or 0.0) + 0.35, false, false, false, false)
end)

local function openPanel(mode)
    local callbackName = mode == 'admin' and 'sunset:businessAdminDashboard' or 'sunset:businessOwnerDashboard'
    local data, err = Sunset.AwaitCallback(callbackName, {})
    if not data then
        notify(err or 'Could not open business panel.', 'error')
        return
    end
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('businessPanelShow', data)
end

RegisterCommand('abusiness', function()
    openPanel('admin')
end, false)

RegisterCommand('mybusiness', function()
    openPanel('owner')
end, false)

AddEventHandler('sunset:nui:businessPanelsClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('businessPanelHide', {})
end)

AddEventHandler('sunset:nui:businessManage', function(data)
    CreateThread(function()
        local result, message = Sunset.AwaitCallback('sunset:businessManage', data or {})
        if type(result) == 'table' and result.mode then
            exports.sunset_ui:Send('businessPanelShow', result)
        end
        if type(message) == 'string' and message ~= '' then
            notify(message, result and 'success' or 'error')
        elseif not result then
            notify(message or 'Action failed.', 'error')
        end
    end)
end)

AddEventHandler('sunset:nui:businessSelect', function(data)
    CreateThread(function()
        local dashboard, err = Sunset.AwaitCallback('sunset:businessAdminDashboard', tonumber(data and data.businessId))
        if dashboard then
            exports.sunset_ui:Send('businessPanelShow', dashboard)
        else
            notify(err or 'Could not load business.', 'error')
        end
    end)
end)

CreateThread(function()
    while true do
        local sleep = 900
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for _, biz in ipairs(cachedBusinesses) do
            if biz.coords and not biz.owned and biz.forSale then
                local coords = vector3(biz.coords.x, biz.coords.y, biz.coords.z)
                if #(pos - coords) < (SunsetBusinesses.PurchaseRadius or 3.5) then
                    sleep = 0
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(('Press ~INPUT_CONTEXT~ to buy %s ($%s)'):format(
                        biz.label or 'business', biz.price or 0))
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) and not IsNuiFocused() then
                        CreateThread(function()
                            local ok, err = Sunset.AwaitCallback('sunset:buyBusiness', biz.id)
                            if ok then
                                notify(err or 'Business purchased.', 'success')
                                refreshBusinesses()
                            else
                                notify(err or 'Could not buy business.', 'error')
                            end
                        end)
                        Wait(500)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)
