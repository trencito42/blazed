FactionCore = FactionCore or {}

local OnDuty = OnDuty or {}
local RateLimits = {}

function FactionCore.getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

function FactionCore.getFactionOf(char)
    return Sunset.GetCharacterFaction(char)
end

function FactionCore.isOnDuty(source)
    return OnDuty[source] == true
end

function FactionCore.setOnDuty(source, state)
    OnDuty[source] = state and true or false
end

function FactionCore.getOnDutyTable()
    return OnDuty
end

function FactionCore.hasPerm(source, perm)
    local char = FactionCore.getChar(source)
    if not char or not OnDuty[source] then return false end
    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then return false end
    if not Sunset.CapabilityAllowedForFaction(factionId, perm) and perm ~= 'invite' and perm ~= 'promote' then
        return false
    end
    return Sunset.HasFactionPerm(factionId, grade, perm)
end

function FactionCore.hasCapability(source, capability)
    local char = FactionCore.getChar(source)
    if not char or not OnDuty[source] then return false end
    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then return false end
    return Sunset.HasFactionCapability(factionId, grade, capability)
end

function FactionCore.isLawEnforcement(source)
    local char = FactionCore.getChar(source)
    if not char or not OnDuty[source] then return false end
    local factionId = FactionCore.getFactionOf(char)
    return factionId and Sunset.FactionTypeMatches(factionId, 'law_enforcement')
end

function FactionCore.playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function FactionCore.distBetween(a, b)
    if not a or not b then return 9999.0 end
    return #(a - b)
end

function FactionCore.isOnline(target)
    target = tonumber(target)
    if not target then return false end
    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) == target then return true end
    end
    return false
end

function FactionCore.notify(source, msg, typ, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, typ or 'info', duration)
end

function FactionCore.checkRateLimit(source, key, cooldownMs)
    cooldownMs = cooldownMs or 1500
    local now = os.time() * 1000
    RateLimits[source] = RateLimits[source] or {}
    local last = RateLimits[source][key] or 0
    if now - last < cooldownMs then return false end
    RateLimits[source][key] = now
    return true
end

function FactionCore.auditLog(factionId, actorCharId, action, targetCharId, details)
    pcall(function()
        MySQL.insert.await([[
            INSERT INTO faction_audit_log (faction_id, actor_character_id, action, target_character_id, details)
            VALUES (?, ?, ?, ?, ?)
        ]], {
            factionId,
            actorCharId,
            action,
            targetCharId,
            details and json.encode(details) or nil,
        })
    end)
end

function FactionCore.isFactionLeader(characterId, factionId)
    local row = MySQL.single.await(
        'SELECT id FROM faction_leaders WHERE character_id = ? AND faction_id = ? LIMIT 1',
        { characterId, factionId }
    )
    return row ~= nil
end

function FactionCore.canManageMembers(source)
    local char = FactionCore.getChar(source)
    if not char then return false end
    local factionId, grade = FactionCore.getFactionOf(char)
    if not factionId then return false end
    if FactionCore.isFactionLeader(char.id, factionId) then return true end
    return FactionCore.hasPerm(source, 'invite')
        or FactionCore.hasPerm(source, 'promote')
        or FactionCore.hasPerm(source, 'giverank')
        or FactionCore.hasPerm(source, 'uninvite')
        or FactionCore.hasPerm(source, 'fwarn')
        or FactionCore.hasPerm(source, 'fmotd')
end

AddEventHandler('playerDropped', function()
    RateLimits[source] = nil
end)
