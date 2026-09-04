local adminLevel = 0
local noclip = false
local godmode = false

RegisterNetEvent('sunset:client:setAdmin', function(level)
    adminLevel = level or 0
end)

RegisterNetEvent('sunset:admin:teleport', function(x, y, z)
    local ped = PlayerPedId()
    SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
end)

RegisterNetEvent('sunset:admin:spawnVehicle', function(model)
    local hash = joaat(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 100 do Wait(10) timeout = timeout + 1 end
    if not HasModelLoaded(hash) then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(hash)
    exports.sunset_vehicles:SetFuelLevel(veh, 100.0)
end)

RegisterNetEvent('sunset:admin:deleteVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end
    if veh ~= 0 then DeleteEntity(veh) end
end)

RegisterNetEvent('sunset:admin:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('sunset:admin:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('sunset:admin:toggleNoclip', function()
    noclip = not noclip
    exports.sunset_ui:Notify(noclip and 'Noclip ON' or 'Noclip OFF', 'info')
end)

RegisterNetEvent('sunset:admin:toggleGod', function()
    godmode = not godmode
    SetEntityInvincible(PlayerPedId(), godmode)
    exports.sunset_ui:Notify(godmode and 'Godmode ON' or 'Godmode OFF', 'info')
end)

RegisterNetEvent('sunset:admin:copyCoords', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local str = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h)
    print(str)
    exports.sunset_ui:Notify('Coords printed to F8', 'info')
end)

-- Noclip thread
CreateThread(function()
    while true do
        if noclip then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local speed = 1.5
            if IsControlPressed(0, 21) then speed = 4.0 end

            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
            SetEntityCollision(ped, false, false)
            FreezeEntityPosition(ped, true)

            if IsControlPressed(0, 32) then -- W
                local rad = math.rad(heading)
                coords = vector3(coords.x - math.sin(rad) * speed, coords.y + math.cos(rad) * speed, coords.z)
            end
            if IsControlPressed(0, 33) then -- S
                local rad = math.rad(heading)
                coords = vector3(coords.x + math.sin(rad) * speed, coords.y - math.cos(rad) * speed, coords.z)
            end
            if IsControlPressed(0, 44) then coords = vector3(coords.x, coords.y, coords.z + speed) end -- Q up
            if IsControlPressed(0, 38) then coords = vector3(coords.x, coords.y, coords.z - speed) end -- E down

            SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
            Wait(0)
        else
            local ped = PlayerPedId()
            SetEntityCollision(ped, true, true)
            FreezeEntityPosition(ped, false)
            Wait(500)
        end
    end
end)

exports('GetAdminLevel', function() return adminLevel end)

local speedMultiplier = 1.0

local function applyVehicleSpeed(mult)
    speedMultiplier = mult
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if mult <= 1.01 then
        SetVehicleEnginePowerMultiplier(veh, 1.0)
        SetVehicleCheatPowerIncrease(veh, 0.0)
    else
        SetVehicleEnginePowerMultiplier(veh, mult)
        SetVehicleCheatPowerIncrease(veh, mult)
    end
end

RegisterNetEvent('sunset:admin:setSpeed', function(mult)
    mult = tonumber(mult) or 1.0
    applyVehicleSpeed(mult)
    if mult > 1.01 and IsPedInAnyVehicle(PlayerPedId(), false) then
        exports.sunset_ui:Notify(('Speed boost: %.1fx'):format(mult), 'info')
    end
end)

CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(400)
        local ped = PlayerPedId()
        local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or 0
        if veh ~= lastVeh then
            if lastVeh ~= 0 and DoesEntityExist(lastVeh) then
                SetVehicleEnginePowerMultiplier(lastVeh, 1.0)
                SetVehicleCheatPowerIncrease(lastVeh, 0.0)
            end
            if veh ~= 0 and speedMultiplier > 1.01 then
                applyVehicleSpeed(speedMultiplier)
            end
            lastVeh = veh
        elseif veh ~= 0 and speedMultiplier > 1.01 then
            SetVehicleEnginePowerMultiplier(veh, speedMultiplier)
            SetVehicleCheatPowerIncrease(veh, speedMultiplier)
        end
    end
end)

RegisterCommand('gotocp', function(_, args)
    TriggerServerEvent('sunset:admin:gotocp', table.concat(args, ' '))
end, false)

RegisterCommand('speed', function(_, args)
    TriggerServerEvent('sunset:admin:requestSpeed', args[1])
end, false)

CreateThread(function()
    Wait(4000)
    TriggerEvent('chat:addSuggestion', '/gotocp', 'Teleport to a checkpoint (admin)', {
        { name = 'id or name', help = 'e.g. hq_medic, pillbox, mrpd' },
    })
    TriggerEvent('chat:addSuggestion', '/speed', 'Vehicle speed multiplier while driving (admin)', {
        { name = 'multiplier', help = 'e.g. 2.5 — omit or use off/1 to reset' },
    })
end)
