local spawned = false
local spawning = false

local function validCoordinate(value)
    value = tonumber(value)
    return value and value == value and math.abs(value) < 10000.0
end

local function resolvePosition(char, spawnPosition)
    local pos = type(spawnPosition) == 'table' and spawnPosition or (char.position or {})
    if not validCoordinate(pos.x) or not validCoordinate(pos.y) or not validCoordinate(pos.z) then
        pos = Sunset.Config.DefaultSpawn
    end
    return {
        x = tonumber(pos.x) or Sunset.Config.DefaultSpawn.x,
        y = tonumber(pos.y) or Sunset.Config.DefaultSpawn.y,
        z = tonumber(pos.z) or Sunset.Config.DefaultSpawn.z,
        w = tonumber(pos.w) or Sunset.Config.DefaultSpawn.w,
    }
end

local function streamSpawnArea(ped, pos)
    SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    NewLoadSceneStartSphere(pos.x, pos.y, pos.z, 80.0, 0)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z + 0.15, false, false, false)
    SetEntityHeading(ped, pos.w)

    local deadline = GetGameTimer() + 12000
    local loaded = false
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        if HasCollisionLoadedAroundEntity(ped) and not IsEntityWaitingForWorldCollision(ped) then
            loaded = true
            break
        end
        Wait(50)
    end

    NewLoadSceneStop()
    ClearFocus()
    return loaded
end

local function defaultPosition()
    return resolvePosition({}, Sunset.Config.DefaultSpawn)
end

local function applyAppearance(ped, appearance)
    if not appearance or not next(appearance) then return end
end

local function spawnPlayer(char, spawnPosition)
    spawning = true

    local pos = resolvePosition(char, spawnPosition)

    DoScreenFadeOut(500)
    Wait(600)

    local model = char.gender == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    SetEntityCollision(ped, true, true)

    if char.appearance and next(char.appearance) then
        if GetResourceState('sunset_appearance') == 'started' then
            exports.sunset_appearance:ApplyAppearance(ped, char.appearance, char.gender)
        end
    end

    FreezeEntityPosition(ped, true)

    local collisionLoaded = streamSpawnArea(ped, pos)
    if not collisionLoaded then
        local fallback = defaultPosition()
        print(('[SunsetSpawn] Collision timed out at %.2f %.2f %.2f; using default spawn.'):format(
            pos.x, pos.y, pos.z))
        pos = fallback
        collisionLoaded = streamSpawnArea(ped, pos)
    end

    TriggerServerEvent('sunset:server:characterSpawned', char.id)

    exports.sunset_ui:Send('enterGameplay', { duration = 850 })
    Wait(200)
    DoScreenFadeIn(1500)
    Wait(1500)

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)

    -- Streaming can still be evicted at the exact hand-off on slow clients.
    -- Recover before a bad position can be persisted as the next last location.
    local safePos = pos
    CreateThread(function()
        local deadline = GetGameTimer() + 8000
        while GetGameTimer() < deadline do
            Wait(250)
            local current = GetEntityCoords(ped)
            if IsEntityWaitingForWorldCollision(ped) or current.z < safePos.z - 8.0 then
                local fallback = defaultPosition()
                DoScreenFadeOut(200)
                Wait(250)
                FreezeEntityPosition(ped, true)
                streamSpawnArea(ped, fallback)
                SetEntityCoordsNoOffset(ped, fallback.x, fallback.y, fallback.z + 0.15, false, false, false)
                SetEntityHeading(ped, fallback.w)
                FreezeEntityPosition(ped, false)
                DoScreenFadeIn(500)
                exports.sunset_ui:Notify('Your saved location was not safe, so you were moved to the default spawn.', 'warning', 7000)
                return
            end
        end
    end)

    if not collisionLoaded then
        exports.sunset_ui:Notify('The map loaded slowly. If the world is missing, reconnect once.', 'warning', 7000)
    end
    spawned = true
    spawning = false

    TriggerEvent('sunset:client:characterFlowComplete')
    TriggerEvent('sunset:client:playerSpawned', char)
end

AddEventHandler('sunset:client:spawnCharacter', function(char, spawnPosition)
    CreateThread(function()
        spawnPlayer(char, spawnPosition)
    end)
end)

local function resumeIfAlreadySpawned()
    local char = exports.sunset_core:GetCharacter()
    if char and char.id then
        spawned = true
        local ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        TriggerEvent('sunset:client:playerSpawned', char)
        return true
    end
    return false
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if resumeIfAlreadySpawned() then return end

    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
end)

CreateThread(function()
    while not spawned do
        if spawning or (GetResourceState('sunset_appearance') == 'started' and exports.sunset_appearance:IsEditing()) then
            Wait(200)
        else
            local ped = PlayerPedId()
            SetEntityVisible(ped, false, false)
            FreezeEntityPosition(ped, true)
            Wait(500)
        end
    end
end)
