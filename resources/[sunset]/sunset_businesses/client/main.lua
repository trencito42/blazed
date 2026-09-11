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
        if mode == 'admin' then
            notify(err or 'Admin business panel requires staff level 3+. Try /biz for your owned businesses.', 'error')
        else
            notify(err or 'Could not open business panel.', 'error')
        end
        return
    end
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('businessPanelShow', data)
end

local function openOwnerPanel()
    openPanel('owner')
end

local function openAdminPanel()
    openPanel('admin')
end

local function showBizHelp()
    notify('Owner: /biz, /mybiz, /mybusiness | Admin: /biz admin, /abiz, /bizadmin', 'info', 10000)
end

local function runBizCommand(args)
    local sub = args[1] and string.lower(tostring(args[1])) or ''
    if sub == 'admin' or sub == 'a' then
        openAdminPanel()
    elseif sub == 'help' or sub == '?' then
        showBizHelp()
    else
        openOwnerPanel()
    end
end

RegisterNetEvent('sunset:businesses:openPanel', function(mode)
    if mode == 'admin' then
        openAdminPanel()
    elseif mode == 'help' then
        showBizHelp()
    else
        openOwnerPanel()
    end
end)

RegisterCommand('abusiness', openAdminPanel, false)
RegisterCommand('abiz', openAdminPanel, false)
RegisterCommand('bizadmin', openAdminPanel, false)

RegisterCommand('mybusiness', openOwnerPanel, false)
RegisterCommand('mybiz', openOwnerPanel, false)
RegisterCommand('businesses', openOwnerPanel, false)
RegisterCommand('biz', function(_, args) runBizCommand(args or {}) end, false)
RegisterCommand('bizhelp', showBizHelp, false)

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

AddEventHandler('sunset:nui:businessOwnerRefresh', function()
    CreateThread(function()
        local data, err = Sunset.AwaitCallback('sunset:businessOwnerDashboard', {})
        if data then
            exports.sunset_ui:Send('businessOwnerUpdate', data)
        elseif err then
            notify(err, 'error')
        end
    end)
end)

AddEventHandler('sunset:nui:businessAdminRefresh', function()
    CreateThread(function()
        local data, err = Sunset.AwaitCallback('sunset:businessAdminDashboard', {})
        if data then
            exports.sunset_ui:Send('businessAdminUpdate', data)
        elseif err then
            notify(err, 'error')
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

RegisterNetEvent('sunset:businesses:openOwner', function()
    openPanel('owner')
end)

local gasMenuOpen = false
local gasContext = nil
local gasCooldown = false
local GAS_INTERACT_DIST = 6.0

local function formatMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return '$' .. formatted
end

local function closeGasMenu()
    if not gasMenuOpen then return end
    gasMenuOpen = false
    gasContext = nil
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('playerInteractionHide', {})
end

local function openGasBusinessMenu()
    CreateThread(function()
        local ctx = Sunset.AwaitCallback('sunset:getGasBusinessContext')
        if not ctx then
            notify('No gas station business here.', 'error')
            return
        end
        gasContext = ctx
        local actions = {}
        local biz = ctx.business
        if biz and not biz.owned and biz.forSale then
            actions[#actions + 1] = {
                id = 'buy_gas_business',
                label = ('Buy Gas Station (%s)'):format(formatMoney(biz.price)),
                group = 'BUSINESS',
            }
        elseif biz and biz.mine then
            actions[#actions + 1] = {
                id = 'manage_gas_business',
                label = 'Manage Business',
                group = 'BUSINESS',
            }
        end
        if #actions == 0 then
            notify('This gas station is not available for purchase.', 'info')
            return
        end
        exports.sunset_ui:Send('playerInteractionShow', {
            menuTitle = ctx.stationLabel or 'Gas Station',
            target = { name = ctx.stationLabel or 'Gas Station', id = '' },
            actions = actions,
        })
        exports.sunset_ui:SetFocus(true, true)
        gasMenuOpen = true
    end)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local nearGas = false
        for _, station in ipairs(Sunset.GasStations or {}) do
            if station.coords and #(pos - station.coords) < GAS_INTERACT_DIST then
                nearGas = true
                break
            end
        end

        if nearGas and not gasMenuOpen and not gasCooldown and not IsNuiFocused() and not IsPedInAnyVehicle(ped, false) then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ for gas station business')
            EndTextCommandDisplayHelp(0, false, true, -1)
            if IsControlJustPressed(0, 38) then
                openGasBusinessMenu()
            end
            Wait(0)
        else
            if gasMenuOpen and not nearGas then
                closeGasMenu()
            end
            Wait(nearGas and 0 or 400)
        end
    end
end)

AddEventHandler('sunset:nui:playerInteractionClose', function()
    if gasMenuOpen then closeGasMenu() end
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not gasMenuOpen or not data or not data.action then return end
    local action = data.action
    local ctx = gasContext
    closeGasMenu()

    if action == 'buy_gas_business' then
        local biz = ctx and ctx.business
        if not biz or not biz.id then
            notify('This business is not for sale.', 'error')
            return
        end
        gasCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:buyBusiness', biz.id)
            if ok then
                notify(err or 'Business purchased.', 'success')
            else
                notify(err or 'Could not buy business.', 'error')
            end
            SetTimeout(2000, function() gasCooldown = false end)
        end)
    elseif action == 'manage_gas_business' then
        openPanel('owner')
    end
end)
