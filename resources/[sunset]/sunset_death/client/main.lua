local downed = false
local dead = false
local active = false
local respawning = false
local bleedoutEndsAt = 0
local stabilized = false

local function getPed()
    return PlayerPedId()
end

local function cfg()
    return Sunset.Death or {}
end

local function doRespawn(coords, bill)
    if respawning then return end
    respawning = true
    dead = false
    downed = false
    stabilized = false
    bleedoutEndsAt = 0

    local x = coords.x or 0.0
    local y = coords.y or 0.0
    local z = coords.z or 0.0
    local heading = coords.w or coords.heading or 0.0

    DoScreenFadeOut(400)
    Wait(500)

    NetworkResurrectLocalPlayer(x, y, z, heading, true, false)
    local ped = getPed()
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)
    ClearPedBloodDamage(ped)
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    SetPlayerControl(PlayerId(), true, 0)

    Wait(400)
    DoScreenFadeIn(800)
    respawning = false

    if bill and bill > 0 then
        exports.sunset_ui:Notify(('Hospital bill: $%s'):format(bill), 'warning')
    end
end

local function doReviveInPlace()
    if respawning then return end
    local ped = getPed()
    local coords = GetEntityCoords(ped)
    downed = false
    stabilized = false
    bleedoutEndsAt = 0
    doRespawn({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }, 0)
end

local function playDownedAnim()
    local ped = getPed()
    local dict = cfg().downedAnimDict or 'combat@damage@writhe'
    local anim = cfg().downedAnim or 'writhe_loop'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return end
        Wait(10)
    end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function enterDownedState()
    if downed or respawning then return end
    downed = true
    dead = true
    stabilized = false
    bleedoutEndsAt = GetGameTimer() + ((cfg().bleedoutSeconds or 300) * 1000)

    local ped = getPed()
    NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 150)
    playDownedAnim()

    exports.sunset_ui:Notify('You are downed. EMS can stabilize and revive you.', 'error', 8000)
    TriggerServerEvent('sunset:death:enteredDowned')
end

AddEventHandler('sunset:client:playerSpawned', function()
    active = true
    dead = false
    downed = false
    stabilized = false
    respawning = false
    bleedoutEndsAt = 0
end)

RegisterNetEvent('sunset:client:respawn', function(pos, bill)
    local spawn = pos or {}
    if not spawn.x then
        local fallback = Sunset.Config.HospitalSpawn or Sunset.Config.DefaultSpawn
        spawn = { x = fallback.x, y = fallback.y, z = fallback.z, w = fallback.w }
    end
    doRespawn(spawn, bill)
end)

RegisterNetEvent('sunset:death:reviveInPlace', function()
    doReviveInPlace()
end)

RegisterNetEvent('sunset:admin:revive', function()
    doReviveInPlace()
end)

RegisterNetEvent('sunset:death:stabilized', function()
    if not downed then return end
    stabilized = true
    bleedoutEndsAt = GetGameTimer() + ((cfg().stabilizeBonusSeconds or 120) * 1000)
    exports.sunset_ui:Notify('Stabilized — bleedout slowed. EMS can still revive you.', 'info', 6000)
end)

RegisterNetEvent('sunset:death:forceHospital', function(pos, bill)
    doRespawn(pos or Sunset.Config.HospitalSpawn, bill or Sunset.Config.HospitalBill)
end)

RegisterCommand('respawn', function()
    if not downed and not dead and not IsEntityDead(getPed()) then
        exports.sunset_ui:Notify('You are not downed', 'error')
        return
    end
    TriggerServerEvent('sunset:server:requestRespawn')
end, false)

CreateThread(function()
    while true do
        if active then
            local ped = getPed()
            if not downed and not respawning and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then
                enterDownedState()
                TriggerServerEvent('sunset:server:playerDied')
            end

            if downed and not respawning then
                DisableAllControlActions(0)
                EnableControlAction(0, 1, true)
                EnableControlAction(0, 2, true)
                EnableControlAction(0, 245, true)

                if bleedoutEndsAt > 0 and GetGameTimer() >= bleedoutEndsAt then
                    TriggerServerEvent('sunset:server:bleedoutExpired')
                end

                if not IsEntityPlayingAnim(ped, cfg().downedAnimDict or 'combat@damage@writhe', cfg().downedAnim or 'writhe_loop', 3) then
                    playDownedAnim()
                end
                Wait(0)
            else
                Wait(400)
            end
        else
            Wait(1000)
        end
    end
end)

exports('IsDead', function() return dead or downed end)
exports('IsDowned', function() return downed end)
exports('IsStabilized', function() return stabilized end)
exports('ClearDead', function()
    dead = false
    downed = false
    stabilized = false
    respawning = false
    bleedoutEndsAt = 0
end)
