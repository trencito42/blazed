local dead = false
local active = false

AddEventHandler('sunset:client:playerSpawned', function()
    active = true
    dead = false
end)

RegisterNetEvent('sunset:client:respawn', function(pos, bill)
    dead = false
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(600)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.w or 0.0, true, false)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.w or 0.0)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)

    Wait(800)
    DoScreenFadeIn(1000)

    if bill and bill > 0 then
        exports.sunset_ui:Notify(('Hospital bill: $%s'):format(bill), 'warning')
    end
end)

CreateThread(function()
    while true do
        if active and not dead then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
                dead = true
                TriggerServerEvent('sunset:server:playerDied')
                exports.sunset_ui:Notify('You died. Respawning...', 'error', Sunset.Config.RespawnDelay)
                Wait(Sunset.Config.RespawnDelay)
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)
