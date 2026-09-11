-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Turf Wars Client (client/main.lua)
--  Map blips, territory notifications, and live war top HUD
-- ═══════════════════════════════════════════════════════════════

local LocalTurfs = {}
local ActiveWar = nil
local CurrentTurf = nil
local Blips = {}

local function removeAllBlips()
    for _, b in ipairs(Blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    Blips = {}
end

local function refreshBlips()
    removeAllBlips()
    for _, t in pairs(LocalTurfs) do
        -- 1. Radius zone blip
        local radiusBlip = AddBlipForRadius(t.coords.x, t.coords.y, t.coords.z, t.radius)
        SetBlipAlpha(radiusBlip, 85)
        if t.ownerClanId then
            SetBlipColour(radiusBlip, 38) -- Cyan / Blue
        else
            SetBlipColour(radiusBlip, 4) -- Grey / neutral
        end
        table.insert(Blips, radiusBlip)

        -- 2. Center icon blip
        local centerBlip = AddBlipForCoord(t.coords.x, t.coords.y, t.coords.z)
        SetBlipSprite(centerBlip, 437) -- Flag icon
        SetBlipDisplay(centerBlip, 4)
        SetBlipScale(centerBlip, 0.75)
        if t.ownerClanId then
            SetBlipColour(centerBlip, 38)
        else
            SetBlipColour(centerBlip, 4)
        end
        SetBlipAsShortRange(centerBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(('Turf: %s [%s]'):format(t.name, t.ownerTag or '--'))
        EndTextCommandSetBlipName(centerBlip)
        table.insert(Blips, centerBlip)
    end
end

RegisterNetEvent('sunset:turfs:syncAll', function(turfs)
    LocalTurfs = turfs or {}
    refreshBlips()
end)

RegisterNetEvent('sunset:turfs:warStart', function(war)
    ActiveWar = war
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
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
    PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
end)

-- Territory proximity check
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
                if #(pos - t.coords) <= t.radius then
                    insideAny = t
                    break
                end
            end

            if insideAny and insideAny ~= CurrentTurf then
                CurrentTurf = insideAny
                local ownerStr = insideAny.ownerClanId and ('[%s] %s'):format(insideAny.ownerTag, insideAny.ownerName) or 'Liber'
                exports.sunset_ui:Notify(('Teritoriu: %s (%s)'):format(insideAny.name, ownerStr), 'info', 4000)
            elseif not insideAny and CurrentTurf then
                CurrentTurf = nil
            end
        end
    end
end)

-- Live War HUD Drawing
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

            -- Draw Top Cyber Banner
            DrawRect(0.5, 0.045, 0.42, 0.065, 10, 15, 20, 220)
            DrawRect(0.5, 0.015, 0.42, 0.003, 0, 255, 204, 255)

            -- Text labels
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

            -- Subtitle zone count
            SetTextFont(4)
            SetTextScale(0.26, 0.26)
            SetTextColour(180, 180, 180, 220)
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString(('In zona: %d atacatori vs %d aparatori'):format(attCount, defCount))
            DrawText(0.5, 0.052)
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

