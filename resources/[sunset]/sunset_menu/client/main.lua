local menuOpen = false
local menuSoloMode = nil
local cachedMugshot = nil
local mugshotAt = 0
local mugshotHandle = nil
local cachedExtras = nil
local cachedExtrasAt = 0

local function releaseMugshot()
    if mugshotHandle then
        UnregisterPedheadshot(mugshotHandle)
        mugshotHandle = nil
    end
    cachedMugshot = nil
    mugshotAt = 0
end

local function captureMugshot()
    if cachedMugshot and (GetGameTimer() - mugshotAt) < 45000 then
        return cachedMugshot
    end

    releaseMugshot()

    local ped = PlayerPedId()
    for attempt = 1, 2 do
        local handle = RegisterPedheadshot(ped)
        local timeout = GetGameTimer() + (attempt == 1 and 2500 or 4500)
        while (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) and GetGameTimer() < timeout do
            Wait(10)
        end

        if IsPedheadshotValid(handle) then
            local txd = GetPedheadshotTxdString(handle)
            mugshotHandle = handle
            cachedMugshot = ('https://nui-img/%s/%s'):format(txd, txd)
            mugshotAt = GetGameTimer()
            return cachedMugshot
        end

        UnregisterPedheadshot(handle)
        if attempt == 1 then Wait(350) end
    end

    return nil
end

AddEventHandler('sunset:client:onCharacterLoaded', function()
    releaseMugshot()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then releaseMugshot() end
end)

local function controlsBlocked()
    return IsNuiFocused() or IsPauseMenuActive()
end

local function fetchMenuExtras(force)
    if not force and cachedExtras and (GetGameTimer() - cachedExtrasAt) < 5000 then
        return cachedExtras
    end
    local ok, data = pcall(function()
        return Sunset.AwaitCallback('sunset:getMenuData')
    end)
    if ok and type(data) == 'table' then
        cachedExtras = data
        cachedExtrasAt = GetGameTimer()
        return data
    end
    return cachedExtras or {}
end

local function buildMenuData(forceExtras)
    local char = exports.sunset_core:GetCharacter()
    if not char then return nil end

    local extras = fetchMenuExtras(forceExtras)

    pcall(function()
        local ped = PlayerPedId()
        local currentPlate = nil
        local currentVehicle = 0
        if IsPedInAnyVehicle(ped, false) then
            currentVehicle = GetVehiclePedIsIn(ped, false)
            currentPlate = (GetVehicleNumberPlateText(currentVehicle) or ''):gsub('%s+', ''):upper()
        end
        for _, v in ipairs(extras.vehicles or {}) do
            local plate = (v.plate or ''):gsub('%s+', ''):upper()
            if currentPlate ~= nil and currentPlate ~= '' and plate == currentPlate then
                v.inWorld = true
                v.fuel = exports.sunset_vehicles:GetFuelLevel()
                v.engine = GetVehicleEngineHealth(currentVehicle)
                v.body = GetVehicleBodyHealth(currentVehicle)
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
    local respect = extras.respectPoints or char.respect_points or 0
    local respectRequired = extras.respectRequired or Sunset.GetLevelRespectCost(level)

    local playerData = exports.sunset_core:GetPlayer()
    local displayName = playerData and playerData.name
        or (char.firstname .. (char.lastname ~= '' and (' ' .. char.lastname) or ''))

    local properties = {}
    local propertyMeta = nil
    pcall(function()
        properties = Sunset.AwaitCallback('sunset:getProperties') or {}
        propertyMeta = Sunset.AwaitCallback('sunset:getPropertyMeta') or {}
    end)

    return {
        id = GetPlayerServerId(PlayerId()),
        name = displayName,
        rank = playtimeMin >= 3000 and 'LOYAL PLAYER' or 'PLAYER',
        level = level,
        respectPoints = respect,
        respectRequired = respectRequired,
        levelPrice = extras.levelPrice or Sunset.GetLevelMoneyCost(level),
        paydaysReceived = extras.paydaysReceived or char.paydays_received or 0,
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
        characterCreated = extras.characterCreated or '—',
        sessionTime = extras.sessionFormatted or '0H 0M',
        completedTasks = extras.completedTasks or 0,
        careerEarnings = extras.careerEarnings or 0,
        combinedSkillLevels = extras.combinedSkillLevels or 0,
        payday = extras.nextPayday or '—',
        serverTime = extras.serverTime or '—',
        vehicleCount = extras.vehicleCount or 0,
        vehicles = extras.vehicles or {},
        propertyCount = extras.propertyCount or 0,
        homeLabel = extras.homeLabel or 'None',
        properties = properties,
        propertyMeta = propertyMeta,
        avatar = captureMugshot(),
        cid = char.id,
    }
end

local function openMenu(initialTab, opts)
    if menuOpen then
        if initialTab then
            exports.sunset_ui:Send('menuSetTab', { tab = initialTab, soloMode = menuSoloMode })
        end
        return
    end
    local ok, data = pcall(buildMenuData, true)
    if not ok or not data then
        exports.sunset_ui:Notify('Could not open menu', 'error')
        return
    end
    if initialTab then
        data.initialTab = initialTab
    end
    if opts and opts.solo then
        data.soloMode = opts.solo
        menuSoloMode = opts.solo
    else
        menuSoloMode = nil
    end
    menuOpen = true
    exports.sunset_ui:SetFocus(true, true, false)
    exports.sunset_ui:Send('menuShow', data)
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    menuSoloMode = nil
    exports.sunset_ui:SetFocus(false, false, false)
    exports.sunset_ui:Send('menuHide', {})
end

local function openVehicleMenu()
    if menuOpen then
        if menuSoloMode == 'vehicle' then
            closeMenu()
            return
        end
        closeMenu()
        Wait(50)
    end
    openMenu('vehicle', { solo = 'vehicle' })
end

AddEventHandler('sunset:menu:openVehicle', openVehicleMenu)
exports('OpenVehicle', openVehicleMenu)

local function toggleMenu(initialTab)
    if menuOpen then
        if initialTab and not menuSoloMode then
            exports.sunset_ui:Send('menuSetTab', { tab = initialTab })
            return
        end
        closeMenu()
        return
    end
    openMenu(initialTab)
end

RegisterCommand('sunset_menu', function()
    toggleMenu()
end, false)
RegisterKeyMapping('sunset_menu', 'Toggle player menu', 'keyboard', 'M')

RegisterCommand('chatsettings', function()
    toggleMenu('settings')
end, false)
RegisterCommand('stats', function() toggleMenu('statistics') end, false)
TriggerEvent('chat:addSuggestion', '/stats', 'Open character statistics and Respect Point progression')
TriggerEvent('chat:addSuggestion', '/buylevel', 'Buy the next level using the required Respect Points and money')
TriggerEvent('chat:addSuggestion', '/chatsettings', 'Open chat font size and visible row settings')

RegisterCommand('sunset_menu_close', function()
    closeMenu()
end, false)
RegisterKeyMapping('sunset_menu_close', 'Close player menu', 'keyboard', 'BACK')

AddEventHandler('sunset:nui:menuClose', function()
    closeMenu()
end)

AddEventHandler('sunset:properties:updated', function(properties, meta)
    if not menuOpen then return end
    local data = buildMenuData(false)
    if not data then return end
    data.properties = properties or data.properties
    data.propertyMeta = meta or data.propertyMeta
    exports.sunset_ui:Send('menuPropertyUpdate', data)
end)

AddEventHandler('sunset:properties:closeMenu', function()
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
        local command = data.action == 'documents' and 'id' or 'licenses'
        CreateThread(function()
            Wait(150)
            ExecuteCommand(command)
        end)
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
    if data.action == 'properties' then
        closeMenu()
        CreateThread(function()
            Wait(150)
            ExecuteCommand('properties')
        end)
        return
    end
    if data.action == 'buy_level' then
        CreateThread(function()
            local ok, message = Sunset.AwaitCallback('sunset:buyLevel')
            exports.sunset_ui:Notify(message or (ok and 'Level purchased.' or 'Level purchase failed.'), ok and 'success' or 'error')
            if not menuOpen then return end
            cachedExtras = nil
            cachedExtrasAt = 0
            local refreshed, menuData = pcall(buildMenuData, true)
            if refreshed and menuData then
                exports.sunset_ui:Send('menuUpdate', menuData)
            end
        end)
        return
    end
    if data.action == 'pass' then
        closeMenu()
        CreateThread(function()
            Wait(150)
            ExecuteCommand('pass')
        end)
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
            TriggerEvent('sunset:nui:garageLocate', {
                plate = data.plate,
                vehicleId = tonumber(data.vehicleId),
            })
        end
    end)
end)

AddEventHandler('sunset:nui:menuJobAction', function(data)
    if not data or not data.action then return end
    CreateThread(function()
        if data.action == 'duty' then
            local state, err = Sunset.AwaitCallback('sunset:toggleDuty')
            if state == nil then
                exports.sunset_ui:Notify(err or 'Cannot toggle duty', 'error')
            else
                cachedExtrasAt = 0
            end
        elseif data.action == 'leave' then
            local ok, err = Sunset.AwaitCallback('sunset:leaveFaction')
            if ok then
                cachedExtrasAt = 0
                closeMenu()
            else
                exports.sunset_ui:Notify(err or 'Failed', 'error')
            end
        elseif data.action == 'quit_civilian' then
            local ok, err = Sunset.AwaitCallback('sunset:quitCivilianJob')
            if ok then
                cachedExtrasAt = 0
                closeMenu()
            else
                exports.sunset_ui:Notify(err or 'Could not quit civilian job', 'error')
            end
        elseif data.action == 'faction' then
            closeMenu()
            Wait(100)
            ExecuteCommand('faction')
        end
    end)
end)

CreateThread(function()
    local MENU_CONTROL = 244 -- M
    while true do
        if menuOpen then
            DisableControlAction(0, MENU_CONTROL, true)
            if IsDisabledControlJustReleased(0, MENU_CONTROL) then
                closeMenu()
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        if menuOpen then
            local ok, data = pcall(buildMenuData)
            if ok and data then exports.sunset_ui:Send('menuUpdate', data) end
            Wait(1000)
        else
            Wait(500)
        end
    end
end)
