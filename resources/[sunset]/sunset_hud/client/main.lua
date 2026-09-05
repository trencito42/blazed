local nextPaydayLabel = '--:--'
local serverTimeLabel = '00:00'
local defaultLayoutCache = nil
local char = nil
local hudActive = false
local pauseHidden = false

local function nui(action, data)
    exports.sunset_ui:Send(action, data or {})
end

local function getStreetName()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if zone == 'NULL' then zone = 'Los Santos' end
    return street or '—', zone
end

local function getCompassDirection(ped)
    local heading = (GetEntityHeading(ped) + 22.5) % 360.0
    local directions = { 'N', 'NW', 'W', 'SW', 'S', 'SE', 'E', 'NE' }
    local index = math.floor(heading / 45.0) + 1
    return directions[index] or 'N'
end

local function getJobLabel(jobName)
    local job = Sunset.Jobs[jobName]
    return job and job.label or 'Unemployed'
end

local function getGameTime()
    return serverTimeLabel
end

local function formatPayday()
    return nextPaydayLabel
end

local function loadDefaultHudLayout()
    if defaultLayoutCache then return defaultLayoutCache end
    local raw = LoadResourceFile(GetCurrentResourceName(), 'hud_layout_default.json')
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then
            defaultLayoutCache = data
            return data
        end
    end
    return nil
end

local function hasPersonalHudLayout()
    local raw = GetResourceKvpString('sunset_hud_layout')
    return raw ~= nil and raw ~= ''
end

local function getHudLayout()
    local raw = GetResourceKvpString('sunset_hud_layout')
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok then return data end
    end
    return loadDefaultHudLayout()
end

local function readSavedHudLayout()
    local raw = GetResourceKvpString('sunset_hud_layout')
    if not raw or raw == '' then return nil end
    local ok, data = pcall(json.decode, raw)
    if ok then return data end
    return nil
end

local function buildHudData()
    if not char then return nil end

    local ped = PlayerPedId()
    local health = GetEntityHealth(ped) - 100
    local maxHealth = GetEntityMaxHealth(ped) - 100
    local healthPct = maxHealth > 0 and (health / maxHealth) * 100 or 0
    local street, zone = getStreetName()

    local playerData = exports.sunset_core:GetPlayer()
    local displayName = playerData and playerData.name
        or (char.firstname .. (char.lastname ~= '' and (' ' .. char.lastname) or ''))

    local jobId = select(1, Sunset.GetCharacterJob(char))
    local factionId = select(1, Sunset.GetCharacterFaction(char))
    local jobLabel = 'Unemployed'
    if factionId and Sunset.Factions[factionId] then
        jobLabel = Sunset.Factions[factionId].label
    elseif Sunset.Jobs[jobId] then
        jobLabel = Sunset.Jobs[jobId].label
    end

    local data = {
        playerId = GetPlayerServerId(PlayerId()),
        cash = char.cash,
        bank = char.bank,
        name = displayName,
        job = jobLabel,
        health = healthPct,
        armor = GetPedArmour(ped),
        time = getGameTime(),
        payday = formatPayday(),
        street = street,
        zone = zone,
        heading = getCompassDirection(ped),
        inVehicle = false,
        wanted = exports['sunset_hud']:GetWantedLevel(),
    }

    local vehState = nil
    pcall(function()
        vehState = exports.sunset_vehicles:GetVehicleState()
    end)

    if vehState then
        data.inVehicle = true
        data.speed = vehState.speed
        data.gear = vehState.gear
        data.rpm = vehState.rpm
        data.fuel = vehState.fuel
        data.engine = vehState.engine
        data.odometer = vehState.odometer
        data.locked = vehState.locked
        data.seatbelt = vehState.seatbelt
        data.lightMode = vehState.lightMode or 0
        data.engineOn = vehState.engineOn
    end

    return data
end

local function refreshHudLayout(layout)
    if not hudActive then return end
    nui('showHud', {
        playerId = GetPlayerServerId(PlayerId()),
        layout = layout or getHudLayout(),
    })
    local data = buildHudData()
    if data then nui('updateHud', data) end
end

local function activateHud(character)
    char = character
    hudActive = true
    pcall(function()
        nextPaydayLabel = exports.sunset_economy:GetNextPayday() or nextPaydayLabel
    end)
    nui('showHud', {
        playerId = GetPlayerServerId(PlayerId()),
        layout = getHudLayout(),
    })
    local data = buildHudData()
    if data then nui('updateHud', data) end
end

local function updateHud()
    if not hudActive then return end
    local data = buildHudData()
    if data then nui('updateHud', data) end
end

AddEventHandler('sunset:client:playerSpawned', function(character)
    activateHud(character)
end)

AddEventHandler('sunset:client:onCharacterLoaded', function(character)
    char = character
    if not hudActive then
        activateHud(character)
    end
end)

RegisterNetEvent('sunset:client:updateMoney', function(cash, bank)
    if char then
        char.cash = cash or char.cash
        char.bank = bank or char.bank
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(1000)
    local existing = exports.sunset_core:GetCharacter()
    if existing and existing.id then
        activateHud(existing)
    end
end)

function GetPaydaySeconds()
    return 0
end
exports('GetPaydaySeconds', GetPaydaySeconds)

CreateThread(function()
    while true do
        if hudActive and not pauseHidden then
            local veh = nil
            pcall(function() veh = exports.sunset_vehicles:GetVehicleState() end)
            updateHud()
            Wait(veh and 50 or 500)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        local paused = IsPauseMenuActive()
        if paused ~= pauseHidden then
            pauseHidden = paused
            nui('pauseState', { paused = paused })
            DisplayRadar(not paused)
        end
        Wait(paused and 50 or 100)
    end
end)

CreateThread(function()
    while true do
        if hudActive then
            HideHudComponentThisFrame(1)
            HideHudComponentThisFrame(2)
            HideHudComponentThisFrame(3)
            HideHudComponentThisFrame(4)
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
            HideHudComponentThisFrame(13)
            HideHudComponentThisFrame(17)
            HideHudComponentThisFrame(20)
            HideHudComponentThisFrame(21) -- wanted stars
            DisplayAmmoThisFrame(false)
        end
        Wait(0)
    end
end)

RegisterCommand('hudedit', function()
    if not hudActive then return end
    exports.sunset_ui:Send('hudEditToggle', {})
end, false)

RegisterCommand('hudexport', function(_, args)
    local layout = readSavedHudLayout()
    if not layout then
        exports.sunset_ui:Notify('Save your HUD first: /hudedit then Enter', 'error')
        return
    end
    local applyAll = args[1] == 'all'
    TriggerServerEvent('sunset:server:hudExport', layout, applyAll)
end, false)

RegisterCommand('hudreset', function()
    DeleteResourceKvp('sunset_hud_layout')
    refreshHudLayout(getHudLayout())
    exports.sunset_ui:Notify('HUD reset to server default', 'success')
end, false)

RegisterNetEvent('sunset:client:hudDefaultUpdated', function(layout, applyAll)
    if type(layout) ~= 'table' then return end
    defaultLayoutCache = layout
    if applyAll then
        SetResourceKvp('sunset_hud_layout', json.encode(layout))
        refreshHudLayout(layout)
        return
    end
    if not hasPersonalHudLayout() then
        refreshHudLayout(layout)
    end
end)

RegisterNetEvent('sunset:client:serverTime', function(data)
    if not data then return end
    if data.time then serverTimeLabel = data.time end
    if data.nextPayday then nextPaydayLabel = data.nextPayday end
    if data.hour and data.minute then
        NetworkOverrideClockTime(data.hour, data.minute, 0)
    end
end)

RegisterNetEvent('sunset:client:paydayTimer', function()
    -- legacy noop
end)

RegisterNetEvent('sunset:client:updateCharacter', function(updated)
    if char and updated then
        for k, v in pairs(updated) do char[k] = v end
    end
end)

AddEventHandler('sunset:nui:hudEditSave', function(data)
    if type(data) ~= 'table' then return end
    SetResourceKvp('sunset_hud_layout', json.encode(data))
    exports.sunset_ui:Notify('HUD layout saved', 'success')
end)

AddEventHandler('sunset:nui:hudEditClose', function()
    exports.sunset_ui:SetFocus(false, false)
end)
