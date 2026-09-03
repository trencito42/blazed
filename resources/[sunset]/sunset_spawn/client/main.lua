local spawned = false

local function applyAppearance(ped, appearance)
    if not appearance or not next(appearance) then return end
end

local function spawnPlayer(char)
    local pos = char.position or {}
    local x = pos.x or Sunset.Config.DefaultSpawn.x
    local y = pos.y or Sunset.Config.DefaultSpawn.y
    local z = pos.z or Sunset.Config.DefaultSpawn.z
    local w = pos.w or Sunset.Config.DefaultSpawn.w

    DoScreenFadeOut(500)
    Wait(600)

    local model = char.gender == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    applyAppearance(ped, char.appearance)

    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, w)
    FreezeEntityPosition(ped, true)

    TriggerServerEvent('sunset:server:setCharacter', char)

    Wait(1000)
    DoScreenFadeIn(1500)
    Wait(1500)

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    spawned = true

    TriggerEvent('sunset:client:characterFlowComplete')
    TriggerEvent('sunset:client:playerSpawned', char)
end

AddEventHandler('sunset:client:spawnCharacter', function(char)
    spawnPlayer(char)
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
        if GetResourceState('sunset_appearance') == 'started' and exports.sunset_appearance:IsEditing() then
            Wait(200)
        else
            local ped = PlayerPedId()
            SetEntityVisible(ped, false, false)
            FreezeEntityPosition(ped, true)
            Wait(500)
        end
    end
end)
