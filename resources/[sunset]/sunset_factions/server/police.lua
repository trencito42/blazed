local Wanted = {}

local function notify(source, msg, typ)
    FactionCore.notify(source, msg, typ or 'info')
end

local function syncWanted(targetId, level, reason)
    TriggerClientEvent('sunset:client:wantedUpdate', targetId, level or 0, reason or '')
end

local function setWanted(targetId, level, reason, reasonCode, jailMinutes)
    level = math.max(1, math.min(5, tonumber(level) or 1))
    local decayMin = (Sunset.Police and Sunset.Police.decayMinutes[level]) or 15
    Wanted[targetId] = {
        level = level,
        reason = reason or 'Unknown',
        reasonCode = reasonCode or '',
        jailMinutes = jailMinutes or 2,
        decayAt = os.time() + decayMin * 60,
    }
    syncWanted(targetId, level, reason)
end

local function clearWanted(targetId)
    Wanted[targetId] = nil
    syncWanted(targetId, 0, '')
end

function GetWantedState(source)
    return Wanted[source]
end
exports('GetWantedState', GetWantedState)

exports.sunset_core:RegisterCallback('sunset:policeSetWanted', function(source, targetId, reasonCode)
    if not FactionCore.hasPerm(source, 'wanted') then return nil, 'You must be on-duty law enforcement' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end

    reasonCode = string.lower(reasonCode or '')
    local reasonRow = Sunset.GetPoliceReason(reasonCode)
    if not reasonRow then
        local codes = {}
        for code in pairs(Sunset.Police.reasons or {}) do
            codes[#codes + 1] = code
        end
        table.sort(codes)
        return nil, ('Invalid reason. Use: %s'):format(table.concat(codes, ', '))
    end

    setWanted(targetId, reasonRow.stars, reasonRow.label, reasonCode, reasonRow.jailMinutes)

    notify(targetId, ('Wanted level %d — %s'):format(reasonRow.stars, reasonRow.label), 'error')
    notify(source, ('Set wanted on #%d — %s (★%d)'):format(targetId, reasonRow.label, reasonRow.stars), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeSummon', function(source, targetId)
    if not FactionCore.isLawEnforcement(source) then return nil, 'You must be on-duty law enforcement' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end

    local range = Sunset.Police and Sunset.Police.summonRange or 125.0
    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > range then
        return nil, ('You must be within %dm of the suspect'):format(math.floor(range))
    end

    notify(targetId, 'You are being summoned by law enforcement — stop and comply', 'warning', 10000)
    notify(source, ('Summoned player #%d'):format(targetId), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeWantedList', function(source)
    if not FactionCore.hasPerm(source, 'mdc') and not FactionCore.isLawEnforcement(source) then
        return nil, 'You must be on-duty law enforcement'
    end

    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local w = Wanted[src]
        if w then
            local remaining = math.max(0, w.decayAt - os.time())
            list[#list + 1] = {
                id = src,
                name = exports.sunset_core:GetPlayerDisplayName(src),
                level = w.level,
                reason = w.reason,
                remainingSec = remaining,
            }
        end
    end

    table.sort(list, function(a, b) return a.level > b.level end)
    return list
end)

exports.sunset_core:RegisterCallback('sunset:policeArrest', function(source, targetId)
    if not FactionCore.hasPerm(source, 'arrest') then return nil, 'You must be on-duty law enforcement' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end
    if not Detention.isCuffed(targetId) then return nil, 'Suspect must be restrained first (/cuff)' end

    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    local arrestRange = Sunset.Police and Sunset.Police.arrestRange or 5.0
    local nearOfficer = FactionCore.distBetween(officerPos, targetPos) <= arrestRange

    local atPdJail = false
    if Sunset.Police and Sunset.Police.pdJailPoint and targetPos then
        atPdJail = FactionCore.distBetween(targetPos, Sunset.Police.pdJailPoint) <= (Sunset.Police.jailRadius or 12.0)
    end

    if not nearOfficer and not atPdJail then
        return nil, 'Suspect must be near you or at the MRPD jail point'
    end

    local w = Wanted[targetId]
    local level = w and w.level or 1
    local minutes = w and w.jailMinutes or 2
    local bounty = (Sunset.Police and Sunset.Police.bounties[level]) or 100

    Detention.setCuffed(targetId, false)
    clearWanted(targetId)
    TriggerClientEvent('sunset:faction:uncuff', targetId)
    TriggerClientEvent('sunset:detention:sync', -1, targetId, { cuffed = false, escorted = false })

    local jail = Sunset.Police and Sunset.Police.jailCoords
    TriggerClientEvent('sunset:police:jail', targetId, minutes, {
        x = jail.x, y = jail.y, z = jail.z, w = jail.w,
    })

    exports.sunset_core:AddMoney(source, 'bank', bounty, 'arrest_bounty')
    notify(source, ('Suspect arrested — %d min jail, $%s bounty'):format(minutes, bounty), 'success')
    notify(targetId, ('You have been arrested — %d minutes'):format(minutes), 'error', 8000)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeReasons', function(source)
    if not FactionCore.isLawEnforcement(source) then return nil end
    local list = {}
    for code, row in pairs(Sunset.Police.reasons or {}) do
        list[#list + 1] = {
            code = code,
            label = row.label,
            stars = row.stars,
            jailMinutes = row.jailMinutes,
        }
    end
    table.sort(list, function(a, b) return a.stars < b.stars end)
    return list
end)

exports.sunset_core:RegisterCallback('sunset:policeBackup', function(source)
    if not FactionCore.hasPerm(source, 'backup') then return nil, 'No permission' end
    local pos = FactionCore.playerCoords(source)
    local name = exports.sunset_core:GetPlayerDisplayName(source)
    local sent = 0
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src ~= source and FactionCore.isLawEnforcement(src) then
            TriggerClientEvent('sunset:client:notify', src,
                ('BACKUP requested by %s (#%d)'):format(name, source), 'warning', 12000)
            TriggerClientEvent('sunset:police:backupBlip', src, { x = pos.x, y = pos.y, z = pos.z }, source)
            sent = sent + 1
        end
    end
    if sent < 1 then return nil, 'No on-duty units available' end
    return sent
end)

CreateThread(function()
    while true do
        Wait(60000)
        for src, w in pairs(Wanted) do
            if not GetPlayerName(src) then
                Wanted[src] = nil
            elseif w.decayAt and os.time() >= w.decayAt then
                local newLevel = w.level - 1
                if newLevel <= 0 then
                    clearWanted(src)
                    notify(src, 'Your wanted level has expired', 'success')
                else
                    local decayMin = (Sunset.Police and Sunset.Police.decayMinutes[newLevel]) or 15
                    w.level = newLevel
                    w.decayAt = os.time() + decayMin * 60
                    syncWanted(src, newLevel, w.reason)
                    notify(src, ('Wanted level reduced to %d'):format(newLevel), 'info')
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    Wanted[source] = nil
end)
