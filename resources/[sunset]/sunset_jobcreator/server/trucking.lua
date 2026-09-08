local function truckingCfg(session)
    return (session.definition and session.definition.trucking) or {}
end

local function recoveryRemaining(session, cfg)
    local uses = session.trailerRecoveryUses or 0
    local maxUses = tonumber(cfg.trailerRecoveryMaxUses) or 3
    return maxUses - uses, maxUses
end

local function authorizeRecovery(session, cfg)
    local remaining = recoveryRemaining(session, cfg)
    if remaining <= 0 then return nil, 'Nu mai ai recuperări de remorcă în acest shift.' end

    local now = os.time()
    local cooldown = tonumber(cfg.trailerRecoveryCooldownSec) or 120
    if session.lastTrailerRecoveryAt and now - session.lastTrailerRecoveryAt < cooldown then
        return nil, ('Recuperare remorcă în %d secunde.'):format(
            cooldown - (now - session.lastTrailerRecoveryAt))
    end

    session.lastTrailerRecoveryAt = now
    session.trailerRecoveryUses = (session.trailerRecoveryUses or 0) + 1
    session.trailerDetachSince = nil
    session.trailerWarned = nil
    session.trailerDestroyHandled = nil
    return remaining - 1
end

function JCTrucking_GetState(session, mustBeAttached, maxDistance)
    local truckNet = session.variables and session.variables.vehicle
    local trailerNet = session.variables and session.variables.trailer
    if not truckNet or not trailerNet then return 'none' end

    local truck = NetworkGetEntityFromNetworkId(truckNet)
    local trailer = NetworkGetEntityFromNetworkId(trailerNet)
    if not truck or truck == 0 or not DoesEntityExist(truck) then
        return 'no_truck'
    end
    if not trailer or trailer == 0 or not DoesEntityExist(trailer) then
        return 'destroyed'
    end

    local cfg = truckingCfg(session)
    local model = cfg.trailerModel or 'trailers2'
    if model and GetEntityModel(trailer) ~= joaat(model) then
        return 'wrong_model'
    end

    local dist = #(GetEntityCoords(truck) - GetEntityCoords(trailer))
    if dist > (maxDistance or 45.0) then
        return 'too_far'
    end

    if mustBeAttached then
        -- In FiveM OneSync server, physical vehicle-trailer joints cannot be checked via GetVehicleTrailerVehicle.
        -- When the trailer is within 22m of the truck, or client explicitly confirmed attachment, state is OK.
        if session.trailerClientAttached == true or (session.trailerClientAttached ~= false and dist <= 22.0) then
            return 'ok'
        end
        if dist > 26.0 then
            return 'detached'
        end
        return 'ok'
    end
    return 'ok'
end

RegisterNetEvent('sunset:jobcreator:syncTrailerStatus', function(attached)
    local src = source
    local session = JCSessions_Get and JCSessions_Get(src)
    if session then
        session.trailerClientAttached = (attached == true)
        if attached then
            session.trailerDetachSince = nil
            session.trailerWarned = nil
        end
    end
end)

function JCTrucking_TickSession(source, session)
    if not session.variables or not session.variables.trailer then return end
    local cfg = truckingCfg(session)
    local state = JCTrucking_GetState(session, true, cfg.trailerRecoveryMaxDistance or 35.0)
    local now = os.time()

    if state == 'ok' or state == 'none' then
        session.trailerDetachSince = nil
        session.trailerWarned = nil
        session.trailerDestroyHandled = nil
        return
    end

    if state == 'destroyed' or state == 'wrong_model' then
        if session.trailerDestroyHandled then return end
        local remaining, err = authorizeRecovery(session, cfg)
        if not remaining then
            session.trailerDestroyHandled = true
            JCSessions_Clear(source, err or 'Remorcă distrusă — shift terminat.', true)
            return
        end
        session.trailerDestroyHandled = true
        TriggerClientEvent('sunset:client:notify', source,
            'Remorcă distrusă! Se spawn-ează una nouă — folosește /recovertrailer dacă nu se atașează.', 'error', 8000)
        TriggerClientEvent('sunset:jobcreator:trailerRespawn', source, {
            truckNetId = session.variables.vehicle,
            trailerModel = cfg.trailerModel or 'trailers2',
            remaining = remaining,
            trailerSpawn = session.definition.locations and session.definition.locations.trailer_spawn,
        })
        return
    end

    if state == 'no_truck' then return end

    session.trailerDetachSince = session.trailerDetachSince or now
    local elapsed = now - session.trailerDetachSince
    local grace = tonumber(cfg.trailerGraceSec) or 90
    local remaining = grace - elapsed
    local warnBucket = remaining <= 10 and 10 or (remaining <= 30 and 30 or 60)
    if session.trailerWarned ~= warnBucket then
        session.trailerWarned = warnBucket
        TriggerClientEvent('sunset:client:notify', source,
            ('Reatașează remorca în %d secunde sau shift-ul se termină!'):format(math.max(0, remaining)),
            'warning', 6000)
        TriggerClientEvent('sunset:jobcreator:trailerWarn', source, {
            seconds = math.max(0, remaining),
        })
    end
    if elapsed >= grace then
        JCSessions_Clear(source, 'Remorcă pierdută prea mult timp — shift terminat.', true)
    end
end

exports.sunset_core:RegisterCallback('sunset:jobcreator:recoverTrailer', function(source)
    local session = JCSessions_Get(source)
    if not session or not session.variables.trailer then
        return nil, 'Nu ai un shift trucker activ.'
    end

    local cfg = truckingCfg(session)
    local truckNet = session.variables.vehicle
    local truck = truckNet and NetworkGetEntityFromNetworkId(truckNet) or 0
    local ped = GetPlayerPed(source)
    if not truck or truck == 0 or not DoesEntityExist(truck) then
        return nil, 'Camionul jobului nu există.'
    end
    if not ped or ped == 0 or GetPedInVehicleSeat(truck, -1) ~= ped then
        return nil, 'Stai pe scaunul șoferului în camionul jobului.'
    end
    if GetEntitySpeed(truck) > 1.5 then
        return nil, 'Oprește camionul înainte de recuperare.'
    end

    local state = JCTrucking_GetState(session, false, cfg.trailerRecoveryMaxDistance or 35.0)
    if state == 'destroyed' or state == 'wrong_model' then
        local remaining, err = authorizeRecovery(session, cfg)
        if not remaining then return nil, err end
        return {
            respawn = true,
            truckNetId = truckNet,
            trailerModel = cfg.trailerModel or 'trailers2',
            remaining = remaining,
            trailerSpawn = session.definition.locations and session.definition.locations.trailer_spawn,
        }
    end

    local trailerNet = session.variables.trailer
    local trailer = trailerNet and NetworkGetEntityFromNetworkId(trailerNet) or 0
    if not trailer or trailer == 0 or not DoesEntityExist(trailer) then
        local remaining, err = authorizeRecovery(session, cfg)
        if not remaining then return nil, err end
        return {
            respawn = true,
            truckNetId = truckNet,
            trailerModel = cfg.trailerModel or 'trailers2',
            remaining = remaining,
            trailerSpawn = session.definition.locations and session.definition.locations.trailer_spawn,
        }
    end

    if #(GetEntityCoords(truck) - GetEntityCoords(trailer)) > (cfg.trailerRecoveryMaxDistance or 35.0) then
        return nil, 'Remorca e prea departe — adu camionul mai aproape.'
    end

    local remaining, err = authorizeRecovery(session, cfg)
    if not remaining then return nil, err end
    return {
        truckNetId = truckNet,
        trailerNetId = trailerNet,
        remaining = remaining,
    }
end)

exports.sunset_core:RegisterCallback('sunset:jobcreator:registerTrailer', function(source, trailerNetId)
    local session = JCSessions_Get(source)
    if not session then return nil, 'No active shift.' end
    trailerNetId = tonumber(trailerNetId)
    local trailer = trailerNetId and NetworkGetEntityFromNetworkId(trailerNetId) or 0
    if not trailer or trailer == 0 or not DoesEntityExist(trailer) then
        return nil, 'Remorca nu e validă.'
    end
    local cfg = truckingCfg(session)
    if cfg.trailerModel and GetEntityModel(trailer) ~= joaat(cfg.trailerModel) then
        return nil, 'Model remorcă invalid.'
    end
    session.variables.trailer = trailerNetId
    session.trailerDetachSince = nil
    session.trailerWarned = nil
    session.trailerDestroyHandled = nil
    return true
end)

CreateThread(function()
    while true do
        Wait(3000)
        if not JCSessions_GetAll then goto continue end
        for source, session in pairs(JCSessions_GetAll()) do
            if session.variables and session.variables.trailer then
                JCTrucking_TickSession(source, session)
            end
        end
        ::continue::
    end
end)
