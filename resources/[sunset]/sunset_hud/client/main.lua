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
        wantedDecayAt = exports['sunset_hud']:GetWantedDecayAt(),
        wantedRemainingSec = exports['sunset_hud']:GetWantedRemainingSec(),
        wantedPersistent = exports['sunset_hud']:GetWantedLevel() > 0 and exports['sunset_hud']:GetWantedDecayAt() == nil,
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
        data.showFuel = vehState.showFuel
        data.showOdometer = vehState.showOdometer
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
            SetMpGamerTagsVisibleDistance(0.0)
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        for i = 0, 255 do
            if IsMpGamerTagActive(i) then
                SetMpGamerTagVisibility(i, 0, false)
                RemoveMpGamerTag(i)
            end
        end
        Wait(200)
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

local function localRpName()
    if char and char.firstname then
        local full = (char.firstname or '') .. ((char.lastname and char.lastname ~= '') and (' ' .. char.lastname) or '')
        if full ~= '' then return full end
    end
    local player = exports.sunset_core:GetPlayer()
    if player and player.name and player.name ~= '' then return player.name end
    return GetPlayerName(PlayerId()) or 'Player'
end

local function applyPauseHeader()
    AddTextEntry('FE_THDR_GTAO', ('%s (%s)'):format(localRpName(), GetPlayerServerId(PlayerId())))
end

CreateThread(function()
    while true do
        applyPauseHeader()
        Wait(2000)
    end
end)

local function drawText3d(x, y, z, text, scale, r, g, b)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return sx, sy, false end
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r or 255, g or 255, b or 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
    return sx, sy, true
end

local function drawHpBar3d(x, y, z, pct)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    local w, h = 0.046, 0.008
    DrawRect(sx, sy, w + 0.0022, h + 0.0028, 0, 0, 0, 190)
    DrawRect(sx, sy, w, h, 28, 28, 28, 170)
    local fill = math.max(0.0, math.min(1.0, (tonumber(pct) or 0) / 100.0))
    if fill <= 0.001 then return end
    local fw = w * fill
    local r, g, b = 40, 220, 90
    if pct <= 25 then
        r, g, b = 220, 50, 50
    elseif pct <= 50 then
        r, g, b = 230, 180, 40
    end
    DrawRect(sx - ((w - fw) * 0.5), sy, fw, h, r, g, b, 230)
end

local function isLawEnforcementOnDuty()
    if not LocalPlayer.state.sunsetOnDuty then return false end
    local factionId = LocalPlayer.state.sunsetFaction
    return factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement')
end

local function wantedLevelForPlayer(serverId)
    local bag = Player(serverId) and Player(serverId).state and Player(serverId).state.sunsetWanted
    if type(bag) ~= 'table' then return 0 end
    return math.max(0, math.min(5, tonumber(bag.level) or 0))
end

local function playerNametagLabel(serverId, fallbackName)
    local sid = tonumber(serverId) or 0
    local label = tostring(fallbackName or 'Player')
    local st = sid > 0 and Player(sid) and Player(sid).state
    if st and type(st.sunsetDisplayName) == 'string' and st.sunsetDisplayName ~= '' then
        label = st.sunsetDisplayName
    elseif st and type(st.sunsetName) == 'string' and st.sunsetName ~= '' then
        label = st.sunsetName
    end
    if sid > 0 and not label:match('%(%d+%)%s*$') then
        label = ('%s (%d)'):format(label, sid)
    end
    return label
end

CreateThread(function()
    while true do
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local myId = PlayerId()
        local policeView = isLawEnforcementOnDuty()
        for _, player in ipairs(GetActivePlayers()) do
            if player ~= myId then
                local ped = GetPlayerPed(player)
                if ped ~= 0 and DoesEntityExist(ped) and HasEntityClearLosToEntity(myPed, ped, 17) then
                    local coords = GetEntityCoords(ped)
                    if #(myCoords - coords) < 22.0 then
                        local serverId = GetPlayerServerId(player)
                        local hp = GetEntityHealth(ped)
                        local maxHp = GetEntityMaxHealth(ped)
                        local pct = math.max(0, math.floor((hp / math.max(1, maxHp)) * 100))
                        local label = playerNametagLabel(serverId, GetPlayerName(player))
                        local wantedLevel = wantedLevelForPlayer(serverId)
                        local nameY = coords.z + 1.18
                        if policeView and wantedLevel > 0 then
                            drawText3d(coords.x, coords.y, nameY + 0.14, ('★%d'):format(wantedLevel), 0.30, 255, 80, 80)
                        end
                        drawText3d(coords.x, coords.y, nameY, label, 0.34)
                        drawHpBar3d(coords.x, coords.y, coords.z + 1.02, pct)
                    end
                end
            end
        end
        Wait(0)
    end
end)
