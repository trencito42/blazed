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
    local pos = hospitalSpawn(char)
    pcall(function() exports.sunset_core:SaveCharacter(source) end)
    TriggerClientEvent('sunset:client:respawn', source, pos, bill)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
    return true
end

function RevivePlayer(targetId)
    targetId = tonumber(targetId)
    if not targetId then
        return false, 'Usage: /revive [player id]'
    end
    local found = false
    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) == targetId then
            found = true
            break
        end
    end
    if not found then
        return false, 'Player not found — check TAB for server ID'
    end

    local char = exports.sunset_core:GetCharacter(targetId)
    if char then
        char.is_dead = false
        TriggerClientEvent('sunset:client:updateCharacter', targetId, char)
    end

    TriggerClientEvent('sunset:death:reviveInPlace', targetId)
    return true
end

exports('RevivePlayer', RevivePlayer)
exports('RespawnPlayer', respawnPlayer)

RegisterNetEvent('sunset:server:playerDied', function()
    local source = source
    respawnPlayer(source, Sunset.Config.HospitalBill or 0)
end)

RegisterNetEvent('sunset:server:requestRespawn', function()
    local source = source
    respawnPlayer(source, Sunset.Config.HospitalBill or 0)
end)

exports.sunset_core:RegisterCallback('sunset:revivePlayer', function(source, targetId)
    targetId = tonumber(targetId)
    if not targetId then
        return nil, 'Usage: /revive [player id]'
    end

    local isAdmin = false
    pcall(function()
        isAdmin = exports.sunset_admin:IsAdmin(source, 2)
    end)
    local isEms = false
    pcall(function()
        isEms = exports.sunset_factions:HasFactionPerm(source, 'revive')
    end)
    if not isAdmin and not isEms then
        return nil, 'Not on duty or no permission'
    end

    local ok, err = RevivePlayer(targetId)
    if not ok then return nil, err end
    return true
end)
