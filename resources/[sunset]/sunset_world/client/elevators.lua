local elevatorZones = {}

local function fadeTeleport(coords4, allowVehicle)
    if not coords4 then return end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local driving = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

    if driving and not allowVehicle then
        exports.sunset_ui:Notify('Exit the vehicle before using the lift', 'error')
        return
    end

    DoScreenFadeOut(400)
    Wait(500)

    local x, y, z = coords4.x, coords4.y, coords4.z
    local heading = coords4.w or 0.0
    RequestCollisionAtCoord(x, y, z)

    if driving and allowVehicle then
        SetEntityCoords(veh, x, y, z, false, false, false, false)
        SetEntityHeading(veh, heading)
        SetPedIntoVehicle(ped, veh, -1)
        SetVehicleOnGroundProperly(veh)
    else
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, heading)
    end

    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(10)
    end

    DoScreenFadeIn(500)
end

local function canUseFactionElevator(factionId)
    local char = exports.sunset_core:GetCharacter()
    if not char then return false end
    return Sunset.GetCharacterFaction(char) == factionId
end

AddEventHandler('sunset:world:registerElevator', function(factionId, lift, faction)
    if not lift or not lift.lobby or not lift.garage then return end

    local color = faction and faction.marker or { 200, 200, 200 }
    local label = lift.label or ((faction and faction.label) or factionId) .. ' Lift'

    elevatorZones[#elevatorZones + 1] = {
        id = factionId .. ':lobby',
        coords = vector3(lift.lobby.x, lift.lobby.y, lift.lobby.z),
        radius = lift.radius or 1.8,
        hint = ('[E] %s — Motor Pool'):format(label),
        markerColor = color,
        factionId = factionId,
        onInteract = function()
            if not canUseFactionElevator(factionId) then
                exports.sunset_ui:Notify('Members only', 'error')
                return
            end
            fadeTeleport(lift.garage, false)
        end,
    }

    elevatorZones[#elevatorZones + 1] = {
        id = factionId .. ':garage',
        coords = vector3(lift.garage.x, lift.garage.y, lift.garage.z),
        radius = lift.garageRadius or 2.5,
        hint = ('[E] %s — Lobby'):format(label),
        markerColor = color,
        factionId = factionId,
        onInteract = function()
            if not canUseFactionElevator(factionId) then
                exports.sunset_ui:Notify('Members only', 'error')
                return
            end
            fadeTeleport(lift.lobby, false)
        end,
    }
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local anyNearby = false

        for _, zone in ipairs(elevatorZones) do
            if #(coords - zone.coords) < 75.0 then
                anyNearby = true
                DrawMarker(
                    1,
                    zone.coords.x, zone.coords.y, zone.coords.z - 0.98,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    1.4, 1.4, 0.75,
                    zone.markerColor[1], zone.markerColor[2], zone.markerColor[3], 185,
                    false, false, 2, false, nil, nil, false
                )
            end
        end

        Wait(anyNearby and 0 or 500)
    end
end)

CreateThread(function()
    local activeId = nil

    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local closest = nil
        local closestDist = 999.0

        for _, zone in ipairs(elevatorZones) do
            local dist = #(coords - zone.coords)
            if dist < zone.radius and dist < closestDist then
                closest = zone
                closestDist = dist
            end
        end

        if closest then
            if activeId ~= closest.id then
                activeId = closest.id
                if GetResourceState('ox_lib') == 'started' then
                    exports.ox_lib:showTextUI(closest.hint, { position = 'bottom-center' })
                end
            end
            if IsControlJustReleased(0, 38) and not IsNuiFocused() then
                closest.onInteract()
            end
            Wait(0)
        else
            if activeId then
                activeId = nil
                if GetResourceState('ox_lib') == 'started' then
                    exports.ox_lib:hideTextUI()
                end
            end
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:hideTextUI()
    end
end)
