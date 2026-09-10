local HEAD_BONES = {
    [31086] = true,
    [39317] = true,
}

local lastHealth = 200
local lastArmor = 0
local lastPulseAt = 0

local function getDamageDirection(attacker)
    if not attacker or attacker == 0 or not DoesEntityExist(attacker) then return nil end
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local attCoords = GetEntityCoords(attacker)
    local forward = GetEntityForwardVector(ped)
    local right = vector3(-forward.y, forward.x, 0.0)
    local diff = attCoords - pedCoords
    local flat = vector3(diff.x, diff.y, 0.0)
    local len = #(flat)
    if len < 0.05 then return nil end
    flat = flat / len
    local dotForward = forward.x * flat.x + forward.y * flat.y
    local dotRight = right.x * flat.x + right.y * flat.y
    if math.abs(dotForward) >= math.abs(dotRight) then
        if dotForward > 0.0 then return 'top' end
        return 'bottom'
    end
    if dotRight > 0.0 then return 'right' end
    return 'left'
end

local function pushDamageIndicator(amount, dmgType, direction)
    if not amount or amount < 1 then return end
    exports.sunset_ui:Send('damageTaken', {
        amount = math.floor(amount),
        type = dmgType,
        direction = direction,
    })
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            lastHealth = GetEntityHealth(ped)
            lastArmor = GetPedArmour(ped)
        end
        Wait(200)
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim = args[1]
    if victim ~= PlayerPedId() then return end

    local attacker = args[2]
    local direction = getDamageDirection(attacker)

    SetTimeout(0, function()
        local ped = PlayerPedId()
        if not ped or ped == 0 then return end

        local now = GetGameTimer()
        if now - lastPulseAt < 80 then return end

        local newHealth = GetEntityHealth(ped)
        local newArmor = GetPedArmour(ped)
        local armorLoss = math.max(0, lastArmor - newArmor)
        local healthLoss = math.max(0, lastHealth - newHealth)

        if armorLoss < 1 and healthLoss < 1 then return end
        lastPulseAt = now

        local dmgType = 'health'
        local amount = healthLoss

        if armorLoss >= 1 then
            dmgType = 'armor'
            amount = armorLoss
        else
            local ok, bone = GetPedLastDamageBone(ped)
            if ok and HEAD_BONES[bone] then
                dmgType = 'crit'
            end
            amount = healthLoss
        end

        pushDamageIndicator(amount, dmgType, direction)
        lastHealth = newHealth
        lastArmor = newArmor
    end)
end)
