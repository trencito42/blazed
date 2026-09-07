local entranceZones = {}

local function requestFibIpls()
    RequestIpl('FIBlobby')
    RequestIpl('FIB_01')
    RequestIpl('atriumglmission')
end

CreateThread(function()
    requestFibIpls()
    Wait(5000)
    requestFibIpls()
end)

local function fadeTeleport(coords4)
    if not coords4 then return end

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    local x, y, z = coords4.x, coords4.y, coords4.z
    local heading = coords4.w or 0.0
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)

    RequestCollisionAtCoord(x, y, z)
    for _ = 1, 20 do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end

    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end
    Wait(250)

    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(500)
end

local function canEnterFib()
    if LocalPlayer.state.sunsetFaction == 'fib' then return true end
    return Sunset.AwaitCallback('sunset:world:canUseFactionLift', 'fib') == true
end

AddEventHandler('sunset:world:registerFactionEntrance', function(factionId, entrance, faction)
    if factionId ~= 'fib' or not entrance or not entrance.from or not entrance.to then return end
    local color = faction and faction.marker or { 20, 20, 20 }
    entranceZones[#entranceZones + 1] = {
        id = factionId .. ':entrance',
        coords = vector3(entrance.from.x, entrance.from.y, entrance.from.z),
        radius = entrance.radius or 3.5,
        hint = entrance.hint or '[E] Enter FIB offices',
        markerColor = color,
        onInteract = function()
            if not canEnterFib() then
                exports.sunset_ui:Notify('FIB members only', 'error')
                return
            end
            fadeTeleport(entrance.to)
        end,
    }
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local anyNearby = false
        for _, zone in ipairs(entranceZones) do
            if #(coords - zone.coords) < 75.0 then
                anyNearby = true
                DrawMarker(
                    1,
                    zone.coords.x, zone.coords.y, zone.coords.z - 0.98,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    1.6, 1.6, 0.8,
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
        local closest, closestDist = nil, 999.0
        for _, zone in ipairs(entranceZones) do
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
