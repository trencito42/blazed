-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Turf Wars Client
--  SAMP-style map zones, war HUD, clan-colored enemy blips
-- ═══════════════════════════════════════════════════════════════

local LocalTurfs = {}
local ActiveWar = nil
local CurrentTurf = nil
local TurfBlips = {}
local WarPlayerBlips = {}
local WarBlipPulse = false

local BLIP_DISPLAY_BOTH = 2
local BLIP_SPRITE_AREA = 9
local BLIP_SPRITE_PLAYER = 1

local function hexToBlipColour(hex)
    if not hex or hex == '' then return 38 end
    hex = tostring(hex):gsub('#', '')
    if #hex ~= 6 then return 38 end
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    if g > r and g > b and g > 150 then return 2 end
    if r > g and r > b and r > 150 then return 1 end
    if b > r and b > g and b > 150 then return 3 end
    if r > 200 and g > 120 and b < 90 then return 46 end
    if r > 200 and g > 200 then return 5 end
    if g > 180 and b > 180 then return 43 end
    return 38
end

local function removeBlipHandle(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function clearTurfBlips()
    for _, row in pairs(TurfBlips) do
        removeBlipHandle(row.area)
    end
    TurfBlips = {}
end

local function clearWarPlayerBlips()
    for sid, blip in pairs(WarPlayerBlips) do
        removeBlipHandle(blip)
        WarPlayerBlips[sid] = nil
    end
end

local function turfAtWar(turfId)
    return ActiveWar and tonumber(ActiveWar.turfId) == tonumber(turfId)
end

local function turfAreaColour(turf, atWar)
    if atWar then
        return WarBlipPulse and 1 or 17
    end
    if turf.ownerClanId then
        return hexToBlipColour(turf.ownerColor)
    end
    return SunsetTurfs.FreeTurfBlipColour or 27
end

local function applyTurfBlipStyle(turf, row, atWar)
    local map = SunsetTurfs.GetMapZone(turf.id, turf)
    local areaAlpha = SunsetTurfs.TurfBlipAlpha or 95
    local areaColour = turfAreaColour(turf, atWar)

    if atWar then
        areaAlpha = SunsetTurfs.TurfBlipAlphaWar or 140
    end

    if row.area and DoesBlipExist(row.area) then
        SetBlipSprite(row.area, BLIP_SPRITE_AREA)
        SetBlipDisplay(row.area, BLIP_DISPLAY_BOTH)
        SetBlipAlpha(row.area, areaAlpha)
        SetBlipColour(row.area, areaColour)
        SetBlipRotation(row.area, map.rotation or 0.0)
        SetBlipAsShortRange(row.area, false)
        SetBlipFlashes(row.area, atWar)
    end

    if row.label and DoesBlipExist(row.label) then
        SetBlipSprite(row.label, 1)
        SetBlipDisplay(row.label, BLIP_DISPLAY_BOTH)
        SetBlipScale(row.label, 0.55)
        SetBlipColour(row.label, areaColour)
        SetBlipAlpha(row.label, atWar and 255 or 190)
        SetBlipAsShortRange(row.label, true)
        SetBlipFlashes(row.label, atWar)
        BeginTextCommandSetBlipName('STRING')
        local suffix = atWar and ' | RAZBOI' or ''
        AddTextComponentSubstringPlayerName(('Turf #%d: %s [%s]%s'):format(
            turf.id, turf.name, turf.ownerTag or 'LIBER', suffix
        ))
        EndTextCommandSetBlipName(row.label)
    end
end

local function refreshBlips()
    clearTurfBlips()
    for id, t in pairs(LocalTurfs) do
        if not t.coords then goto continue end
        local atWar = turfAtWar(id)
        local map = SunsetTurfs.GetMapZone(id, t)
        local areaBlip = AddBlipForArea(t.coords.x, t.coords.y, t.coords.z, map.width, map.height)
        local labelBlip = AddBlipForCoord(t.coords.x, t.coords.y, t.coords.z)

        TurfBlips[id] = { area = areaBlip, label = labelBlip }
        applyTurfBlipStyle(t, TurfBlips[id], atWar)
        ::continue::
    end
end

local function refreshWarTurfBlipPulse()
    if not ActiveWar then return end
    local row = TurfBlips[ActiveWar.turfId]
    local turf = LocalTurfs[ActiveWar.turfId]
    if row and turf then
        applyTurfBlipStyle(turf, row, true)
    end
end

local function myWarClanRole()
    if not ActiveWar then return nil end
    local myClan = LocalPlayer.state.sunsetClanId
    if not myClan then return nil end
    if tonumber(myClan) == tonumber(ActiveWar.attackerClanId) then return 'attacker' end
    if ActiveWar.defenderClanId and tonumber(myClan) == tonumber(ActiveWar.defenderClanId) then return 'defender' end
    return nil
end

local function syncWarPlayerBlips()
    if not ActiveWar then
        clearWarPlayerBlips()
        return
    end

    local role = myWarClanRole()
    if not role then
        clearWarPlayerBlips()
        return
    end

    local turf = LocalTurfs[ActiveWar.turfId]
    if not turf or not turf.coords then
        clearWarPlayerBlips()
        return
    end

    local seen = {}
    local friendlyHex = ActiveWar.attackerColor
    local enemyHex = ActiveWar.defenderColor
    if role == 'defender' then
        friendlyHex = ActiveWar.defenderColor
        enemyHex = ActiveWar.attackerColor
    end
    local friendlyColour = hexToBlipColour(friendlyHex)
    local enemyColour = hexToBlipColour(enemyHex)

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped == 0 or not DoesEntityExist(ped) then goto continue end

        local sid = GetPlayerServerId(playerId)
        if sid <= 0 then goto continue end

        local pos = GetEntityCoords(ped)
        if #(pos - turf.coords) > (turf.radius or 110.0) then goto continue end

        local pClan = Player(sid).state.sunsetClanId
        if not pClan then goto continue end

        local isFriendly = (role == 'attacker' and tonumber(pClan) == tonumber(ActiveWar.attackerClanId))
            or (role == 'defender' and ActiveWar.defenderClanId and tonumber(pClan) == tonumber(ActiveWar.defenderClanId))

        seen[sid] = true
        local blip = WarPlayerBlips[sid]
        if not blip or not DoesBlipExist(blip) then
            blip = AddBlipForEntity(ped)
            WarPlayerBlips[sid] = blip
            SetBlipSprite(blip, BLIP_SPRITE_PLAYER)
            SetBlipDisplay(blip, BLIP_DISPLAY_BOTH)
            SetBlipScale(blip, 0.85)
            SetBlipAsShortRange(blip, false)
        end

        local colour = isFriendly and friendlyColour or enemyColour
        SetBlipColour(blip, colour)
        SetBlipFlashes(blip, not isFriendly)

        BeginTextCommandSetBlipName('STRING')
        if isFriendly then
            AddTextComponentSubstringPlayerName(('[ALIAT] %s'):format(Player(sid).state.clanTag or 'CLAN'))
        else
            AddTextComponentSubstringPlayerName(('[INAMIC] %s'):format(Player(sid).state.clanTag or 'CLAN'))
        end
        EndTextCommandSetBlipName(blip)

        ::continue::
    end

    for sid, blip in pairs(WarPlayerBlips) do
        if not seen[sid] then
            removeBlipHandle(blip)
            WarPlayerBlips[sid] = nil
        end
    end
end

RegisterNetEvent('sunset:turfs:syncAll', function(turfs)
    LocalTurfs = turfs or {}
    refreshBlips()
end)

RegisterNetEvent('sunset:turfs:warStart', function(war)
    ActiveWar = war
    refreshBlips()
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
    if war.isNeutralCapture then
        exports.sunset_ui:Notify(
            ('Capturare %s: sta in zona %d secunde (%d oameni = mai rapid).'):format(
                war.turfName or 'turf',
                war.captureTarget or SunsetTurfs.NeutralCaptureSec or 180,
                1
            ),
            'info',
            9000
        )
    end
end)

RegisterNetEvent('sunset:turfs:warTick', function(war)
    if ActiveWar and ActiveWar.turfId == war.turfId then
        ActiveWar = war
    end
end)

RegisterNetEvent('sunset:turfs:warEnd', function(data)
    if ActiveWar and ActiveWar.turfId == data.turfId then
        ActiveWar = nil
    end
    clearWarPlayerBlips()
    refreshBlips()
    PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('sunset:turfs:requestSync')

    while true do
        Wait(800)
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            local pos = GetEntityCoords(ped)
            local insideAny = nil

            for _, t in pairs(LocalTurfs) do
                if #(pos - t.coords) <= (t.radius or 110.0) then
                    insideAny = t
                    break
                end
            end

            if insideAny and insideAny ~= CurrentTurf then
                CurrentTurf = insideAny
                local ownerStr = insideAny.ownerClanId
                    and ('[%s] %s'):format(insideAny.ownerTag, insideAny.ownerName)
                    or 'Liber'
                exports.sunset_ui:Notify(
                    ('Teritoriu: %s (%s)'):format(insideAny.name, ownerStr),
                    'info',
                    4500
                )
            elseif not insideAny and CurrentTurf then
                CurrentTurf = nil
            end
        end
    end
end)

CreateThread(function()
    while true do
        if ActiveWar then
            WarBlipPulse = not WarBlipPulse
            refreshWarTurfBlipPulse()
            Wait(650)
        else
            Wait(1200)
        end
    end
end)

CreateThread(function()
    while true do
        if ActiveWar and myWarClanRole() then
            syncWarPlayerBlips()
            Wait(450)
        else
            clearWarPlayerBlips()
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if ActiveWar then
            Wait(0)
            local rem = ActiveWar.remainingSec or 0
            local mins = math.floor(rem / 60)
            local secs = rem % 60
            local timeStr = ('%02d:%02d'):format(mins, secs)

            local attTag = ActiveWar.attackerTag or 'ATK'
            local defTag = ActiveWar.defenderTag or 'DEF'
            local attScore = ActiveWar.attackerScore or 0
            local defScore = ActiveWar.defenderScore or 0
            local attCount = ActiveWar.attackerCount or 0
            local defCount = ActiveWar.defenderCount or 0
            local captureTarget = ActiveWar.captureTarget or SunsetTurfs.NeutralCaptureSec or 180

            DrawRect(0.5, 0.045, 0.44, 0.07, 10, 15, 20, 220)
            DrawRect(0.5, 0.015, 0.44, 0.003, 0, 255, 204, 255)

            if ActiveWar.isNeutralCapture then
                SetTextFont(4)
                SetTextScale(0.34, 0.34)
                SetTextColour(0, 255, 204, 255)
                SetTextCentre(false)
                SetTextEntry('STRING')
                AddTextComponentString(('CAPTURARE [%s]: %d / %d'):format(attTag, attScore, captureTarget))
                DrawText(0.28, 0.024)

                SetTextFont(4)
                SetTextScale(0.42, 0.42)
                SetTextColour(255, 255, 255, 255)
                SetTextCentre(true)
                SetTextEntry('STRING')
                AddTextComponentString(timeStr)
                DrawText(0.5, 0.023)

                SetTextFont(4)
                SetTextScale(0.34, 0.34)
                SetTextColour(160, 160, 160, 255)
                SetTextCentre(false)
                SetTextEntry('STRING')
                AddTextComponentString('TURF LIBER')
                DrawText(0.63, 0.024)

                SetTextFont(4)
                SetTextScale(0.26, 0.26)
                SetTextColour(180, 180, 180, 220)
                SetTextCentre(true)
                SetTextEntry('STRING')
                AddTextComponentString(('In zona: %d capturatori | Progres = secunde in raza'):format(attCount))
                DrawText(0.5, 0.054)
            else
                SetTextFont(4)
                SetTextScale(0.36, 0.36)
                SetTextColour(0, 255, 204, 255)
                SetTextCentre(false)
                SetTextEntry('STRING')
                AddTextComponentString(('ATTACK [%s]: %d'):format(attTag, attScore))
                DrawText(0.31, 0.025)

                SetTextFont(4)
                SetTextScale(0.42, 0.42)
                SetTextColour(255, 255, 255, 255)
                SetTextCentre(true)
                SetTextEntry('STRING')
                AddTextComponentString(timeStr)
                DrawText(0.5, 0.023)

                SetTextFont(4)
                SetTextScale(0.36, 0.36)
                SetTextColour(255, 75, 75, 255)
                SetTextCentre(false)
                SetTextEntry('STRING')
                AddTextComponentString(('DEFEND [%s]: %d'):format(defTag, defScore))
                DrawText(0.61, 0.025)

                SetTextFont(4)
                SetTextScale(0.26, 0.26)
                SetTextColour(180, 180, 180, 220)
                SetTextCentre(true)
                SetTextEntry('STRING')
                AddTextComponentString(('In zona: %d atacatori vs %d aparatori'):format(attCount, defCount))
                DrawText(0.5, 0.052)
            end
        else
            Wait(1000)
        end
    end
end)

RegisterNetEvent('sunset:turfs:teleport', function(coords)
    local ped = PlayerPedId()
    if not coords then return end
    SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.5, false, false, false, false)
end)

CreateThread(function()
    Wait(1500)
    TriggerEvent('chat:addSuggestion', '/attackturf', 'Ataca teritoriul in care te afli (rank 5+ in clan)')
    TriggerEvent('chat:addSuggestion', '/atac', 'Alias pentru /attackturf')
    TriggerEvent('chat:addSuggestion', '/turflist', 'Lista teritorii + status razboi (admin)')
    TriggerEvent('chat:addSuggestion', '/gototurf', 'Teleport la un teritoriu (admin)', { { name = 'id', help = '1-16' } })
    TriggerEvent('chat:addSuggestion', '/forceturf', 'Porneste razboi fortat (admin)', {
        { name = 'turfId', help = '1-16' },
        { name = 'clanId', help = 'optional' },
    })
    TriggerEvent('chat:addSuggestion', '/stopwar', 'Opreste razboiul activ (admin)', { { name = 'turfId', help = '1-16' } })
    TriggerEvent('chat:addSuggestion', '/resetturfcd', 'Reset cooldown teritoriu (admin)', { { name = 'id|all' } })
end)
