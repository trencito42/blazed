local function testExpired(session)
    if not session then return true end
    local practical = SunsetLicenses.Practical[session.licenseType]
    local maxSeconds = practical and tonumber(practical.maxTimeSec) or 600
    local began = tonumber(session.practicalStartedAt) or 0
    return began <= 0 or os.time() - began > maxSeconds + 30
end

function CleanupLicenseTestEntities(source)
    local session = GetTestSession(source)
    if not session then return end
    local netIds = {}
    if session.testVehicleNet then netIds[#netIds + 1] = session.testVehicleNet end
    for netId in pairs(session.weaponTargets or {}) do netIds[#netIds + 1] = netId end
    for _, netId in ipairs(netIds) do
        local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end

local function practicalVehicleModel(licenseType)
    local practical = SunsetLicenses.Practical[licenseType]
    local def = SunsetLicenses.Types[licenseType]
    local facility = def and SunsetLicenses.Facilities[def.facility]
    return facility and facility.testVehicle or practical and practical.vehicle
end

local function validSupervisor(session)
    local instructor = session and tonumber(session.instructor)
    if not instructor or not GetPlayerName(instructor) then return nil end
    local char = exports.sunset_core:GetCharacter(instructor)
    if not char or Sunset.GetCharacterFaction(char) ~= 'lssi'
        or not exports.sunset_factions:IsOnDuty(instructor) then return nil end
    return GetPlayerPed(instructor)
end

local function validateTestVehicle(source, session)
    local netId = tonumber(session.testVehicleNet)
    if not netId or netId <= 0 then
        return nil, 'The training vehicle was not registered. Restart the practical test.'
    end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return nil, 'The training vehicle no longer exists. Restart the practical test.'
    end
    local expectedModel = practicalVehicleModel(session.licenseType)
    if expectedModel and GetEntityModel(vehicle) ~= GetHashKey(expectedModel) then
        return nil, 'You must use the vehicle assigned for this practical test.'
    end
    if NetworkGetEntityOwner(vehicle) ~= source then
        return nil, 'The assigned training vehicle is not under your control.'
    end
    local ped = GetPlayerPed(source)
    if ped == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, 'You must be in the driver seat of your assigned training vehicle.'
    end
    local def = SunsetLicenses.Types[session.licenseType]
    if def and def.instructorFaction and session.licenseType ~= 'weapon' then
        local instructorPed = validSupervisor(session) or 0
        if instructorPed == 0 or GetVehiclePedIsIn(instructorPed, false) ~= vehicle then
            return nil, 'Your LSSI instructor must supervise the practical from the assigned vehicle.'
        end
    end
    return vehicle
end

exports.sunset_core:RegisterCallback('sunset:license:registerTestVehicle', function(source, netId)
    local session = GetTestSession(source)
    if not session or session.phase ~= 'practical' or session.licenseType == 'weapon' or testExpired(session) then
        return nil, 'No active vehicle practical test.'
    end
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil, 'Invalid training vehicle.' end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return nil, 'Training vehicle is not network-ready yet.'
    end
    local expectedModel = practicalVehicleModel(session.licenseType)
    if not expectedModel or GetEntityModel(vehicle) ~= GetHashKey(expectedModel) then
        return nil, 'Wrong vehicle model for this practical test.'
    end
    if NetworkGetEntityOwner(vehicle) ~= source then
        return nil, 'Training vehicle ownership could not be verified.'
    end
    local ped = GetPlayerPed(source)
    if ped == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, 'Enter the driver seat before the vehicle is registered.'
    end
    session.testVehicleNet = netId
    session.vehicleRegisteredAt = os.time()
    return true
end)

exports.sunset_core:RegisterCallback('sunset:license:validateCheckpoint', function(source, licenseType, index)
    licenseType = tostring(licenseType or '')
    index = tonumber(index)
    if not index then return false, 'Invalid checkpoint.' end
    local session = GetTestSession(source)
    if not session or session.licenseType ~= licenseType or session.phase ~= 'practical' then
        return false, 'No active practical test.'
    end
    if testExpired(session) then return false, 'The practical test time expired.' end
    local practical = SunsetLicenses.Practical[licenseType]
    if not practical or not practical.checkpoints or not practical.checkpoints[index] then
        return false, 'Invalid checkpoint index.'
    end
    session.lastCheckpoint = tonumber(session.lastCheckpoint) or 0
    if index ~= session.lastCheckpoint + 1 then
        return false, ('Wrong checkpoint order — go to checkpoint %d next.'):format(session.lastCheckpoint + 1)
    end
    local vehicle, vehicleError = validateTestVehicle(source, session)
    if not vehicle then return false, vehicleError end
    local pos = GetEntityCoords(vehicle)
    local cp = practical.checkpoints[index]
    local radius = practical.checkpointRadius or 8.0
    if #(pos - cp) > radius + 2.0 then return false, 'You are too far from the checkpoint.' end
    if licenseType == 'pilot' and pos.z < cp.z - math.max(8.0, radius * 0.35) then
        return false, 'Gain altitude and fly through the checkpoint; it cannot be passed from the ground.'
    end
    session.lastCheckpoint = index
    session.practicalEvidence = session.practicalEvidence or {}
    session.practicalEvidence[#session.practicalEvidence + 1] = {
        event = 'checkpoint', index = index, at = os.time(),
        x = pos.x, y = pos.y, z = pos.z,
    }
    if index >= #practical.checkpoints then session.allCheckpoints = true end
    return true, { index = index, total = #practical.checkpoints }
end)

exports.sunset_core:RegisterCallback('sunset:license:registerWeaponTargets', function(source, targetNetIds)
    local session = GetTestSession(source)
    if not session or session.licenseType ~= 'weapon' or session.phase ~= 'practical' or testExpired(session) then
        return nil, 'No active weapon practical test.'
    end
    if type(targetNetIds) ~= 'table' then return nil, 'Invalid range targets.' end
    local practical = SunsetLicenses.Practical.weapon
    local registered = {}
    for index, netId in ipairs(targetNetIds) do
        netId = tonumber(netId)
        local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
        local expected = practical.targets[index]
        if not expected or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 3
            or GetEntityModel(entity) ~= GetHashKey('prop_range_target_01')
            or NetworkGetEntityOwner(entity) ~= source then
            return nil, ('Range target %d could not be verified.'):format(index)
        end
        local pos = GetEntityCoords(entity)
        if #(pos - vector3(expected.x, expected.y, expected.z - 1.0)) > 3.0 then
            return nil, ('Range target %d is in the wrong position.'):format(index)
        end
        registered[netId] = index
    end
    if #targetNetIds ~= #(practical.targets or {}) then return nil, 'Not all range targets were registered.' end
    session.weaponTargets = registered
    session.weaponHits = {}
    session.weaponTargetsRegisteredAt = GetGameTimer()
    return true
end)

local function recordWeaponTargetHit(source, session, netId)
    local index = netId and session.weaponTargets and session.weaponTargets[netId]
    if not index or session.weaponHits[index] then return false end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local expected = SunsetLicenses.Practical.weapon.targets[index]
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 3
        or GetEntityModel(entity) ~= GetHashKey('prop_range_target_01') or not expected then return false end
    if #(GetEntityCoords(entity) - vector3(expected.x, expected.y, expected.z - 1.0)) > 3.0 then return false end
    session.weaponHits[index] = true
    session.practicalEvidence = session.practicalEvidence or {}
    session.practicalEvidence[#session.practicalEvidence + 1] = {
        event = 'target_hit', index = index, at = os.time(),
    }
    local count = 0
    for _ in pairs(session.weaponHits) do count = count + 1 end
    TriggerClientEvent('sunset:licenses:weaponProgress', source, count,
        SunsetLicenses.Practical.weapon.targetsRequired or 5)
    return true
end

-- Fallback for locally-owned network targets: the server validates the registered entity,
-- range position and cadence instead of trusting a client-provided hit count or index.
exports.sunset_core:RegisterCallback('sunset:license:claimWeaponTargetHit', function(source, targetNetId)
    local session = GetTestSession(source)
    if not session or session.licenseType ~= 'weapon' or session.phase ~= 'practical'
        or testExpired(session) or not session.weaponTargets then return false end
    local now = GetGameTimer()
    if now - (session.weaponTargetsRegisteredAt or now) < 1000
        or now - (session.weaponLastClaimAt or 0) < 250 then return false end
    local ped = GetPlayerPed(source)
    local practical = SunsetLicenses.Practical.weapon
    if ped == 0 or #(GetEntityCoords(ped) - practical.zoneCenter) > (practical.zoneRadius or 22.0) then return false end
    session.weaponLastClaimAt = now
    return recordWeaponTargetHit(source, session, tonumber(targetNetId))
end)

AddEventHandler('weaponDamageEvent', function(sender, data)
    local session = GetTestSession(sender)
    if not session or session.licenseType ~= 'weapon' or session.phase ~= 'practical'
        or testExpired(session) or type(data) ~= 'table' then return end
    local netId = tonumber(data.hitGlobalId)
    local index = netId and session.weaponTargets and session.weaponTargets[netId]
    if not index or session.weaponHits[index] then return end
    local ped = GetPlayerPed(sender)
    if ped == 0 then return end
    local practical = SunsetLicenses.Practical.weapon
    if #(GetEntityCoords(ped) - practical.zoneCenter) > (practical.zoneRadius or 22.0) then return end
    if tonumber(data.weaponType) ~= GetHashKey(practical.weapon or 'WEAPON_PISTOL') then return end
    recordWeaponTargetHit(sender, session, netId)
end)

exports.sunset_core:RegisterCallback('sunset:license:validateFinish', function(source, licenseType, data)
    licenseType = tostring(licenseType or '')
    local session = GetTestSession(source)
    if not session or session.licenseType ~= licenseType or session.phase ~= 'practical' then
        return false, 'No active practical test.'
    end
    if testExpired(session) then return false, 'The practical test time expired.' end
    local practical = SunsetLicenses.Practical[licenseType]
    if not practical then return false, 'Invalid practical test.' end
    local ped = GetPlayerPed(source)
    if ped == 0 then return false, 'Your position could not be verified.' end
    local pos = GetEntityCoords(ped)

    if licenseType == 'weapon' then
        local hits = 0
        for _ in pairs(session.weaponHits or {}) do hits = hits + 1 end
        local need = practical.targetsRequired or 5
        if hits < need then return false, ('Hit %d/%d verified targets first.'):format(hits, need) end
        local facility = SunsetLicenses.Facilities.range
        if #(pos - facility.marker) > (facility.markerRadius or 2.5) + 3.0 then
            return false, 'Return to the range booth to finish the test.'
        end
        local instructorPed = validSupervisor(session) or 0
        if instructorPed == 0 or #(GetEntityCoords(instructorPed) - practical.zoneCenter) > (practical.zoneRadius or 22.0) + 5.0 then
            return false, 'Your LSSI instructor must remain at the range until the exam is finished.'
        end
    else
        if not session.allCheckpoints then return false, 'Complete all checkpoints before finishing.' end
        local vehicle, vehicleError = validateTestVehicle(source, session)
        if not vehicle then return false, vehicleError end
        local finish = practical.finish
        if finish and #(GetEntityCoords(vehicle) - vector3(finish.x, finish.y, finish.z))
            > (practical.finishRadius or 10.0) + 2.0 then
            return false, 'Return with your assigned vehicle to the finish point.'
        end
        -- Engine-running state is not exposed as a server native. The server still verifies
        -- the exact test vehicle, driver seat and finish position before accepting this flag.
        if practical.requireEngineOff and (type(data) ~= 'table' or data.engineOn ~= false) then
            return false, 'Shut off the engine before finishing.'
        end
        local maxPenalties = practical.maxPenalties or practical.maxSpeedStrikes or 4
        local penaltyCount = tonumber(data and data.penalties)
        if penaltyCount == nil then
            local collisions = tonumber(data and data.collisions) or 0
            local speedStrikes = tonumber(data and data.speedStrikes) or 0
            penaltyCount = collisions + speedStrikes
        end
        if penaltyCount >= maxPenalties then
            return false, ('Too many penalties during the test (%d/%d).'):format(penaltyCount, maxPenalties)
        end
    end

    session.phase = 'validated'
    session.practicalValidatedAt = os.time()
    session.practicalEvidence = session.practicalEvidence or {}
    session.practicalEvidence[#session.practicalEvidence + 1] = {
        event = 'finish_validated', at = session.practicalValidatedAt,
    }
    return true
end)
