local hudActive = false
local char = nil
local paydayTimer = 0

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

local function getJobLabel(jobName)
    local job = Sunset.Jobs[jobName]
    return job and job.label or 'Șomer'
end

local function getGameTime()
    return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
end

local function formatPayday(seconds)
    return ('%02d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function getHudLayout()
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

    local data = {
        playerId = GetPlayerServerId(PlayerId()),
        cash = char.cash,
        bank = char.bank,
        name = char.firstname .. ' ' .. char.lastname,
        job = getJobLabel(char.job),
        health = healthPct,
        armor = GetPedArmour(ped),
        time = getGameTime(),
        payday = formatPayday(paydayTimer),
        street = street,
        zone = zone,
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
        data.locked = vehState.locked
        data.seatbelt = vehState.seatbelt
        data.lightMode = vehState.lightMode or 0
        data.engineOn = vehState.engineOn
    end

    return data
end

local function activateHud(character)
    char = character
    hudActive = true
    if paydayTimer <= 0 then paydayTimer = 42 * 60 + 18 end
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
    return paydayTimer
end
exports('GetPaydaySeconds', GetPaydaySeconds)

CreateThread(function()
    while true do
        if hudActive and paydayTimer > 0 then
            paydayTimer = paydayTimer - 1
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        if hudActive then
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

AddEventHandler('sunset:nui:hudEditSave', function(data)
    if type(data) ~= 'table' then return end
    SetResourceKvp('sunset_hud_layout', json.encode(data))
    exports.sunset_ui:Notify('Poziție HUD salvată', 'success')
end)

AddEventHandler('sunset:nui:hudEditClose', function()
    exports.sunset_ui:SetFocus(false, false)
end)
