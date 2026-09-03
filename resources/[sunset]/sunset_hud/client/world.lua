-- Lume RP: fără NPC-uri/trafic, fără wanted automat GTA
local customWanted = 0

exports('GetWantedLevel', function()
    return customWanted
end)

exports('SetWantedLevel', function(level)
    customWanted = math.max(0, math.min(5, tonumber(level) or 0))
end)

local function isPlayerPed(ped)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPedAPlayer(ped) then return true end
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        for _, playerId in ipairs(GetActivePlayers()) do
            if GetVehiclePedIsIn(GetPlayerPed(playerId), false) == veh then
                return true
            end
        end
    end
    return false
end

CreateThread(function()
    SetMaxWantedLevel(0)
    SetPedPopulationBudget(0)
    SetVehiclePopulationBudget(0)
    SetRandomEventFlag(false)

    while true do
        local playerId = PlayerId()

        SetPedDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetAmbientPedRangeMultiplierThisFrame(0.0)
        SetAmbientVehicleRangeMultiplierThisFrame(0.0)
        SetSomeVehicleDensityMultiplierThisFrame(0.0)

        SetGarbageTrucks(false)
        SetRandomBoats(false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        DistantCopCarSirens(false)
        DisablePlayerVehicleRewards(playerId)

        if GetPlayerWantedLevel(playerId) > 0 then
            ClearPlayerWantedLevel(playerId)
        end

        Wait(0)
    end
end)

-- Curăță NPC-uri și trafic ambiental din jurul jucătorului
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        SetVehicleGeneratorAreaOfInterest(coords.x, coords.y, coords.z, 1.0)
        RemoveVehiclesFromGeneratorsInArea(coords.x - 500.0, coords.y - 500.0, coords.z - 100.0, coords.x + 500.0, coords.y + 500.0, coords.z + 100.0, 0)

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and not IsPedAPlayer(GetPedInVehicleSeat(veh, -1)) then
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver == 0 or not isPlayerPed(driver) then
                    local vCoords = GetEntityCoords(veh)
                    if #(vCoords - coords) < 350.0 then
                        SetEntityAsMissionEntity(veh, true, true)
                        DeleteVehicle(veh)
                    end
                end
            end
        end

        for _, npc in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(npc) and not isPlayerPed(npc) and npc ~= ped then
                local nCoords = GetEntityCoords(npc)
                if #(nCoords - coords) < 250.0 then
                    SetEntityAsMissionEntity(npc, true, true)
                    DeletePed(npc)
                end
            end
        end

        Wait(2500)
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
