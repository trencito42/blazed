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

local function hasCoordsPerm()
    local need = SunsetAdmin.Commands.coords or 2
    return adminLevel >= need
end

local function coordChat(line)
    exports.sunset_ui:Send('chatMessage', { id = 0, name = 'COORDS', message = line, time = '' })
end

local currentPosition

local function showPosition(args)
    if not hasCoordsPerm() then
        exports.sunset_ui:Notify('No permission', 'error')
        return
    end

    local x, y, z, heading = currentPosition()
    local useV4 = args and args[1] and string.lower(tostring(args[1])) == 'v4'

    if useV4 then
        local line = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(x, y, z, heading)
        print('[Sunset] ' .. line)
        coordChat(line)
    else
        local v3 = ('vector3(%.2f, %.2f, %.2f)'):format(x, y, z)
        local raw = ('%.2f, %.2f, %.2f, %.2f'):format(x, y, z, heading)
        print('[Sunset] ' .. v3)
        print('[Sunset] ' .. raw)
        coordChat(v3)
        coordChat(raw)
    end

    exports.sunset_ui:Notify('Position in chat and F8 (use /coords v4 for vector4)', 'info')
end

RegisterNetEvent('sunset:admin:copyCoords', function(args)
    showPosition(args or {})
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

local function resetVehicleSpeed(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleEnginePowerMultiplier(veh, 1.0)
    SetVehicleEngineTorqueMultiplier(veh, 1.0)
    SetVehicleCheatPowerIncrease(veh, 0.0)
    ModifyVehicleTopSpeed(veh, 0.0)
    SetVehicleMaxSpeed(veh, 0.0)
end

local function applyVehicleSpeedBoost(veh, mult)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if mult <= 1.01 then
        resetVehicleSpeed(veh)
        return
    end

    SetVehicleMaxSpeed(veh, 0.0)
    -- Power multiplier is additive in GTA; small values like 2.5 have almost no effect.
    SetVehicleEnginePowerMultiplier(veh, (mult - 1.0) * 20.0)
    SetVehicleEngineTorqueMultiplier(veh, mult)
    SetVehicleCheatPowerIncrease(veh, (mult - 1.0) * 2.0)
    ModifyVehicleTopSpeed(veh, mult - 1.0)
end

local function setSpeedMultiplier(mult)
    mult = tonumber(mult) or 1.0
    mult = math.max(0.5, math.min(mult, 10.0))
    speedMultiplier = mult

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        applyVehicleSpeedBoost(GetVehiclePedIsIn(ped, false), mult)
    end

    if mult <= 1.01 then
        exports.sunset_ui:Notify('Speed boost disabled', 'info')
    else
        exports.sunset_ui:Notify(('Speed boost: %.1fx'):format(mult), 'success')
    end
end

RegisterNetEvent('sunset:admin:setSpeed', setSpeedMultiplier)

-- GTA resets vehicle multipliers every frame while driving; re-apply while boosted.
CreateThread(function()
    while true do
        if speedMultiplier > 1.01 then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if GetPedInVehicleSeat(veh, -1) == ped then
                    applyVehicleSpeedBoost(veh, speedMultiplier)
                    Wait(0)
                else
                    Wait(250)
                end
            else
                Wait(500)
            end
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(200)
        local ped = PlayerPedId()
        local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or 0
        if veh ~= lastVeh then
            if lastVeh ~= 0 and DoesEntityExist(lastVeh) then
                resetVehicleSpeed(lastVeh)
            end
            if veh ~= 0 and speedMultiplier > 1.01 then
                applyVehicleSpeedBoost(veh, speedMultiplier)
            end
            lastVeh = veh
        end
    end
end)

currentPosition = function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return c.x, c.y, c.z, GetEntityHeading(ped)
end

local function registerCoordsCommand(name)
    RegisterCommand(name, function(_, args)
        showPosition(args)
    end, false)
end

registerCoordsCommand('coords')
registerCoordsCommand('getpos')
registerCoordsCommand('pos')

RegisterCommand('setcp', function(_, args)
    local name = table.concat(args, ' ')
    local x, y, z, heading = currentPosition()
    TriggerServerEvent('sunset:admin:setcp', name, x, y, z, heading)
end, false)

RegisterCommand('delcp', function(_, args)
    TriggerServerEvent('sunset:admin:delcp', table.concat(args, ' '))
end, false)

RegisterCommand('gotocp', function(_, args)
    TriggerServerEvent('sunset:admin:gotocp', table.concat(args, ' '))
end, false)

RegisterCommand('gotoloc', function(_, args)
    TriggerServerEvent('sunset:admin:gotoloc', table.concat(args, ' '))
end, false)

RegisterCommand('speed', function(_, args)
    TriggerServerEvent('sunset:admin:requestSpeed', args[1])
end, false)

CreateThread(function()
    Wait(4000)
    TriggerEvent('chat:addSuggestion', '/coords', 'Show your position for configs (admin)', {
        { name = 'v4', help = 'Optional — output vector4 with heading' },
    })
    TriggerEvent('chat:addSuggestion', '/getpos', 'Alias for /coords (admin)')
    TriggerEvent('chat:addSuggestion', '/pos', 'Alias for /coords (admin)')
    TriggerEvent('chat:addSuggestion', '/setcp', 'Save your current position as a named checkpoint (admin)', {
        { name = 'name', help = 'e.g. staging, event_spawn' },
    })
    TriggerEvent('chat:addSuggestion', '/delcp', 'Delete a saved checkpoint (admin)', {
        { name = 'name', help = 'Checkpoint name saved with /setcp' },
    })
    TriggerEvent('chat:addSuggestion', '/gotocp', 'Teleport to a saved admin checkpoint', {
        { name = 'name', help = 'Omit or use list to show saved checkpoints' },
    })
    TriggerEvent('chat:addSuggestion', '/gotoloc', 'Teleport to a predefined world location (admin)', {
        { name = 'id or name', help = 'e.g. hq_medic, hospital — omit or use list' },
    })
    TriggerEvent('chat:addSuggestion', '/speed', 'Vehicle speed multiplier while driving (admin)', {
        { name = 'multiplier', help = 'e.g. 2.5 — omit or use off/1 to reset' },
    })
end)
