-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (server/main.lua)
--  Server-authoritative racing: route-specific lobbies, state machine,
--  checkpoint validation, millisecond timing, DNF lifecycle, money safety.
--
--  OWNERSHIP: sunset_racing owns the world interaction (marker + E) at the
--  race hub. sunset_events integrates through exports/events — it does NOT
--  create its own marker at the same location.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetRacing.Config

-- ═══ STATE ═══
-- Lobbies: per-route, so players on different routes never mix.
local Lobbies = {}          -- [routeId] = { players = {src=true}, startedAt }
local PlayerLobby = {}      -- [src] = routeId (prevents multi-lobby)

-- Races: one active race at a time (explicit limitation, safe).
local ActiveRace = nil      -- see startRace() for shape
local PlayerProgress = {}   -- [src] = { nextCheckpoint, lastCheckpointAt, startTimeMs, finishedAtMs, vehicle, dnf }

-- Race Night points (per character, reset each event)
local RaceNightPoints = {}  -- [charId] = points
local RaceNightActive = false

-- Solo cooldown
local SoloCooldowns = {}    -- [src] = GetGameTimer() of last solo finish

-- Race ID nonce — old client events cannot mutate a newer race.
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

local function totalLobbyPlayers()
    local n = 0
    for _, lobby in pairs(Lobbies) do
        for _ in pairs(lobby.players) do n = n + 1 end
    end
    return n
end

local function getRoute(routeId)
    for _, r in ipairs(Cfg.routes or {}) do
        if r.id == routeId then return r end
    end
    return nil
end

-- ═══ LOBBY ═══

exports.sunset_core:RegisterCallback('sunset:racing:join', function(source, routeId)
    if ActiveRace then
        return nil, 'A race is already in progress. Wait for it to finish.'
    end
    if PlayerLobby[source] then
        return nil, 'You are already in a lobby. Leave first.'
    end

    routeId = tostring(routeId or '')
    local route = getRoute(routeId)
    if not route then return nil, 'Unknown race route.' end

    -- Driver validation: must be in a vehicle AND be the driver
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'No ped found.' end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        return nil, 'You must be in a vehicle to join a race.'
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return nil, 'You must be the DRIVER to join a race.'
    end

    -- Charge entry fee (once — guarded by PlayerLobby check above)
    if not exports.sunset_core:RemoveMoney(source, 'cash', Cfg.entryFee or 1000, 'race_entry') then
        return nil, ('Not enough cash. Entry fee: $%s.'):format(Cfg.entryFee or 1000)
    end

    -- Add to route-specific lobby
    if not Lobbies[routeId] then
        Lobbies[routeId] = { players = {}, startedAt = nowMs() }
    end
    Lobbies[routeId].players[source] = true
    PlayerLobby[source] = routeId

    -- Notify all players in this route's lobby
    for src in pairs(Lobbies[routeId].players) do
        notify(src, ('%s joined %s lobby (%d/%d).'):format(
            exports.sunset_core:GetPlayerDisplayName(src) or 'Someone',
            route.label, countLobby(routeId), Cfg.minPlayers or 1), 'info')
    end

    -- Auto-start if enough players
    if countLobby(routeId) >= (Cfg.minPlayers or 1) then
        startRace(routeId)
    end

    return {
        routeId = routeId,
        players = countLobby(routeId),
        minPlayers = Cfg.minPlayers or 1,
        soloAvailable = Cfg.minPlayers <= 1,
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

    -- Refund entry fee (once — guarded by PlayerLobby check above)
    exports.sunset_core:AddMoney(source, 'cash', Cfg.entryFee or 1000, 'race_refund')
    notify(source, 'Left the race lobby. Entry fee refunded.', 'info')
    return true
end)

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

    return {
        inLobby = routeId ~= nil,
        lobbyInfo = lobbyInfo,
        inRace = PlayerProgress[source] ~= nil and PlayerProgress[source].dnf ~= true,
        minPlayers = Cfg.minPlayers or 1,
        entryFee = Cfg.entryFee or 1000,
        soloAvailable = Cfg.minPlayers <= 1,
        soloReward = Cfg.soloReward or 500,
        routes = Cfg.routes or {},
        activeRace = ActiveRace and {
            raceId = ActiveRace.raceId,
            routeId = ActiveRace.routeId,
            phase = ActiveRace.phase,
            players = #ActiveRace.players,
        } or nil,
        raceNightActive = RaceNightActive,
        raceNightPoints = getCharId(source) and RaceNightPoints[getCharId(source)] or 0,
    }
end)

-- ═══ RACE LIFECYCLE ═══

function startRace(routeId)
    local route = getRoute(routeId)
    local lobby = Lobbies[routeId]
    if not route or not lobby then return end

    local playerCount = countLobby(routeId)
    if playerCount < (Cfg.minPlayers or 1) then return end

    local isSolo = playerCount == 1
    raceIdCounter = raceIdCounter + 1
    local raceId = raceIdCounter

    local players = {}
    for src in pairs(lobby.players) do
        players[#players + 1] = src
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
        phase = 'countdown',  -- lobby → countdown → running → finished → cancelled
        startTimeMs = nil,
        countdown = Cfg.countdownSeconds or 5,
        finished = {},
        isSolo = isSolo,
        settled = false,
    }

    -- Clear lobbies (players are now in the race)
    Lobbies[routeId] = nil
    for _, src in ipairs(players) do
        PlayerLobby[src] = nil
    end

    -- Freeze vehicles during countdown
    for _, src in ipairs(players) do
        TriggerClientEvent('sunset:racing:freeze', src, true)
    end

    -- Send race start + checkpoints to all racers
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

        -- GO!
        ActiveRace.phase = 'running'
        ActiveRace.startTimeMs = nowMs()
        for _, src in ipairs(ActiveRace.players) do
            if PlayerProgress[src] then
                PlayerProgress[src].startTimeMs = nowMs()
            end
            TriggerClientEvent('sunset:racing:go', src)
            TriggerClientEvent('sunset:racing:freeze', src, false)
        end
    end)

    -- Timeout thread
    CreateThread(function()
        Wait((Cfg.raceTimeout or 600) * 1000)
        if ActiveRace and ActiveRace.raceId == raceId and ActiveRace.phase == 'running' then
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
    if progress.finishedAtMs then return end -- already finished

    checkpointIndex = tonumber(checkpointIndex)
    if not checkpointIndex then return end
    if checkpointIndex ~= progress.nextCheckpoint then return end

    -- Anti-speedhack: minimum interval between checkpoints
    local now = nowMs()
    if progress.lastCheckpointAt > 0 and (now - progress.lastCheckpointAt) < (Cfg.minCheckpointIntervalMs or 1500) then
        return
    end

    -- Position validation: player must be near the expected checkpoint
    local cp = ActiveRace.route.checkpoints[checkpointIndex]
    if not cp then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)
    local target = veh ~= 0 and veh or ped
    local coords = GetEntityCoords(target)
    local dist = #(coords - cp)
    if dist > (Cfg.checkpointRadius or 25.0) then
        return
    end

    -- Vehicle validation: must still be in the race vehicle (or any vehicle)
    if veh == 0 then
        -- On foot — DNF
        progress.dnf = true
        TriggerClientEvent('sunset:racing:dnf', src, { reason = 'You left your vehicle.' })
        checkRaceEnd()
        return
    end

    progress.lastCheckpointAt = now
    progress.nextCheckpoint = checkpointIndex + 1
    local totalCheckpoints = #ActiveRace.route.checkpoints

    if progress.nextCheckpoint > totalCheckpoints then
        -- Finished!
        progress.finishedAtMs = now
        ActiveRace.finished[#ActiveRace.finished + 1] = src
        local elapsed = progress.finishedAtMs - (progress.startTimeMs or progress.finishedAtMs)
        TriggerClientEvent('sunset:racing:finished', src, {
            raceId = raceId,
            position = #ActiveRace.finished,
            timeMs = elapsed,
            timeFormatted = formatTime(elapsed),
        })
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
    local totalPot = #ActiveRace.players * (Cfg.entryFee or 1000)

    -- Payout (once only — guarded by settled flag)
    if #ActiveRace.finished > 0 then
        if isSolo then
            -- Solo time trial: fixed reward, not player-funded
            local winner = ActiveRace.finished[1]
            local now = nowMs()
            if not SoloCooldowns[winner] or (now - SoloCooldowns[winner]) > (Cfg.soloCooldownMs or 300000) then
                exports.sunset_core:AddMoney(winner, 'cash', Cfg.soloReward or 500, 'race_solo_reward')
                notify(winner, ('⏱ Time trial complete! Reward: $%s.'):format(Cfg.soloReward or 500), 'success', 10000)
            else
                notify(winner, '⏱ Time trial complete! (Solo reward on cooldown)', 'info', 8000)
            end
            SoloCooldowns[winner] = now
        else
            -- Multiplayer: winner takes the pot
            local prize = math.floor(totalPot * (Cfg.prizeMultiplier or 0.8))
            local winner = ActiveRace.finished[1]
            exports.sunset_core:AddMoney(winner, 'cash', prize, 'race_prize')
            notify(winner, ('🏆 You won the race! Prize: $%s.'):format(prize), 'success', 10000)

            for i = 2, #ActiveRace.finished do
                local src = ActiveRace.finished[i]
                notify(src, ('Race finished — position #%d.'):format(i), 'info', 8000)
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
        -- No one finished — refund entry fees
        for _, src in ipairs(ActiveRace.players) do
            local p = PlayerProgress[src]
            if p and not p.finishedAtMs then
                exports.sunset_core:AddMoney(src, 'cash', Cfg.entryFee or 1000, 'race_refund_dnf')
            end
        end
    end

    -- Clean up
    for _, src in ipairs(ActiveRace.players) do
        TriggerClientEvent('sunset:racing:end', src, { raceId = raceId, reason = reason })
        PlayerProgress[src] = nil
    end
    ActiveRace = nil
end

-- ═══ DISCONNECT / DNF ═══

AddEventHandler('playerDropped', function()
    local src = source

    -- Remove from lobby
    local routeId = PlayerLobby[src]
    if routeId and Lobbies[routeId] then
        Lobbies[routeId].players[src] = nil
        if countLobby(routeId) == 0 then
            Lobbies[routeId] = nil
        end
    end
    PlayerLobby[src] = nil

    -- Remove from race (DNF)
    if PlayerProgress[src] then
        PlayerProgress[src] = nil
        if ActiveRace then
            -- Remove from players list
            for i, s in ipairs(ActiveRace.players) do
                if s == src then
                    table.remove(ActiveRace.players, i)
                    break
                end
            end
            checkRaceEnd()
        end
    end

    SoloCooldowns[src] = nil
end)

-- ═══ RACE NIGHT INTEGRATION ═══

-- sunset_events calls these exports to start/end Race Night
exports('StartRaceNight', function()
    RaceNightActive = true
    RaceNightPoints = {}
    broadcast('🏁 Race Night is LIVE! Head to the race hub (LS Customs) and press E to join a race.', 'success')
end)

exports('EndRaceNight', function()
    if not RaceNightActive then return end
    RaceNightActive = false

    -- Award final rewards based on points
    local rewarded = 0
    for charId, points in pairs(RaceNightPoints) do
        local reward = nil
        for _, r in ipairs(Cfg.raceNightRewards or {}) do
            if points >= r.minPoints then
                reward = r
                break
            end
        end
        if reward then
            -- Find online source for this character
            for _, id in ipairs(GetPlayers()) do
                local src = tonumber(id)
                if getCharId(src) == charId then
                    exports.sunset_core:AddMoney(src, 'cash', reward.cash, 'race_night_reward')
                    pcall(function() exports.sunset_core:AddXP(src, reward.xp) end)
                    notify(src, ('🏆 Race Night complete! %s reward: $%s + %d XP (%d points).'):format(
                        reward.label, reward.cash, reward.xp, points), 'success', 12000)
                    rewarded = rewarded + 1
                    break
                end
            end
        end
    end

    broadcast(('🏁 Race Night has ended. %d racers rewarded.'):format(rewarded), 'info')
    RaceNightPoints = {}
end)

exports('IsRaceNightActive', function() return RaceNightActive end)
exports('GetRaceNightPoints', function(charId) return RaceNightPoints[charId] or 0 end)

print(('^2[sunset_racing]^7 Street racing online (%d routes, hub at %.0f,%.0f,%.0f)'):format(
    #(Cfg.routes or {}), Cfg.raceHub.x, Cfg.raceHub.y, Cfg.raceHub.z))
