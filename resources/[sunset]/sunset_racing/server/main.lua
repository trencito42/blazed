-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Street Racing (server/main.lua)
--  Lobby, entry fee, checkpoint tracking, prize payout.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetRacing.Config
local Lobby = {}          -- [src] = { routeId, joinedAt }
local ActiveRace = nil    -- { routeId, players = {src,...}, startTime, checkpoints, finished = {} }
local PlayerProgress = {} -- [src] = { nextCheckpoint, startTime, finishedAt }

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function getCharId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id) or nil
end

-- ═══ LOBBY ═══

exports.sunset_core:RegisterCallback('sunset:racing:join', function(source, routeId)
    if ActiveRace then
        return nil, 'A race is already in progress. Wait for it to finish.'
    end
    if Lobby[source] then
        return nil, 'You are already in the lobby.'
    end

    routeId = tostring(routeId or '')
    local route = nil
    for _, r in ipairs(Cfg.routes or {}) do
        if r.id == routeId then route = r break end
    end
    if not route then return nil, 'Unknown race route.' end

    -- Check player is in a vehicle
    local inVehicle = false
    pcall(function()
        local ped = GetPlayerPed(source)
        inVehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
    end)
    if not inVehicle then
        return nil, 'You must be in a vehicle to join a race.'
    end

    -- Charge entry fee
    if not exports.sunset_core:RemoveMoney(source, 'cash', Cfg.entryFee or 1000, 'race_entry') then
        return nil, ('Not enough cash. Entry fee: $%s.'):format(Cfg.entryFee or 1000)
    end

    Lobby[source] = { routeId = routeId, joinedAt = os.time() }

    -- Notify all lobby members
    for src in pairs(Lobby) do
        notify(src, ('%s joined the race lobby (%d/%d).'):format(
            exports.sunset_core:GetPlayerDisplayName(src) or 'Someone', countLobby(), Cfg.minPlayers or 2), 'info')
    end

    -- Auto-start if enough players
    if countLobby() >= (Cfg.minPlayers or 2) then
        startRace(routeId)
    end

    return { routeId = routeId, players = countLobby(), minPlayers = Cfg.minPlayers or 2 }
end)

function countLobby()
    local n = 0
    for _ in pairs(Lobby) do n = n + 1 end
    return n
end

exports.sunset_core:RegisterCallback('sunset:racing:leave', function(source)
    if not Lobby[source] then return nil, 'You are not in the lobby.' end

    -- Refund entry fee
    exports.sunset_core:AddMoney(source, 'cash', Cfg.entryFee or 1000, 'race_refund')
    Lobby[source] = nil
    notify(source, 'Left the race lobby. Entry fee refunded.', 'info')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:racing:status', function(source)
    return {
        inLobby = Lobby[source] ~= nil,
        inRace = PlayerProgress[source] ~= nil,
        lobbyCount = countLobby(),
        minPlayers = Cfg.minPlayers or 2,
        entryFee = Cfg.entryFee or 1000,
        routes = Cfg.routes or {},
        activeRace = ActiveRace and { routeId = ActiveRace.routeId, players = #ActiveRace.players } or nil,
    }
end)

-- ═══ RACE LIFECYCLE ═══

function startRace(routeId)
    local route = nil
    for _, r in ipairs(Cfg.routes or {}) do
        if r.id == routeId then route = r break end
    end
    if not route or countLobby() < (Cfg.minPlayers or 2) then return end

    local players = {}
    for src in pairs(Lobby) do
        players[#players + 1] = src
        PlayerProgress[src] = { nextCheckpoint = 1, startTime = nil, finishedAt = nil }
    end

    ActiveRace = {
        routeId = routeId,
        route = route,
        players = players,
        startTime = nil,
        countdown = Cfg.countdownSeconds or 5,
        finished = {},
    }
    Lobby = {}

    -- Send countdown + checkpoints to all racers
    for _, src in ipairs(players) do
        TriggerClientEvent('sunset:racing:start', src, {
            routeId = routeId,
            label = route.label,
            checkpoints = route.checkpoints,
            countdown = Cfg.countdownSeconds or 5,
        })
    end

    -- Countdown thread
    CreateThread(function()
        for i = (Cfg.countdownSeconds or 5), 1, -1 do
            for _, src in ipairs(ActiveRace and ActiveRace.players or {}) do
                TriggerClientEvent('sunset:racing:countdown', src, i)
            end
            Wait(1000)
        end
        if ActiveRace then
            ActiveRace.startTime = os.time()
            for _, src in ipairs(ActiveRace.players) do
                if PlayerProgress[src] then
                    PlayerProgress[src].startTime = os.time()
                end
                TriggerClientEvent('sunset:racing:go', src)
            end
        end
    end)

    -- Timeout thread
    CreateThread(function()
        Wait((Cfg.raceTimeout or 600) * 1000)
        if ActiveRace and ActiveRace.routeId == routeId then
            endRace('timeout')
        end
    end)
end

-- Checkpoint reached
RegisterNetEvent('sunset:racing:checkpoint', function(checkpointIndex)
    local src = source
    if not ActiveRace or not PlayerProgress[src] then return end

    local progress = PlayerProgress[src]
    if checkpointIndex ~= progress.nextCheckpoint then return end

    progress.nextCheckpoint = checkpointIndex + 1
    local totalCheckpoints = #ActiveRace.route.checkpoints

    if progress.nextCheckpoint > totalCheckpoints then
        -- Finished!
        progress.finishedAt = os.time()
        ActiveRace.finished[#ActiveRace.finished + 1] = src
        TriggerClientEvent('sunset:racing:finished', src, {
            position = #ActiveRace.finished,
            time = progress.finishedAt - (progress.startTime or progress.finishedAt),
        })

        -- Check if all players finished
        if #ActiveRace.finished >= #ActiveRace.players then
            endRace('complete')
        end
    else
        TriggerClientEvent('sunset:racing:checkpointReached', src, {
            current = checkpointIndex,
            total = totalCheckpoints,
        })
    end
end)

function endRace(reason)
    if not ActiveRace then return end

    local totalPot = #ActiveRace.players * (Cfg.entryFee or 1000)
    local prize = math.floor(totalPot * (Cfg.prizeMultiplier or 0.8))

    if #ActiveRace.finished > 0 then
        local winner = ActiveRace.finished[1]
        exports.sunset_core:AddMoney(winner, 'cash', prize, 'race_prize')
        notify(winner, ('🏆 You won the race! Prize: $%s.'):format(prize), 'success', 10000)

        for i = 2, #ActiveRace.finished do
            local src = ActiveRace.finished[i]
            notify(src, ('Race finished — position #%d.'):format(i), 'info', 8000)
        end
    end

    -- Clean up
    for _, src in ipairs(ActiveRace.players) do
        TriggerClientEvent('sunset:racing:end', src, { reason = reason })
        PlayerProgress[src] = nil
    end
    ActiveRace = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    Lobby[src] = nil
    if PlayerProgress[src] then
        PlayerProgress[src] = nil
        -- If race is active and player was racing, check if race should end
        if ActiveRace then
            local active = false
            for _, s in ipairs(ActiveRace.players) do
                if s ~= src and PlayerProgress[s] then active = true break end
            end
            if not active then endRace('abandoned') end
        end
    end
end)

print(('^2[sunset_racing]^7 Street racing online (%d routes)'):format(#(Cfg.routes or {})))
