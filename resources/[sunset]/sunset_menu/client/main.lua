local menuOpen = false
local cachedMugshot = nil
local mugshotAt = 0

local function captureMugshot()
    if cachedMugshot and (GetGameTimer() - mugshotAt) < 45000 then
        return cachedMugshot
    end

    local ped = PlayerPedId()
    local handle = RegisterPedheadshot(ped)
    local timeout = GetGameTimer() + 2500
    while (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not IsPedheadshotValid(handle) then
        UnregisterPedheadshot(handle)
        return nil
    end

    local txd = GetPedheadshotTxdString(handle)
    UnregisterPedheadshot(handle)
    cachedMugshot = ('https://nui-img/%s/%s'):format(txd, txd)
    mugshotAt = GetGameTimer()
    return cachedMugshot
end

local function controlsBlocked()
    return IsNuiFocused() or IsPauseMenuActive()
end

local function fetchMenuExtras()
    local ok, data = pcall(function()
        return Sunset.AwaitCallback('sunset:getMenuData')
    end)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function buildMenuData()
    local char = exports.sunset_core:GetCharacter()
    if not char then return nil end

    local extras = fetchMenuExtras()

    pcall(function()
        local ped = PlayerPedId()
        local currentPlate = nil
        if IsPedInAnyVehicle(ped, false) then
            currentPlate = (GetVehicleNumberPlateText(GetVehiclePedIsIn(ped, false)) or ''):gsub('%s+', ''):upper()
        end
        for _, v in ipairs(extras.vehicles or {}) do
            local plate = (v.plate or ''):gsub('%s+', ''):upper()
            if currentPlate ~= '' and plate ~= '' and (currentPlate == plate or currentPlate:find(plate, 1, true) or plate:find(currentPlate, 1, true)) then
                v.inWorld = true
            else
                v.inWorld = exports.sunset_vehicles:IsPlateInWorld(v.plate)
            end
        end
    end)

    local ped = PlayerPedId()
    local maxHp = GetEntityMaxHealth(ped) - 100
    local hp = GetEntityHealth(ped) - 100
    local health = maxHp > 0 and math.floor((hp / maxHp) * 100) or 0
    local jobId = extras.jobId or select(1, Sunset.GetCharacterJob(char)) or 'unemployed'
    local job = Sunset.CivilianJobs[jobId] or Sunset.Jobs[jobId]

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
        job = extras.jobLabel or (job and job.label) or 'Unemployed',
        jobId = jobId,
        jobGrade = extras.jobGrade or char.job_grade or 0,
        jobGradeLabel = extras.jobGradeLabel or '—',
        jobSalary = extras.jobSalary or 0,
        factionId = extras.factionId,
        factionLabel = extras.factionLabel,
        factionGrade = extras.factionGrade,
        factionGradeLabel = extras.factionGradeLabel,
        factionSalary = extras.factionSalary,
        jobType = extras.jobType or 'civilian',
        hasDuty = extras.hasDuty == true,
        onDuty = extras.onDuty == true,
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
        vehicles = extras.vehicles or {},
        propertyCount = extras.propertyCount or 0,
        homeLabel = extras.homeLabel or 'None',
        avatar = captureMugshot(),
        cid = char.id,
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
    exports.sunset_ui:SetFocus(true, true, false)
    exports.sunset_ui:Send('menuShow', data)
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    exports.sunset_ui:SetFocus(false, false, false)
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
        closeMenu()
        return
    end
    if data.action == 'phone' then
        closeMenu()
        CreateThread(function()
            Wait(150)
            exports.sunset_phone:Open()
        end)
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

AddEventHandler('sunset:nui:menuVehicleAction', function(data)
    if not data or not data.action then return end
    CreateThread(function()
        if data.action == 'spawn' then
            local ok, err = Sunset.AwaitCallback('sunset:spawnVehicle', tonumber(data.vehicleId))
            if ok then
                closeMenu()
            else
                exports.sunset_ui:Notify(err or 'Could not spawn', 'error')
            end
        elseif data.action == 'store' then
            TriggerEvent('sunset:nui:garageStore', { vehicleId = tonumber(data.vehicleId) })
        elseif data.action == 'gps' then
            TriggerEvent('sunset:nui:garageLocate', { plate = data.plate })
        end
    end)
end)

AddEventHandler('sunset:nui:menuJobAction', function(data)
    if not data or not data.action then return end
    CreateThread(function()
        if data.action == 'duty' then
            local state, err = Sunset.AwaitCallback('sunset:toggleDuty')
            if state == nil then exports.sunset_ui:Notify(err or 'Cannot toggle duty', 'error') end
        elseif data.action == 'leave' then
            local ok, err = Sunset.AwaitCallback('sunset:leaveFaction')
            if ok then exports.sunset_ui:Notify('You left your faction', 'warning')
            else exports.sunset_ui:Notify(err or 'Failed', 'error') end
        elseif data.action == 'faction' then
            ExecuteCommand('faction')
        end
    end)
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
