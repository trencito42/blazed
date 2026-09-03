local menuOpen = false

local function controlsBlocked()
    return IsNuiFocused() or IsPauseMenuActive()
end

local function buildMenuData()
    local char = exports.sunset_core:GetCharacter()
    if not char then return nil end

    local extras = Sunset.AwaitCallback('sunset:getMenuData') or {}

    local ped = PlayerPedId()
    local maxHp = GetEntityMaxHealth(ped) - 100
    local hp = GetEntityHealth(ped) - 100
    local health = maxHp > 0 and math.floor((hp / maxHp) * 100) or 0
    local job = Sunset.Jobs[char.job]

    local fuel, seatbelt, locked
    pcall(function()
        local veh = exports.sunset_vehicles:GetVehicleState()
        if veh then
            fuel = veh.fuel
            seatbelt = veh.seatbelt
            locked = veh.locked
        end
    end)

    local playtimeMin = extras.playtime or 0
    local level = extras.level or char.level or 1
    local xp = extras.xp or char.xp or 0
    local xpMax = math.max(5000, level * 5000)

    local playerData = exports.sunset_core:GetPlayer()
    local displayName = playerData and playerData.name
        or (char.firstname .. (char.lastname ~= '' and (' ' .. char.lastname) or ''))

    local playerData = exports.sunset_core:GetPlayer()

    return {
        id = GetPlayerServerId(PlayerId()),
        name = displayName,
        rank = playtimeMin >= 3000 and 'LOYAL PLAYER' or 'PLAYER',
        level = level,
        xp = xp % xpMax,
        xpMax = xpMax,
        cash = char.cash,
        bank = char.bank,
        premium = extras.premium or (playerData and playerData.premium) or 0,
        job = job and job.label or 'Unemployed',
        faction = char.job or 'unemployed',
        health = math.max(0, math.min(100, health)),
        armor = math.max(0, math.min(100, GetPedArmour(ped))),
        hunger = extras.hunger or char.hunger or 100,
        thirst = extras.thirst or char.thirst or 100,
        stress = extras.stress or char.stress or 0,
        stamina = math.max(0, math.min(100, 100 - (extras.stress or char.stress or 0))),
        fuel = fuel,
        seatbelt = seatbelt,
        locked = locked,
        playtime = extras.playtimeFormatted or '0H 0M',
        lastLogin = extras.lastLogin or '—',
        payday = extras.nextPayday or '—',
        serverTime = extras.serverTime or '—',
        vehicleCount = extras.vehicleCount or 0,
        propertyCount = extras.propertyCount or 0,
        homeLabel = extras.homeLabel or 'None',
    }
end

local function openMenu()
    if menuOpen then return end
    local ok, data = pcall(buildMenuData)
    if not ok or not data then
        exports.sunset_ui:Notify('Could not open menu', 'error')
        return
    end
    menuOpen = true
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('menuShow', data)
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('menuHide', {})
end

RegisterCommand('sunset_menu', function()
    if menuOpen then return end
    openMenu()
end, false)
RegisterKeyMapping('sunset_menu', 'Open player menu', 'keyboard', 'M')

RegisterCommand('sunset_menu_close', function()
    closeMenu()
end, false)
RegisterKeyMapping('sunset_menu_close', 'Close player menu', 'keyboard', 'BACK')

AddEventHandler('sunset:nui:menuClose', function()
    closeMenu()
end)

AddEventHandler('sunset:nui:menuAction', function(data)
    if not data or not data.action then return end
    if data.action == 'inventory' then
        closeMenu()
        ExecuteCommand('inventory')
        return
    end
    if data.action == 'animations' then
        closeMenu()
        ExecuteCommand('emotes')
        return
    end
    if data.action == 'documents' or data.action == 'licenses' then
        return
    end
    if data.action == 'phone' then
        return
    end
    if data.action == 'statistics' then
        local extras = Sunset.AwaitCallback('sunset:getMenuData') or {}
        exports.sunset_ui:Notify(('Level %s | Playtime %s | Next payday %s'):format(
            extras.level or 1,
            extras.playtimeFormatted or '0H 0M',
            extras.nextPayday or '—'
        ), 'info')
        return
    end
end)

CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 244, true) -- M — prevent re-trigger quirks
            local ok, data = pcall(buildMenuData)
            if ok and data then exports.sunset_ui:Send('menuUpdate', data) end
            Wait(1000)
        else
            Wait(500)
        end
    end
end)
