local OnDuty = {}

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function getGrade(char)
    return Sunset.GetFactionGrade(char.job, char.job_grade or 0)
end

local function hasPerm(source, perm)
    local char = getChar(source)
    if not char then return false end
    if not OnDuty[source] then return false end
    return Sunset.HasFactionPerm(char.job, char.job_grade, perm)
end

function IsOnDuty(source)
    return OnDuty[source] == true
end
exports('IsOnDuty', IsOnDuty)

local function setDuty(source, state)
    OnDuty[source] = state and true or false
    local char = getChar(source)
    if char then
        char.metadata = char.metadata or {}
        char.metadata.on_duty = OnDuty[source]
        TriggerClientEvent('sunset:client:updateCharacter', source, char)
    end
    TriggerClientEvent('sunset:client:dutyState', source, OnDuty[source], char and char.job)
end

exports.sunset_core:RegisterCallback('sunset:toggleDuty', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local faction = Sunset.Factions[char.job]
    if not faction or not faction.duty then return nil, 'Your job has no duty shift' end
    setDuty(source, not OnDuty[source])
    return OnDuty[source]
end)

exports.sunset_core:RegisterCallback('sunset:joinFactionHQ', function(source, factionId)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    local faction = Sunset.Factions[factionId]
    if not faction then return nil, 'Unknown faction' end

    if char.job ~= 'unemployed' and char.job ~= factionId then
        return nil, 'Leave your current faction first (/leavefaction)'
    end
    if char.job == factionId then return nil, 'You are already in this faction' end

    exports.sunset_core:SetJob(source, factionId, 0)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:leaveFaction', function(source)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    if char.job == 'unemployed' then return nil, 'You are not in a faction' end
    setDuty(source, false)
    exports.sunset_core:SetJob(source, 'unemployed', 0)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionInvite', function(source, targetId)
    local char = getChar(source)
    if not char then return nil, 'No character' end
    if not hasPerm(source, 'invite') then return nil, 'No permission' end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end
    local target = getChar(targetId)
    if not target then return nil, 'Target has no character' end
    if target.job ~= 'unemployed' then return nil, 'Target must be unemployed' end

    exports.sunset_core:SetJob(targetId, char.job, 0)
    TriggerClientEvent('sunset:client:notify', targetId, 'You joined ' .. (Sunset.Factions[char.job].label or char.job), 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:policeFine', function(source, targetId, amount, reason)
    if not hasPerm(source, 'fine') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or amount < 1 then return nil, 'Invalid fine' end
    if not GetPlayerName(targetId) then return nil, 'Player not found' end

    if not exports.sunset_core:RemoveMoney(targetId, 'bank', amount, 'fine') then
        if not exports.sunset_core:RemoveMoney(targetId, 'cash', amount, 'fine') then
            return nil, 'Target cannot pay'
        end
    end

    local officer = getChar(source)
    local target = getChar(targetId)
    if officer and target then
        MySQL.insert.await(
            'INSERT INTO faction_fines (officer_character_id, target_character_id, amount, reason) VALUES (?, ?, ?, ?)',
            { officer.id, target.id, amount, reason or '' }
        )
    end

    exports.sunset_core:AddMoney(source, 'bank', math.floor(amount * 0.1), 'fine_commission')
    TriggerClientEvent('sunset:client:notify', targetId, ('Fined $%s: %s'):format(amount, reason or '—'), 'error')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionHeal', function(source, targetId)
    if not hasPerm(source, 'heal') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId) or source
    if not GetPlayerName(targetId) then return nil, 'Player not found' end
    TriggerClientEvent('sunset:admin:heal', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:factionRevive', function(source, targetId)
    if not hasPerm(source, 'revive') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil, 'Player not found' end
    TriggerClientEvent('sunset:admin:revive', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:mechanicRepair', function(source, targetId)
    if not hasPerm(source, 'repair') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId) or source
    if not GetPlayerName(targetId) then return nil, 'Player not found' end
    TriggerClientEvent('sunset:faction:repairVehicle', targetId)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:taxiFare', function(source, targetId, amount)
    if not hasPerm(source, 'fare') then return nil, 'Not on duty or no permission' end
    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    if not targetId or amount < 1 then return nil, 'Invalid fare' end
    if not GetPlayerName(targetId) then return nil, 'Passenger not found' end
    if not exports.sunset_core:RemoveMoney(targetId, 'cash', amount, 'taxi') then
        if not exports.sunset_core:RemoveMoney(targetId, 'bank', amount, 'taxi') then
            return nil, 'Passenger cannot pay'
        end
    end
    exports.sunset_core:AddMoney(source, 'cash', amount, 'taxi_fare')
    TriggerClientEvent('sunset:client:notify', targetId, ('Taxi fare: $%s'):format(amount), 'info')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:getFactionPanel', function(source)
    local char = getChar(source)
    if not char then return nil end
    local faction = Sunset.Factions[char.job]
    if not faction then return { job = char.job, label = 'Unemployed' } end
    local grade = getGrade(char)
    return {
        job = char.job,
        label = faction.label,
        type = faction.type,
        grade = char.job_grade or 0,
        gradeLabel = grade and grade.label or '—',
        onDuty = OnDuty[source] == true,
        salary = grade and grade.salary or 0,
    }
end)

RegisterCommand('f', function(source, args)
    local char = getChar(source)
    if not char or char.job == 'unemployed' then return end
    local msg = table.concat(args, ' ')
    if msg == '' then return end
    local name = exports.sunset_core:GetPlayerDisplayName(source)
    local faction = Sunset.Factions[char.job]
    local label = faction and faction.label or char.job
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = getChar(src)
        if c and c.job == char.job then
            TriggerClientEvent('sunset:chat:message', src, {
                id = source,
                name = '[' .. label .. '] ' .. name,
                message = msg,
                time = os.date('%H:%M'),
            })
        end
    end
end, false)

RegisterNetEvent('sunset:server:factionCmd', function(cmd, ...)
    local source = source
    local args = { ... }
    if cmd == 'cuff' then
        if not hasPerm(source, 'cuff') then return end
        local target = tonumber(args[1])
        if target then TriggerClientEvent('sunset:faction:cuff', target) end
    end
end)

AddEventHandler('playerDropped', function()
    OnDuty[source] = nil
end)

AddEventHandler('sunset:server:characterSelected', function(source)
    OnDuty[source] = false
    TriggerClientEvent('sunset:client:dutyState', source, false, nil)
end)

AddEventHandler('sunset:server:jobChanged', function(source, job)
    OnDuty[source] = false
    TriggerClientEvent('sunset:client:dutyState', source, false, job)
end)

function GetDutyState(source)
    return OnDuty[source] == true
end
exports('GetDutyState', GetDutyState)
