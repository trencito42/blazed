local function notify(source, message, kind)
    TriggerClientEvent('sunset:client:notify', source, message, kind or 'info', 7000)
end

exports.sunset_core:RegisterCallback('sunset:license:validateCheckpoint', function(source, licenseType, index)
    licenseType = tostring(licenseType or '')
    index = tonumber(index)
    if not index then return false, 'Invalid checkpoint.' end
    local session = GetTestSession(source)
    if not session or session.licenseType ~= licenseType or session.phase ~= 'practical' then
        return false, 'No active practical test.'
    end
    local practical = SunsetLicenses.Practical[licenseType]
    if not practical or not practical.checkpoints or not practical.checkpoints[index] then
        return false, 'Invalid checkpoint index.'
    end
    local expected = index - 1
    session.lastCheckpoint = tonumber(session.lastCheckpoint) or 0
    if index ~= session.lastCheckpoint + 1 then
        return false, ('Wrong checkpoint order — go to checkpoint %d next.'):format(session.lastCheckpoint + 1)
    end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'Position unavailable.' end
    local pos = GetEntityCoords(ped)
    local cp = practical.checkpoints[index]
    local radius = practical.checkpointRadius or 8.0
    if #(pos - cp) > radius + 5.0 then
        return false, 'You are too far from the checkpoint.'
    end
    session.lastCheckpoint = index
    if index >= #practical.checkpoints then
        session.allCheckpoints = true
    end
    return true, { index = index, total = #practical.checkpoints }
end)

exports.sunset_core:RegisterCallback('sunset:license:validateFinish', function(source, licenseType, data)
    licenseType = tostring(licenseType or '')
    local session = GetTestSession(source)
    if not session or session.licenseType ~= licenseType or session.phase ~= 'practical' then
        return false, 'No active practical test.'
    end
    if not session.allCheckpoints then
        return false, 'Complete all checkpoints before finishing.'
    end
    local practical = SunsetLicenses.Practical[licenseType]
    if not practical then return false, 'Invalid test.' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'Position unavailable.' end
    local pos = GetEntityCoords(ped)

    if licenseType == 'weapon' then
        local hits = tonumber(data and data.hits) or 0
        local need = practical.targetsRequired or 5
        if hits < need then
            return false, ('Hit %d/%d targets to pass the range test.'):format(hits, need)
        end
        return true
    end

    local finish = practical.finish
    if finish then
        local fr = practical.finishRadius or 10.0
        local finishPos = type(finish) == 'vector3' and finish or vector3(finish.x, finish.y, finish.z)
        if #(pos - finishPos) > fr + 5.0 then
            return false, 'Return to the finish point to complete the test.'
        end
    end

    if practical.requireEngineOff and data and data.engineOn then
        return false, 'Shut off the engine before finishing.'
    end

    return true
end)

exports.sunset_core:RegisterCallback('sunset:license:weaponTargetHit', function(source, licenseType, targetIndex)
    licenseType = tostring(licenseType or '')
    targetIndex = tonumber(targetIndex)
    local session = GetTestSession(source)
    if not session or session.licenseType ~= licenseType then return false end
    session.weaponHits = session.weaponHits or {}
    if session.weaponHits[targetIndex] then return true, session.weaponHits end
    local ped = GetPlayerPed(source)
    local pos = GetEntityCoords(ped)
    local practical = SunsetLicenses.Practical.weapon
    local t = practical.targets[targetIndex]
    if not t then return false end
    local tp = vector3(t.x, t.y, t.z)
    if #(pos - tp) > (practical.zoneRadius or 25.0) then return false end
    session.weaponHits[targetIndex] = true
    local count = 0
    for _ in pairs(session.weaponHits) do count = count + 1 end
    return true, { hits = count, required = practical.targetsRequired or 5 }
end)
