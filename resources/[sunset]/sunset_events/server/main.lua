-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Server Events (server/main.lua)
--  Scheduled events: car meet, race night, fishing tournament.
--  Announce + marker + participation tracking + rewards.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetEvents.Config
local ActiveEvent = nil       -- { type, label, startTime, endTime, participants = {} }
local EventParticipants = {}  -- [src] = { type, joinedAt, score }

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

-- ═══ EVENT SCHEDULER ═══

CreateThread(function()
    Wait(60000) -- Wait for server to fully boot
    while true do
        Wait(60000) -- Check every minute
        local srvHour = tonumber(os.date('%H'))
        local srvMin = tonumber(os.date('%M'))

        for _, ev in ipairs(Cfg.schedule or {}) do
            if srvHour == ev.hour and srvMin == 0 and (not ActiveEvent or ActiveEvent.type ~= ev.type) then
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

    broadcast(('🎉 %s is starting! Head to the event marker on your map.'):format(ev.label), 'success')

    -- [SERVER-SIDE] Notify other server resources (e.g. fishing tournament tracker)
    TriggerEvent('sunset:events:serverStart', ev)

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
    local reward = Cfg.rewards[evType] or { cash = 1000, xp = 50 }

    -- Reward participants
    local participantCount = 0
    for src, data in pairs(EventParticipants) do
        if data.type == evType and GetPlayerName(src) then
            participantCount = participantCount + 1
            exports.sunset_core:AddMoney(src, 'cash', reward.cash, 'event_reward')
            pcall(function()
                exports.sunset_core:AddXP(src, reward.xp)
            end)
            notify(src, ('🏆 %s complete! Reward: $%s + %d XP.'):format(ActiveEvent.label, reward.cash, reward.xp), 'success', 10000)
            TriggerClientEvent('sunset:events:end', src, { type = evType })
        end
    end

    broadcast(('🏁 %s has ended. %d participants rewarded.'):format(ActiveEvent.label, participantCount), 'info')

    -- [SERVER-SIDE] Notify other server resources
    TriggerEvent('sunset:events:serverEnd', { type = evType })

    ActiveEvent = nil
    EventParticipants = {}
end

-- ═══ PARTICIPATION ═══

exports.sunset_core:RegisterCallback('sunset:events:join', function(source)
    if not ActiveEvent then
        return nil, 'No event is currently active.'
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
    notify(source, ('Joined %s! Stay in the area to earn your reward.'):format(ActiveEvent.label), 'success')
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
-- Track fish caught during fishing tournament
RegisterNetEvent('sunset:events:fishCaught', function()
    local src = source
    if ActiveEvent and ActiveEvent.type == 'fishing_tournament' and EventParticipants[src] then
        EventParticipants[src].score = (EventParticipants[src].score or 0) + 1
    end
end)

AddEventHandler('playerDropped', function()
    EventParticipants[source] = nil
end)

print('^2[sunset_events]^7 Server events online (car meet, race night, fishing tournament)')
