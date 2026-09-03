Detention = Detention or {}

Detention.States = {
    FREE = 'FREE',
    COMPLIANT = 'COMPLIANT',
    CUFFED = 'CUFFED',
    ESCORTED = 'ESCORTED',
    IN_VEHICLE = 'IN_VEHICLE',
    JAILED = 'JAILED',
}

local Cuffed = {}
local Escorted = {}
local HandsUp = {}
local State = {}

local INTERACT_RANGE = 3.5
local VEHICLE_RANGE = 6.0

local function syncDetentionBag(source)
    local state = State[source] or Detention.States.FREE
    Player(source).state:set('sunsetDetention', state, true)
    Player(source).state:set('sunsetCuffed', Cuffed[source] == true, true)
end

function Detention.getState(source)
    return State[source] or Detention.States.FREE
end

function Detention.setState(source, newState)
    State[source] = newState
    syncDetentionBag(source)
end

function Detention.isCuffed(source)
    return Cuffed[source] == true
end

function Detention.setCuffed(source, state)
    if state then
        Cuffed[source] = true
        if State[source] ~= Detention.States.JAILED then
            Detention.setState(source, Detention.States.CUFFED)
        end
    else
        Cuffed[source] = nil
        Escorted[source] = nil
        if State[source] ~= Detention.States.JAILED then
            Detention.setState(source, Detention.States.FREE)
        end
    end
    syncDetentionBag(source)
end

function Detention.clear(source)
    Cuffed[source] = nil
    Escorted[source] = nil
    HandsUp[source] = nil
    if State[source] ~= Detention.States.JAILED then
        State[source] = nil
        syncDetentionBag(source)
    end
end

function Detention.setJailed(source)
    Cuffed[source] = nil
    Escorted[source] = nil
    HandsUp[source] = nil
    Detention.setState(source, Detention.States.JAILED)
end

function Detention.releaseJail(source)
    State[source] = nil
    syncDetentionBag(source)
end

function Detention.getEscort(source)
    return Escorted[source]
end

function Detention.setEscort(target, officer)
    if officer then
        Escorted[target] = officer
        if State[target] ~= Detention.States.JAILED then
            Detention.setState(target, Detention.States.ESCORTED)
        end
    else
        Escorted[target] = nil
        if Cuffed[target] and State[target] ~= Detention.States.JAILED then
            Detention.setState(target, Detention.States.CUFFED)
        end
    end
end

function Detention.setInVehicle(source)
    if State[source] ~= Detention.States.JAILED then
        Detention.setState(source, Detention.States.IN_VEHICLE)
    end
end

function Detention.isHandsUp(source)
    return HandsUp[source] == true
end

local function validateOfficerTarget(source, targetId, perm, range)
    if not FactionCore.hasPerm(source, perm) then
        return nil, 'Not on duty or no permission'
    end
    targetId = tonumber(targetId)
    if not targetId or not FactionCore.isOnline(targetId) then
        return nil, 'Player not found'
    end
    if targetId == source then
        return nil, 'Invalid target'
    end
    if Detention.getState(targetId) == Detention.States.JAILED then
        return nil, 'Suspect is already in custody'
    end
    local officerPos = FactionCore.playerCoords(source)
    local targetPos = FactionCore.playerCoords(targetId)
    if FactionCore.distBetween(officerPos, targetPos) > (range or INTERACT_RANGE) then
        return nil, ('You must be within %dm'):format(math.floor(range or INTERACT_RANGE))
    end
    return targetId
end

exports.sunset_core:RegisterCallback('sunset:detentionCuff', function(source, targetId)
    local target, err = validateOfficerTarget(source, targetId, 'cuff', INTERACT_RANGE)
    if not target then return nil, err end

    Detention.setCuffed(target, true)
    Detention.setEscort(target, nil)
    TriggerClientEvent('sunset:faction:cuff', target)
    TriggerClientEvent('sunset:detention:sync', -1, target, { cuffed = true, state = Detention.States.CUFFED })
    FactionCore.notify(source, 'Suspect restrained', 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:detentionUncuff', function(source, targetId)
    local target, err = validateOfficerTarget(source, targetId, 'uncuff', INTERACT_RANGE)
    if not target then return nil, err end
    if not Detention.isCuffed(target) then return nil, 'Suspect is not restrained' end

    Detention.setCuffed(target, false)
    TriggerClientEvent('sunset:faction:uncuff', target)
    TriggerClientEvent('sunset:detention:sync', -1, target, { cuffed = false, escorted = false, state = Detention.States.FREE })
    FactionCore.notify(source, 'Restraints removed', 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:detentionEscort', function(source, targetId)
    local target, err = validateOfficerTarget(source, targetId, 'escort', INTERACT_RANGE)
    if not target then return nil, err end
    if not Detention.isCuffed(target) then return nil, 'Suspect must be restrained first' end

    if Escorted[target] == source then
        Detention.setEscort(target, nil)
        TriggerClientEvent('sunset:detention:escort', target, nil)
        TriggerClientEvent('sunset:detention:escortOfficer', source, nil)
        FactionCore.notify(source, 'Escort released', 'info')
        return false
    end

    Detention.setEscort(target, source)
    TriggerClientEvent('sunset:detention:escort', target, source)
    TriggerClientEvent('sunset:detention:escortOfficer', source, target)
    FactionCore.notify(source, 'Escorting suspect — use /escort again to release', 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:detentionPutInVehicle', function(source, targetId)
    local target, err = validateOfficerTarget(source, targetId, 'vehicle_detain', VEHICLE_RANGE)
    if not target then return nil, err end
    if not Detention.isCuffed(target) then return nil, 'Suspect must be restrained first' end

    TriggerClientEvent('sunset:detention:putInVehicle', target, source)
    Detention.setEscort(target, nil)
    Detention.setInVehicle(target)
    TriggerClientEvent('sunset:detention:sync', -1, target, { state = Detention.States.IN_VEHICLE })
    FactionCore.notify(source, 'Placing suspect in vehicle', 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:detentionTakeOut', function(source, targetId)
    local target, err = validateOfficerTarget(source, targetId, 'vehicle_detain', VEHICLE_RANGE)
    if not target then return nil, err end
    if not Detention.isCuffed(target) then return nil, 'Suspect must be restrained' end

    TriggerClientEvent('sunset:detention:takeOutVehicle', target)
    if Cuffed[target] then
        Detention.setState(target, Detention.States.CUFFED)
    end
    TriggerClientEvent('sunset:detention:sync', -1, target, { state = Detention.States.CUFFED })
    FactionCore.notify(source, 'Suspect removed from vehicle', 'success')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:detentionFrisk', function(source, targetId)
    local target, err = validateOfficerTarget(source, targetId, 'frisk', INTERACT_RANGE)
    if not target then return nil, err end

    local inv = exports.sunset_inventory:GetInventory(target) or {}
    local summary = {}
    for _, row in ipairs(inv) do
        local def = Sunset.Items[row.item]
        summary[#summary + 1] = {
            item = row.item,
            label = def and def.label or row.item,
            count = row.count,
            confiscatable = Sunset.IsConfiscatableItem(row.item),
        }
    end
    return summary
end)

RegisterNetEvent('sunset:server:handsUp', function(state)
    local src = source
    if Detention.getState(src) == Detention.States.JAILED then return end
    HandsUp[src] = state == true
    if HandsUp[src] and not Cuffed[src] then
        Detention.setState(src, Detention.States.COMPLIANT)
    elseif not HandsUp[src] and not Cuffed[src] then
        Detention.setState(src, Detention.States.FREE)
    end
    TriggerClientEvent('sunset:detention:handsUp', -1, src, HandsUp[src])
    TriggerClientEvent('sunset:detention:sync', -1, src, { state = Detention.getState(src) })
end)

RegisterNetEvent('sunset:server:detentionVehicleState', function(inVehicle)
    local src = source
    if not Cuffed[src] or Detention.getState(src) == Detention.States.JAILED then return end
    if inVehicle then
        Detention.setInVehicle(src)
    elseif Detention.getState(src) == Detention.States.IN_VEHICLE then
        Detention.setState(src, Detention.States.CUFFED)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Detention.clear(src)
    State[src] = nil
    for target, officer in pairs(Escorted) do
        if officer == src or target == src then
            Escorted[target] = nil
        end
    end
end)

function IsCuffed(source)
    return Detention.isCuffed(source)
end
exports('IsCuffed', IsCuffed)
exports('GetDetentionState', function(source) return Detention.getState(source) end)
