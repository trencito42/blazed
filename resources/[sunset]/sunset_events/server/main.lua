-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Server Events (server/main.lua)
--  Scheduled events: car meet, race night, fishing tournament.
--  Robust scheduler (idempotent, catches missed windows).
--
--  OWNERSHIP: sunset_events announces events and tracks participation.
--  For race_night, it delegates to sunset_racing (StartRaceNight/EndRaceNight)
--  and does NOT create its own marker at the race hub.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetEvents.Config
local ActiveEvent = nil       -- { type, label, startTime, endTime, location }
local EventParticipants = {}  -- [src] = { type, joinedAt, score }
local LastStartedHour = {}    -- [type] = hour (prevents double-start)

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

-- ═══ ROBUST SCHEDULER ═══
-- Checks every 30s. Starts an event if:
--   - current hour matches configured hour
--   - event not already active
--   - not already started this hour (idempotent)
-- Catches missed windows (server started late, resource restarted).

CreateThread(function()
    Wait(30000) -- Wait for server to fully boot
    while true do
        Wait(30000) -- Check every 30s
        local srvHour = tonumber(os.date('%H'))

        for _, ev in ipairs(Cfg.schedule or {}) do
            local shouldStart = srvHour == ev.hour
                and (not ActiveEvent or ActiveEvent.type ~= ev.type)
                and LastStartedHour[ev.type] ~= srvHour

            if shouldStart then
                LastStartedHour[ev.type] = srvHour
                startEvent(ev)
            end
        end

        -- Check event expiry
        if ActiveEvent and os.time() > ActiveEvent.endTime then
            endEvent()
        end
    end
end)

function startEvent(ev)
    local location = Cfg.locations[ev.type]
    ActiveEvent = {
        type = ev.type,
        label = ev.label,
        startTime = os.time(),
        endTime = os.time() + (ev.duration or 3600),
        location = location,
    }

    broadcast(('🎉 %s is starting! Head to the event location.'):format(ev.label), 'success')

    -- [SERVER-SIDE] Notify other server resources
    TriggerEvent('sunset:events:serverStart', ev)

    -- Race Night: delegate to sunset_racing
    if ev.type == 'race_night' and GetResourceState('sunset_racing') == 'started' then
        pcall(function() exports.sunset_racing:StartRaceNight() end)
    end

    -- Announce thread
    CreateThread(function()
        while ActiveEvent and ActiveEvent.type == ev.type do
            Wait((Cfg.announceInterval or 300) * 1000)
            if ActiveEvent and ActiveEvent.type == ev.type then
                local remaining = math.floor((ActiveEvent.endTime - os.time()) / 60)
                broadcast(('🎉 %s in progress — %d minutes remaining!'):format(ev.label, remaining), 'info')
            end
        end
    end)

    -- Notify all players with event info
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('sunset:events:start', tonumber(id), {
            type = ev.type,
            label = ev.label,
            location = location,
            endTime = ActiveEvent.endTime,
        })
    end
end

function endEvent()
    if not ActiveEvent then return end

    local evType = ActiveEvent.type

    -- Race Night: delegate to sunset_racing for rewards
    if evType == 'race_night' and GetResourceState('sunset_racing') == 'started' then
        pcall(function() exports.sunset_racing:EndRaceNight() end)
    else
        -- Non-race events: reward participants based on score
        local reward = Cfg.rewards[evType] or { cash = 1000, xp = 50 }
        local participantCount = 0
        for src, data in pairs(EventParticipants) do
            if data.type == evType and GetPlayerName(src) then
                participantCount = participantCount + 1
                exports.sunset_core:AddMoney(src, 'cash', reward.cash, 'event_reward')
                pcall(function()
                    exports.sunset_core:AddXP(src, reward.xp)
                end)
                notify(src, ('🏆 %s complete! Reward: $%s + %d XP.'):format(ActiveEvent.label, reward.cash, reward.xp), 'success', 10000)
            end
        end
        broadcast(('🏁 %s has ended. %d participants rewarded.'):format(ActiveEvent.label, participantCount), 'info')
    end

    -- Notify all clients to clean up
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('sunset:events:end', tonumber(id), { type = evType })
    end

    -- [SERVER-SIDE] Notify other server resources
    TriggerEvent('sunset:events:serverEnd', { type = evType })

    ActiveEvent = nil
    EventParticipants = {}
end

-- ═══ PARTICIPATION ═══
-- For non-race events (car meet, fishing tournament).
-- Race Night participation is tracked by sunset_racing (actual racing).

exports.sunset_core:RegisterCallback('sunset:events:join', function(source)
    if not ActiveEvent then
        return nil, 'No event is currently active.'
    end

    -- Race Night: participation is through racing, not E-press
    if ActiveEvent.type == 'race_night' then
        return nil, 'Race Night participation is through racing. Press E at the race hub to join a race.'
    end

    local location = ActiveEvent.location
    if location then
        local near = false
        pcall(function()
            local ped = GetPlayerPed(source)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                near = #(coords - location) < 50.0
            end
        end)
        if not near then
            return nil, 'You must be at the event location to participate.'
        end
    end

    EventParticipants[source] = { type = ActiveEvent.type, joinedAt = os.time(), score = 0 }
    notify(source, ('Joined %s!'):format(ActiveEvent.label), 'success')
    return { type = ActiveEvent.type, label = ActiveEvent.label }
end)

exports.sunset_core:RegisterCallback('sunset:events:status', function(source)
    if not ActiveEvent then
        return { active = false }
    end
    return {
        active = true,
        type = ActiveEvent.type,
        label = ActiveEvent.label,
        remaining = math.max(0, ActiveEvent.endTime - os.time()),
        participating = EventParticipants[source] ~= nil,
    }
end)

-- ═══ FISHING TOURNAMENT SCORE ═══
RegisterNetEvent('sunset:events:fishCaught', function()
    local src = source
    if ActiveEvent and ActiveEvent.type == 'fishing_tournament' and EventParticipants[src] then
        EventParticipants[src].score = (EventParticipants[src].score or 0) + 1
    end
end)

AddEventHandler('playerDropped', function()
    EventParticipants[source] = nil
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if ActiveEvent then
        for _, id in ipairs(GetPlayers()) do
            TriggerClientEvent('sunset:events:end', tonumber(id), { type = ActiveEvent.type })
        end
    end
end)

print('^2[sunset_events]^7 Server events online (car meet, race night, fishing tournament)')
