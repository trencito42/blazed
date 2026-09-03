local Downed = {}

local function hospitalSpawn(char)
    local pos = char and exports.sunset_core:GetSpawnPosition(char)
    if pos and pos.x then return pos end
    local h = Sunset.Config.HospitalSpawn or Sunset.Config.DefaultSpawn
    return { x = h.x, y = h.y, z = h.z, w = h.w }
end

local function respawnPlayer(source, bill)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'No character' end

    bill = bill or 0
    if bill > 0 then
        if not exports.sunset_core:RemoveMoney(source, 'bank', bill, 'hospital') then
            exports.sunset_core:RemoveMoney(source, 'cash', bill, 'hospital')
        end
    end

    char.is_dead = false
    Downed[source] = nil
    local pos = hospitalSpawn(char)
    pcall(function() exports.sunset_core:SaveCharacter(source) end)
    TriggerClientEvent('sunset:death:forceHospital', source, pos, bill)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function RevivePlayer(targetId)
    targetId = tonumber(targetId)
    if not targetId then
        return false, 'Usage: /revive [player id]'
    end
    if not GetPlayerName(targetId) then
        return false, 'Player not found — check TAB for server ID'
    end

    local char = exports.sunset_core:GetCharacter(targetId)
    if char then
        char.is_dead = false
        TriggerClientEvent('sunset:client:updateCharacter', targetId, char)
    end

    Downed[targetId] = nil
    TriggerClientEvent('sunset:death:reviveInPlace', targetId)
    return true
end

function StabilizePlayer(targetId)
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return false, 'Player not found'
    end
    if not Downed[targetId] then
        return false, 'Target is not downed'
    end
    Downed[targetId].stabilized = true
    TriggerClientEvent('sunset:death:stabilized', targetId)
    return true
end

exports('RevivePlayer', RevivePlayer)
exports('RespawnPlayer', respawnPlayer)
exports('StabilizePlayer', StabilizePlayer)
exports('IsPlayerDowned', function(source) return Downed[source] ~= nil end)

RegisterNetEvent('sunset:server:playerDied', function()
    local source = source
    local char = exports.sunset_core:GetCharacter(source)
    if char then char.is_dead = true end
    Downed[source] = { startedAt = os.time(), stabilized = false }
    TriggerEvent('sunset:death:playerDowned', source)
end)

RegisterNetEvent('sunset:death:enteredDowned', function()
    local source = source
    if not Downed[source] then
        Downed[source] = { startedAt = os.time(), stabilized = false }
    end
end)

RegisterNetEvent('sunset:server:bleedoutExpired', function()
    local source = source
    if not Downed[source] then return end
    respawnPlayer(source, Sunset.Config.HospitalBill or 0)
end)

RegisterNetEvent('sunset:server:requestRespawn', function()
    local source = source
    if not Downed[source] then return end
    respawnPlayer(source, Sunset.Config.HospitalBill or 0)
end)

AddEventHandler('playerDropped', function()
    Downed[source] = nil
end)

exports.sunset_core:RegisterCallback('sunset:revivePlayer', function(source, targetId)
    targetId = tonumber(targetId)
    if not targetId then return nil, 'Usage: /revive [player id]' end

    local isAdmin = false
    pcall(function() isAdmin = exports.sunset_admin:IsAdmin(source, 2) end)
    local isEms = false
    pcall(function() isEms = exports.sunset_factions:HasFactionPerm(source, 'revive') end)
    if not isAdmin and not isEms then return nil, 'Not on duty or no permission' end

    local ok, err = RevivePlayer(targetId)
    if not ok then return nil, err end
    return true
end)

