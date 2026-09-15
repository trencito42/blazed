-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (server/main.lua)
--  Server-authoritative racing: solo time trial + multiplayer lobbies,
--  checkpoint validation, vehicle/driver checks, idempotent cleanup.
--
--  OWNERSHIP: sunset_racing owns the world interaction (marker + E) at the
--  race hub. sunset_events integrates through exports — no competing marker.
--
--  DIAGNOSTICS: gated behind convar sv_sunset_racing_debug (default off).
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetRacing.Config

local function debugEnabled()
    return GetConvar('sv_sunset_racing_debug', '0') == '1'
end

local function dlog(msg)
    if debugEnabled() then
        print(('[RACING] ' .. msg))
    end
end

-- ═══ STATE ═══
local Lobbies = {}          -- [routeId] = { players = {src=true}, startedAt, autoStartAt }
local PlayerLobby = {}      -- [src] = routeId

local ActiveRace = nil      -- { raceId, routeId, route, players, phase, ... }
local PlayerProgress = {}   -- [src] = { nextCheckpoint, lastCheckpointAt, startTimeMs, finishedAtMs, vehicle, dnf }

local RaceNightPoints = {}  -- [charId] = points
local RaceNightActive = false

-- Solo cooldown keyed by CHARACTER ID (persists across reconnect within runtime)
local SoloCooldowns = {}    -- [charId] = GetGameTimer() of last solo finish

local raceIdCounter = 0

-- ═══ HELPERS ═══

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function broadcast(msg, kind)
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('sunset:client:notify', tonumber(id), msg, kind or 'info', 8000)
    end
end

local function getCharId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id) or nil
end

local function nowMs()
    return GetGameTimer()
end

local function formatTime(ms)
    if not ms or ms < 0 then return '--:--.---' end
    local totalSec = math.floor(ms / 1000)
    local min = math.floor(totalSec / 60)
    local sec = totalSec % 60
    local millis = ms % 1000
    return ('%02d:%02d.%03d'):format(min, sec, millis)
end

local function countLobby(routeId)
    local lobby = Lobbies[routeId]
    if not lobby then return 0 end
    local n = 0
    for _ in pairs(lobby.players) do n = n + 1 end
    return n
end

local function getRoute(routeId)
    for _, r in ipairs(Cfg.routes or {}) do
        if r.id == routeId then return r end
    end
    return nil
end

-- ═══ SOLO TIME TRIAL ═══

exports.sunset_core:RegisterCallback('sunset:racing:startSolo', function(source, routeId)
    routeId = tostring(routeId or '')
    local route = getRoute(routeId)
    if not route then
        dlog(('solo rejected src=%d reason=unknown_route'):format(source))
        return nil, 'Unknown race route.'
    end
    if ActiveRace then
        dlog(('solo rejected src=%d reason=active_race'):format(source))
        return nil, 'A race is already in progress. Wait for it to finish.'
    end
    if PlayerLobby[source] then
        return nil, 'You are already in a lobby. Leave first.'
    end

    -- Solo cooldown (per character)
    local charId = getCharId(source)
    if charId and SoloCooldowns[charId] then
        local elapsed = nowMs() - SoloCooldowns[charId]
        if elapsed < (Cfg.soloCooldownMs or 300000) then
            local remaining = math.ceil(((Cfg.soloCooldownMs or 300000) - elapsed) / 1000)
            return nil, ('Solo time trial on cooldown. Try again in %ds.'):format(remaining)
        end
    end

    -- Driver validation
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'No ped found.' end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil, 'You must be in a vehicle to start a race.' end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil, 'You must be the DRIVER to start a race.' end

    -- Solo entry fee (default 0 = free)
    local soloFee = Cfg.soloEntryFee or 0
    if soloFee > 0 then
        if not exports.sunset_core:RemoveMoney(source, 'cash', soloFee, 'race_solo_entry') then
            return nil, ('Not enough cash. Solo entry fee: $%s.'):format(soloFee)
        end
    end

    dlog(('solo starting src=%d route=%s'):format(source, routeId))
    startRace(routeId, { source }, true)
    return { routeId = routeId, isSolo = true }
end)

-- ═══ MULTIPLAYER LOBBY ═══

exports.sunset_core:RegisterCallback('sunset:racing:join', function(source, routeId)
    routeId = tostring(routeId or '')
    local route = getRoute(routeId)
    if not route then
        dlog(('join rejected src=%d reason=unknown_route'):format(source))
        return nil, 'Unknown race route.'
    end
    if ActiveRace then
        dlog(('join rejected src=%d reason=active_race'):format(source))
        return nil, 'A race is already in progress. Wait for it to finish.'
    end
    if PlayerLobby[source] then
        return nil, 'You are already in a lobby. Leave first.'
    end

    -- Driver validation
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'No ped found.' end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil, 'You must be in a vehicle to join a race.' end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil, 'You must be the DRIVER to join a race.' end

    -- Charge entry fee (once — guarded by PlayerLobby check)
    if not exports.sunset_core:RemoveMoney(source, 'cash', Cfg.entryFee or 1000, 'race_entry') then
        return nil, ('Not enough cash. Entry fee: $%s.'):format(Cfg.entryFee or 1000)
    end

    -- Add to route-specific lobby
    if not Lobbies[routeId] then
        Lobbies[routeId] = { players = {}, startedAt = nowMs(), autoStartAt = nil }
    end
    Lobbies[routeId].players[source] = true
    PlayerLobby[source] = routeId

    local count = countLobby(routeId)
    dlog(('join ok src=%d route=%s count=%d'):format(source, routeId, count))

    -- Notify lobby
    for src in pairs(Lobbies[routeId].players) do
        notify(src, ('%s joined %s lobby (%d/%d).'):format(
            exports.sunset_core:GetPlayerDisplayName(src) or 'Someone',
            route.label, count, Cfg.minMultiPlayers or 2), 'info')
    end

    -- Auto-start countdown when minimum reached
    if count >= (Cfg.minMultiPlayers or 2) and not Lobbies[routeId].autoStartAt then
        Lobbies[routeId].autoStartAt = nowMs() + (Cfg.lobbyAutoStartDelay or 5000)
    end

    return {
        routeId = routeId,
        players = count,
        minPlayers = Cfg.minMultiPlayers or 2,
    }
end)

exports.sunset_core:RegisterCallback('sunset:racing:leave', function(source)
    local routeId = PlayerLobby[source]
    if not routeId then return nil, 'You are not in a lobby.' end

    local lobby = Lobbies[routeId]
    if lobby then
        lobby.players[source] = nil
        if countLobby(routeId) == 0 then
            Lobbies[routeId] = nil
        end
    end
    PlayerLobby[source] = nil

    -- Refund entry fee (once)
    exports.sunset_core:AddMoney(source, 'cash', Cfg.entryFee or 1000, 'race_refund')
    notify(source, 'Left the race lobby. Entry fee refunded.', 'info')
    dlog(('leave src=%d route=%s refunded'):format(source, routeId))
    return true
end)

-- Explicit multiplayer start (host or auto)
exports.sunset_core:RegisterCallback('sunset:racing:startMulti', function(source, routeId)
    routeId = tostring(routeId or '')
    local lobby = Lobbies[routeId]
    if not lobby then return nil, 'No lobby for that route.' end
    if not lobby.players[source] then return nil, 'You are not in that lobby.' end
    if countLobby(routeId) < (Cfg.minMultiPlayers or 2) then
        return nil, ('Need at least %d players to start.'):format(Cfg.minMultiPlayers or 2)
    end
    if ActiveRace then return nil, 'A race is already in progress.' end

    local players = {}
    for src in pairs(lobby.players) do players[#players + 1] = src end
    dlog(('multi starting route=%s players=%d'):format(routeId, #players))
    startRace(routeId, players, false)
    return true
end)

-- Lobby auto-start checker
CreateThread(function()
    while true do
        Wait(1000)
        for routeId, lobby in pairs(Lobbies) do
            if lobby.autoStartAt and nowMs() >= lobby.autoStartAt and not ActiveRace then
                if countLobby(routeId) >= (Cfg.minMultiPlayers or 2) then
                    local players = {}
                    for src in pairs(lobby.players) do players[#players + 1] = src end
                    dlog(('auto-start route=%s players=%d'):format(routeId, #players))
                    startRace(routeId, players, false)
                else
                    lobby.autoStartAt = nil
                end
            end
        end
    end
end)

-- ═══ STATUS ═══

exports.sunset_core:RegisterCallback('sunset:racing:status', function(source)
    local routeId = PlayerLobby[source]
    local lobbyInfo = nil
    if routeId and Lobbies[routeId] then
        local players = {}
        for src in pairs(Lobbies[routeId].players) do
            players[#players + 1] = {
                name = exports.sunset_core:GetPlayerDisplayName(src) or 'Unknown',
                isSelf = src == source,
            }
        end
        lobbyInfo = { routeId = routeId, players = players, count = #players }
    end

    local charId = getCharId(source)
    local soloOnCooldown = false
    if charId and SoloCooldowns[charId] then
        soloOnCooldown = (nowMs() - SoloCooldowns[charId]) < (Cfg.soloCooldownMs or 300000)
    end

    return {
        inLobby = routeId ~= nil,
        lobbyInfo = lobbyInfo,
        inRace = PlayerProgress[source] ~= nil and PlayerProgress[source].dnf ~= true,
        entryFee = Cfg.entryFee or 1000,
        soloReward = Cfg.soloReward or 500,
        soloOnCooldown = soloOnCooldown,
        minMultiPlayers = Cfg.minMultiPlayers or 2,
        routes = Cfg.routes or {},
        activeRace = ActiveRace and {
            raceId = ActiveRace.raceId,
            routeId = ActiveRace.routeId,
            phase = ActiveRace.phase,
            players = #ActiveRace.players,
        } or nil,
        raceNightActive = RaceNightActive,
        raceNightPoints = charId and RaceNightPoints[charId] or 0,
    }
end)

-- ═══ RACE LIFECYCLE ═══

function startRace(routeId, players, isSolo)
    local route = getRoute(routeId)
    if not route or #players == 0 then return end

    raceIdCounter = raceIdCounter + 1
    local raceId = raceIdCounter

    for _, src in ipairs(players) do
        local ped = GetPlayerPed(src)
        local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        PlayerProgress[src] = {
            nextCheckpoint = 1,
            lastCheckpointAt = 0,
            startTimeMs = nil,
            finishedAtMs = nil,
            vehicle = veh,
            dnf = false,
        }
    end

    ActiveRace = {
        raceId = raceId,
        routeId = routeId,
        route = route,
        players = players,
        phase = 'countdown',
        startTimeMs = nil,
        countdown = Cfg.countdownSeconds or 5,
        finished = {},
        isSolo = isSolo,
        settled = false,
    }

    -- Clear lobbies
    Lobbies[routeId] = nil
    for _, src in ipairs(players) do
        PlayerLobby[src] = nil
    end

    -- Freeze vehicles
    for _, src in ipairs(players) do
        TriggerClientEvent('sunset:racing:freeze', src, true)
    end

    -- Send start + checkpoints
    for _, src in ipairs(players) do
        TriggerClientEvent('sunset:racing:start', src, {
            raceId = raceId,
            routeId = routeId,
            label = route.label,
            checkpoints = route.checkpoints,
            countdown = Cfg.countdownSeconds or 5,
            isSolo = isSolo,
        })
    end

    dlog(('race started id=%d route=%s players=%d solo=%s'):format(raceId, routeId, #players, tostring(isSolo)))

    -- Countdown thread
    CreateThread(function()
        for i = (Cfg.countdownSeconds or 5), 1, -1 do
            if not ActiveRace or ActiveRace.raceId ~= raceId then return end
            for _, src in ipairs(ActiveRace.players) do
                TriggerClientEvent('sunset:racing:countdown', src, i)
            end
            Wait(1000)
        end
        if not ActiveRace or ActiveRace.raceId ~= raceId then return end

        ActiveRace.phase = 'running'
        ActiveRace.startTimeMs = nowMs()
        for _, src in ipairs(ActiveRace.players) do
            if PlayerProgress[src] then
                PlayerProgress[src].startTimeMs = nowMs()
            end
            TriggerClientEvent('sunset:racing:go', src)
            TriggerClientEvent('sunset:racing:freeze', src, false)
        end
        dlog(('race GO id=%d'):format(raceId))
    end)

    -- Timeout thread
    CreateThread(function()
        Wait((Cfg.raceTimeout or 600) * 1000)
        if ActiveRace and ActiveRace.raceId == raceId and ActiveRace.phase == 'running' then
            dlog(('race timeout id=%d'):format(raceId))
            endRace('timeout')
        end
    end)
end

-- ═══ CHECKPOINT VALIDATION (server-authoritative) ═══

RegisterNetEvent('sunset:racing:checkpoint', function(checkpointIndex, raceId)
    local src = source
    if not ActiveRace or ActiveRace.raceId ~= raceId then return end
    if ActiveRace.phase ~= 'running' then return end

    local progress = PlayerProgress[src]
    if not progress or progress.dnf then return end
    if progress.finishedAtMs then return end

    checkpointIndex = tonumber(checkpointIndex)
    if not checkpointIndex then return end
    if checkpointIndex ~= progress.nextCheckpoint then
        dlog(('checkpoint rejected src=%d expected=%d got=%d reason=wrong_index'):format(
            src, progress.nextCheckpoint, checkpointIndex))
        return
    end

    -- Anti-speedhack
    local now = nowMs()
    if progress.lastCheckpointAt > 0 and (now - progress.lastCheckpointAt) < (Cfg.minCheckpointIntervalMs or 1500) then
        return
    end

    -- Position validation
    local cp = ActiveRace.route.checkpoints[checkpointIndex]
    if not cp then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)

    -- Vehicle/driver validation
    if veh == 0 then
        progress.dnf = true
        TriggerClientEvent('sunset:racing:dnf', src, { reason = 'You left your vehicle.' })
        dlog(('dnf src=%d reason=left_vehicle'):format(src))
        checkRaceEnd()
        return
    end
    if progress.vehicle ~= 0 and veh ~= progress.vehicle then
        progress.dnf = true
        TriggerClientEvent('sunset:racing:dnf', src, { reason = 'You switched vehicles.' })
        dlog(('dnf src=%d reason=switched_vehicle'):format(src))
        checkRaceEnd()
        return
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        progress.dnf = true
        TriggerClientEvent('sunset:racing:dnf', src, { reason = 'You are not the driver.' })
        dlog(('dnf src=%d reason=not_driver'):format(src))
        checkRaceEnd()
        return
    end

    local target = veh
    local coords = GetEntityCoords(target)
    local dist = #(coords - cp)
    if dist > (Cfg.checkpointRadius or 25.0) then
        dlog(('checkpoint rejected src=%d cp=%d dist=%.1f reason=too_far'):format(src, checkpointIndex, dist))
        return
    end

    -- ACCEPTED
    progress.lastCheckpointAt = now
    progress.nextCheckpoint = checkpointIndex + 1
    local totalCheckpoints = #ActiveRace.route.checkpoints
    dlog(('checkpoint accepted src=%d cp=%d/%d'):format(src, checkpointIndex, totalCheckpoints))

    if progress.nextCheckpoint > totalCheckpoints then
        progress.finishedAtMs = now
        ActiveRace.finished[#ActiveRace.finished + 1] = src
        local elapsed = progress.finishedAtMs - (progress.startTimeMs or progress.finishedAtMs)
        TriggerClientEvent('sunset:racing:finished', src, {
            raceId = raceId,
            position = #ActiveRace.finished,
            timeMs = elapsed,
            timeFormatted = formatTime(elapsed),
        })
        dlog(('finish src=%d pos=%d time=%s'):format(src, #ActiveRace.finished, formatTime(elapsed)))
        checkRaceEnd()
    else
        TriggerClientEvent('sunset:racing:checkpointReached', src, {
            raceId = raceId,
            current = checkpointIndex,
            total = totalCheckpoints,
        })
    end
end)

function checkRaceEnd()
    if not ActiveRace then return end
    local activeRacers = 0
    for _, src in ipairs(ActiveRace.players) do
        local p = PlayerProgress[src]
        if p and not p.dnf and not p.finishedAtMs then
            activeRacers = activeRacers + 1
        end
    end
    if activeRacers == 0 then
        endRace('complete')
    end
end

function endRace(reason)
    if not ActiveRace then return end
    if ActiveRace.settled then return end
    ActiveRace.settled = true

    local raceId = ActiveRace.raceId
    local isSolo = ActiveRace.isSolo

    -- Payout (once only)
    if #ActiveRace.finished > 0 then
        if isSolo then
            local winner = ActiveRace.finished[1]
            local charId = getCharId(winner)
            local now = nowMs()
            if charId and (not SoloCooldowns[charId] or (now - SoloCooldowns[charId]) > (Cfg.soloCooldownMs or 300000)) then
                exports.sunset_core:AddMoney(winner, 'cash', Cfg.soloReward or 500, 'race_solo_reward')
                notify(winner, ('⏱ Time trial complete! Reward: $%s.'):format(Cfg.soloReward or 500), 'success', 10000)
            else
                notify(winner, '⏱ Time trial complete! (Reward on cooldown)', 'info', 8000)
            end
            if charId then SoloCooldowns[charId] = now end
        else
            local totalPot = #ActiveRace.players * (Cfg.entryFee or 1000)
            local prize = math.floor(totalPot * (Cfg.prizeMultiplier or 0.8))
            local winner = ActiveRace.finished[1]
            exports.sunset_core:AddMoney(winner, 'cash', prize, 'race_prize')
            notify(winner, ('🏆 You won the race! Prize: $%s.'):format(prize), 'success', 10000)
            for i = 2, #ActiveRace.finished do
                notify(ActiveRace.finished[i], ('Race finished — position #%d.'):format(i), 'info', 8000)
            end
        end

        -- Race Night points
        if RaceNightActive then
            for i, src in ipairs(ActiveRace.finished) do
                local charId = getCharId(src)
                if charId then
                    local pts = Cfg.pointsFinish or 10
                    local bonus = (Cfg.pointsPlacement or {})[i] or 0
                    if isSolo then pts = Cfg.pointsSoloFinish or 5; bonus = 0 end
                    RaceNightPoints[charId] = (RaceNightPoints[charId] or 0) + pts + bonus
                end
            end
        end
    else
        -- No one finished — refund. SOLO IS FREE (soloEntryFee=0), so no
        -- refund there; refunding entryFee on a free solo race would be a
        -- money faucet (start free, DNF on purpose, collect $1000).
        if not isSolo then
            for _, src in ipairs(ActiveRace.players) do
                local p = PlayerProgress[src]
                if p and not p.finishedAtMs then
                    exports.sunset_core:AddMoney(src, 'cash', Cfg.entryFee or 1000, 'race_refund_dnf')
                end
            end
        end
    end

    -- Cleanup (idempotent). Always unfreeze vehicles — covers cancellation
    -- during countdown (e.g. all racers disconnected mid-countdown).
    for _, src in ipairs(ActiveRace.players) do
        TriggerClientEvent('sunset:racing:freeze', src, false)
        TriggerClientEvent('sunset:racing:end', src, { raceId = raceId, reason = reason })
        PlayerProgress[src] = nil
    end
    ActiveRace = nil
    dlog(('race ended id=%d reason=%s'):format(raceId, reason))
end

-- ═══ DISCONNECT ═══

AddEventHandler('playerDropped', function()
    local src = source

    -- Remove from lobby (refund)
    local routeId = PlayerLobby[src]
    if routeId and Lobbies[routeId] then
        Lobbies[routeId].players[src] = nil
        exports.sunset_core:AddMoney(src, 'cash', Cfg.entryFee or 1000, 'race_refund_disconnect')
        if countLobby(routeId) == 0 then
            Lobbies[routeId] = nil
        end
    end
    PlayerLobby[src] = nil

    -- Remove from race (DNF)
    if PlayerProgress[src] then
        PlayerProgress[src] = nil
        if ActiveRace then
            for i, s in ipairs(ActiveRace.players) do
                if s == src then
                    table.remove(ActiveRace.players, i)
                    break
                end
            end
            checkRaceEnd()
        end
    end
end)

-- ═══ RESOURCE STOP ═══

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Cleanup any active race
    if ActiveRace and not ActiveRace.settled then
        for _, src in ipairs(ActiveRace.players) do
            TriggerClientEvent('sunset:racing:end', src, { raceId = ActiveRace.raceId, reason = 'resource_stop' })
            TriggerClientEvent('sunset:racing:freeze', src, false)
            PlayerProgress[src] = nil
        end
    end
    ActiveRace = nil
    Lobbies = {}
    PlayerLobby = {}
end)

-- ═══ RACE NIGHT ═══

exports('StartRaceNight', function()
    RaceNightActive = true
    RaceNightPoints = {}
    broadcast('🏁 Race Night is LIVE! Head to the race hub and press E to race.', 'success')
end)

exports('EndRaceNight', function()
    if not RaceNightActive then return end
    RaceNightActive = false

    local rewarded = 0
    for charId, points in pairs(RaceNightPoints) do
        local reward = nil
        for _, r in ipairs(Cfg.raceNightRewards or {}) do
            if points >= r.minPoints then reward = r break end
        end
        if reward then
            for _, id in ipairs(GetPlayers()) do
                local src = tonumber(id)
                if getCharId(src) == charId then
                    exports.sunset_core:AddMoney(src, 'cash', reward.cash, 'race_night_reward')
                    pcall(function() exports.sunset_core:AddXP(src, reward.xp) end)
                    notify(src, ('🏆 Race Night complete! %s: $%s + %d XP (%d pts).'):format(
                        reward.label, reward.cash, reward.xp, points), 'success', 12000)
                    rewarded = rewarded + 1
                    break
                end
            end
        end
    end

    broadcast(('🏁 Race Night ended. %d racers rewarded.'):format(rewarded), 'info')
    RaceNightPoints = {}
end)

exports('IsRaceNightActive', function() return RaceNightActive end)
exports('GetRaceNightPoints', function(charId) return RaceNightPoints[charId] or 0 end)

-- [TEST AGENT] Read-only racing snapshot for dev/test tooling.
exports('GetTestSnapshot', function(source)
    local src = tonumber(source or -1)
    local out = { inLobby = PlayerLobby[src] ~= nil, lobbyRoute = PlayerLobby[src] }
    local progress = PlayerProgress[src]
    if progress then
        out.inRace = ActiveRace ~= nil
        out.raceId = ActiveRace and ActiveRace.raceId or nil
        out.phase = ActiveRace and ActiveRace.phase or nil
        out.nextCheckpoint = progress.nextCheckpoint
        out.dnf = progress.dnf == true
        out.finished = progress.finishedAtMs ~= nil
    end
    if ActiveRace then
        out.activeRace = {
            raceId = ActiveRace.raceId,
            routeId = ActiveRace.routeId,
            phase = ActiveRace.phase,
            players = #ActiveRace.players,
            finished = #ActiveRace.finished,
            isSolo = ActiveRace.isSolo == true,
        }
    end
    return out
end)

print(('^2[sunset_racing]^7 Street racing online (%d routes, hub at %.0f,%.0f,%.0f)'):format(
    #(Cfg.routes or {}), Cfg.raceHub.x, Cfg.raceHub.y, Cfg.raceHub.z))
