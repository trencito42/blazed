local MEDIC_RANGE = 5.0
local HEAL_RANGE = 5.0
local REVIVE_RANGE = 4.0

local function notify(source, msg, typ)
    TriggerClientEvent('sunset:client:notify', source, msg, typ or 'info')
end

local function distCheck(source, targetId, maxDist)
    local a = FactionCore.playerCoords(source)
    local b = FactionCore.playerCoords(targetId)
    return FactionCore.distBetween(a, b) <= (maxDist or 5.0)
end

local function recordActivity(source, action, targetId, details)
    local char = FactionCore.getChar(source)
    if not char then return end
    local factionId = FactionCore.getFactionOf(char)
    if not factionId then return end
    local targetChar = targetId and FactionCore.getChar(targetId)
    FactionCore.auditLog(factionId, char.id, action, targetChar and targetChar.id, details or {})
end

exports.sunset_core:RegisterCallback('sunset:emsStabilize', function(source, targetId)
    local isAdmin = false
    pcall(function() isAdmin = exports.sunset_admin:IsAdmin(source, 2) end)
    if not isAdmin and not FactionCore.hasPerm(source, 'stabilize') and not FactionCore.hasPerm(source, 'heal') then
        return nil, 'Not on duty or no permission'
    end
    targetId = tonumber(targetId)
    if not targetId or not FactionCore.isOnline(targetId) then
        return nil, 'Player not found'
    end
    if not isAdmin and targetId ~= source and not distCheck(source, targetId, MEDIC_RANGE) then
        return nil, 'You must be near the patient'
    end

    local ok, err = exports.sunset_death:StabilizePlayer(targetId)
    if not ok then return nil, err end

    notify(targetId, 'A medic stabilized your injuries.', 'info')
    notify(source, 'Patient stabilized.', 'success')
    recordActivity(source, 'stabilize', targetId, {})
    return true
end)

exports.sunset_core:RegisterCallback('sunset:emsHeal', function(source, targetId)
    local isAdmin = false
    pcall(function() isAdmin = exports.sunset_admin:IsAdmin(source, 2) end)
    if not isAdmin and not FactionCore.hasPerm(source, 'heal') then
        return nil, 'Not on duty or no permission'
    end
    targetId = tonumber(targetId) or source
    if not FactionCore.isOnline(targetId) then return nil, 'Player not found' end
    if targetId ~= source and not isAdmin and not distCheck(source, targetId, HEAL_RANGE) then
        return nil, 'You must be near the patient'
    end

    local isDowned = false
    pcall(function() isDowned = exports.sunset_death:IsPlayerDowned(targetId) end)
    if isDowned then
        return nil, 'Patient is downed — use /stabilize then /revive'
    end

    TriggerClientEvent('sunset:admin:heal', targetId)
    notify(source, 'Patient treated.', 'success')
    if targetId ~= source then
        notify(targetId, 'You were treated by medical staff.', 'success')
    end
    recordActivity(source, 'heal', targetId, {})
    return true
end)

exports.sunset_core:RegisterCallback('sunset:emsRevive', function(source, targetId)
    local isAdmin = false
    pcall(function() isAdmin = exports.sunset_admin:IsAdmin(source, 2) end)
    if not isAdmin and not FactionCore.hasPerm(source, 'revive') then
        return nil, 'Not on duty or no permission'
    end
    targetId = tonumber(targetId)
    if not targetId or not FactionCore.isOnline(targetId) then
        return nil, 'Usage: /revive [player id]'
    end
    if not isAdmin and not distCheck(source, targetId, REVIVE_RANGE) then
        return nil, 'You must be near the patient'
    end

    local isDowned = false
    pcall(function() isDowned = exports.sunset_death:IsPlayerDowned(targetId) end)
    if not isDowned then
        return nil, 'Target is not downed'
    end

    local ok, err = exports.sunset_death:RevivePlayer(targetId)
    if not ok then return nil, err end

    notify(source, 'Patient revived.', 'success')
    notify(targetId, 'You were revived by medical staff.', 'success')
    recordActivity(source, 'revive', targetId, {})

    local call = nil
    pcall(function() call = exports.sunset_dispatch:GetPlayerActiveCall(targetId, 'medic') end)
    if call and call.status ~= Sunset.Dispatch.States.COMPLETED then
        pcall(function() exports.sunset_dispatch:CompleteCall(source, 'medic', call.id) end)
    end

    return true
end)

AddEventHandler('sunset:dispatch:serviceCommand', function(callerSource, serviceType, callId)
    if serviceType ~= 'medic' then return end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if exports.sunset_factions:IsOnDuty(src) then
            local char = FactionCore.getChar(src)
            local factionId = char and FactionCore.getFactionOf(char)
            if factionId and Sunset.FactionTypeMatches(factionId, 'ems') then
                notify(src, ('Medic dispatch #%s — /accept medic %s'):format(callId, callId), 'warning', 10000)
            end
        end
    end
end)

AddEventHandler('sunset:death:playerDowned', function(victimSource)
    local coords = FactionCore.playerCoords(victimSource)
    if not coords then return end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src ~= victimSource and exports.sunset_factions:IsOnDuty(src) then
            local char = FactionCore.getChar(src)
            local factionId = char and FactionCore.getFactionOf(char)
            if factionId and (Sunset.FactionTypeMatches(factionId, 'ems') or Sunset.FactionTypeMatches(factionId, 'fire_rescue')) then
                local pos = FactionCore.playerCoords(src)
                if FactionCore.distBetween(coords, pos) <= (Sunset.Death and Sunset.Death.emsNotifyRadius or 500.0) then
                    notify(src, ('Injured civilian nearby (ID %s) — respond or /service medic'):format(victimSource), 'warning', 8000)
                end
            end
        end
    end
end)
