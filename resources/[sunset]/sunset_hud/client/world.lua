-- Lume RP: fără NPC-uri/trafic, fără wanted automat GTA
local customWanted = 0
local customWantedDecayAt = nil

exports('GetWantedLevel', function()
    return customWanted
end)

exports('GetWantedDecayAt', function()
    return customWantedDecayAt
end)

exports('GetWantedRemainingSec', function()
    if not customWantedDecayAt then return nil end
    return math.max(0, customWantedDecayAt - GetCloudTimeAsInt())
end)

exports('SetWantedLevel', function(level)
    customWanted = math.max(0, math.min(5, tonumber(level) or 0))
    if customWanted <= 0 then
        customWantedDecayAt = nil
    end
end)

local function applyWantedFromBag(value)
    if value and value.level then
        customWanted = math.max(0, math.min(5, tonumber(value.level) or 0))
        customWantedDecayAt = value.decayAt
    else
        customWanted = 0
        customWantedDecayAt = nil
    end
end

RegisterNetEvent('sunset:client:wantedUpdate', function(level, reason)
    customWanted = math.max(0, math.min(5, tonumber(level) or 0))
    if customWanted <= 0 then
        customWantedDecayAt = nil
    end
end)

AddStateBagChangeHandler('sunsetWanted', nil, function(bagName, _, value)
    if bagName == ('player:%s'):format(GetPlayerServerId(PlayerId())) then
        applyWantedFromBag(value)
    end
end)

CreateThread(function()
    Wait(2000)
    local bag = LocalPlayer.state.sunsetWanted
    if bag then applyWantedFromBag(bag) end
end)

local function vehicleHasPlayerOccupant(veh)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    for seat = -1, maxSeats - 2 do
        local occupant = GetPedInVehicleSeat(veh, seat)
        if occupant ~= 0 and IsPedAPlayer(occupant) then
            return true
        end
    end
    return false
end

local function vehicleWasPlayerOwned(veh)
    local ok, result = pcall(function()
        return GetVehicleHasBeenOwnedByPlayer(veh)
    end)
    return ok and result == true
end

local function isProtectedVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return true end
    if vehicleHasPlayerOccupant(veh) then return true end
    if vehicleWasPlayerOwned(veh) then return true end
    local stateOk, stateProtected = pcall(function()
        return Entity(veh).state.sunsetProtectedVehicle
    end)
    if stateOk and stateProtected == true then return true end
    local ok, protected = pcall(function()
        return exports.sunset_vehicles:IsProtectedVehicle(veh)
    end)
    return ok and protected == true
end

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

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        SetVehicleGeneratorAreaOfInterest(coords.x, coords.y, coords.z, 1.0)
        RemoveVehiclesFromGeneratorsInArea(coords.x - 500.0, coords.y - 500.0, coords.z - 100.0, coords.x + 500.0, coords.y + 500.0, coords.z + 100.0, 0)

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and not isProtectedVehicle(veh) then
                -- Only remove GTA ambient population. Script/network/mission
                -- vehicles (population type 0 or >= 6) belong to gameplay.
                local populationType = GetEntityPopulationType(veh)
                local driver = GetPedInVehicleSeat(veh, -1)
                if populationType >= 1 and populationType <= 5 and (driver == 0 or not isPlayerPed(driver)) then
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
                local populationType = GetEntityPopulationType(npc)
                local nCoords = GetEntityCoords(npc)
                if populationType >= 1 and populationType <= 5 and #(nCoords - coords) < 250.0 then
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
