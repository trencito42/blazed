local dead = false
local active = false
local respawning = false

local function getPed()
    return PlayerPedId()
end

local function doRespawn(coords, bill)
    if respawning then return end
    respawning = true
    dead = false

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
    doRespawn({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }, 0)
end

AddEventHandler('sunset:client:playerSpawned', function()
    active = true
    dead = false
    respawning = false
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

RegisterCommand('respawn', function()
    if not dead and not IsEntityDead(getPed()) then
        exports.sunset_ui:Notify('You are not dead', 'error')
        return
    end
    TriggerServerEvent('sunset:server:requestRespawn')
end, false)

CreateThread(function()
    while true do
        if active then
            local ped = getPed()
            if not dead and not respawning and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then
                dead = true
                TriggerServerEvent('sunset:server:playerDied')

                local delay = Sunset.Config.RespawnDelay or 5000
                exports.sunset_ui:Notify('You died. Respawning at hospital...', 'error', delay + 2000)

                SetTimeout(delay + 4000, function()
                    if dead and not respawning then
                        local fallback = Sunset.Config.HospitalSpawn or Sunset.Config.DefaultSpawn
                        doRespawn({ x = fallback.x, y = fallback.y, z = fallback.z, w = fallback.w }, 0)
                        exports.sunset_ui:Notify('Respawned at hospital', 'info')
                    end
                end)
            end

            if dead and not respawning then
                DisableAllControlActions(0)
                EnableControlAction(0, 1, true)
                EnableControlAction(0, 2, true)
                Wait(0)
            else
                Wait(400)
            end
        else
            Wait(1000)
        end
    end
end)

exports('IsDead', function() return dead end)
exports('ClearDead', function()
    dead = false
    respawning = false
end)
