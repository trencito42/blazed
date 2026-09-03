-- Lume RP: fără NPC-uri, fără wanted automat GTA (doar PD custom mai târziu)
local customWanted = 0

exports('GetWantedLevel', function()
    return customWanted
end)

exports('SetWantedLevel', function(level)
    customWanted = math.max(0, math.min(5, tonumber(level) or 0))
end)

CreateThread(function()
    SetMaxWantedLevel(0)

    while true do
        SetPedDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetGarbageTrucks(false)
        SetRandomBoats(false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        DisablePlayerVehicleRewards(PlayerId())

        local playerId = PlayerId()
        if GetPlayerWantedLevel(playerId) > 0 then
            ClearPlayerWantedLevel(playerId)
        end

        Wait(0)
    end
end)

CreateThread(function()
    while true do
        local playerId = PlayerId()
        SetPoliceIgnorePlayer(playerId, true)
        SetDispatchCopsForPlayer(playerId, false)
        SetPlayerWantedLevel(playerId, 0, false)
        Wait(2000)
    end
end)
