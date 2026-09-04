local myFaction = nil
local myOnDuty = false
local lastHealth = 200
local lastArmor = 0
local lastFfNotify = 0

local function getPlayerState(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player < 0 then return nil, false end
    local bag = Player(serverId).state
    return bag.sunsetFaction, bag.sunsetOnDuty == true
end

local function isAllyOnDuty(serverId)
    if Sunset.Config.FactionFriendlyFire then return false end
    if not myFaction or not myOnDuty then return false end
    local faction, onDuty = getPlayerState(serverId)
    return faction == myFaction and onDuty
end

local function syncLocalState()
    local char = exports.sunset_core:GetCharacter()
    if char then
        myFaction = select(1, Sunset.GetCharacterFaction(char))
    end
    myOnDuty = exports.sunset_factions:IsOnDuty()
end

RegisterNetEvent('sunset:client:dutyState', function(state, factionId)
    myOnDuty = state == true
    if factionId then myFaction = factionId end
end)

RegisterNetEvent('sunset:client:characterLoaded', function()
    syncLocalState()
end)

RegisterNetEvent('sunset:client:updateCharacter', function()
    syncLocalState()
end)

AddStateBagChangeHandler('sunsetFaction', nil, function(bagName, _, value)
    local serverId = tonumber(bagName:match('player:(%d+)'))
    if serverId == GetPlayerServerId(PlayerId()) then
        myFaction = value
    end
end)

AddStateBagChangeHandler('sunsetOnDuty', nil, function(bagName, _, value)
    local serverId = tonumber(bagName:match('player:(%d+)'))
    if serverId == GetPlayerServerId(PlayerId()) then
        myOnDuty = value == true
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            lastHealth = GetEntityHealth(ped)
            lastArmor = GetPedArmour(ped)
        end
        Wait(150)
    end
end)

CreateThread(function()
    while true do
        local enabled = Sunset.Config.FriendlyFire ~= false
        local ped = PlayerPedId()
        NetworkSetFriendlyFireOption(enabled)
        SetCanAttackFriendly(ped, enabled, enabled)
        Wait(2000)
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if Sunset.Config.FactionFriendlyFire then return end

    local victim = args[1]
    local attacker = args[2]
    if victim ~= PlayerPedId() then return end
    if not attacker or attacker == 0 or not DoesEntityExist(attacker) then return end
    -- GTA reports the local ped as the attacker for some vehicle collision and
    -- windscreen damage events. That is not faction friendly fire.
    if attacker == victim then return end
    if not IsPedAPlayer(attacker) then return end

    local playerIdx = NetworkGetPlayerIndexFromPed(attacker)
    if playerIdx < 0 then return end
    local serverId = GetPlayerServerId(playerIdx)
    if serverId == GetPlayerServerId(PlayerId()) then return end
    if not isAllyOnDuty(serverId) then return end

    SetEntityHealth(victim, lastHealth)
    SetPedArmour(victim, lastArmor)

    local now = GetGameTimer()
    if now - lastFfNotify > 4000 then
        lastFfNotify = now
        exports.sunset_ui:Notify('Friendly fire blocked — same faction on duty', 'warning', 2500)
    end
end)

CreateThread(function()
    Wait(2000)
    syncLocalState()
end)
