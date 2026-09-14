-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Vehicle Impound (client/main.lua)
--  Impound lot marker, recovery UI, police impound command.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetImpound.Config
local impoundOpen = false

-- ── Impound lot marker + recovery ──
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 500

        if #(coords - Cfg.lot) < 5.0 then
            sleep = 0
            DrawMarker(1, Cfg.lot.x, Cfg.lot.y, Cfg.lot.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                2.0, 2.0, 1.0,
                255, 200, 0, 100,
                false, false, 2, false, nil, nil, false)

            if IsControlJustReleased(0, 38) and not impoundOpen then
                openImpoundUI()
            end
        end

        Wait(sleep)
    end
end)

local function openImpoundUI()
    if impoundOpen then return end
    impoundOpen = true
    local list, err = Sunset.AwaitCallback('sunset:impound:list')
    if not list then
        exports.sunset_ui:Notify(err or 'Could not load impound list.', 'error')
        impoundOpen = false
        return
    end
    exports.sunset_ui:Send('impoundShow', { vehicles = list })
    exports.sunset_ui:SetFocus(true, true, false, 'impound')
end

local function closeImpoundUI()
    if not impoundOpen then return end
    impoundOpen = false
    exports.sunset_ui:Send('impoundHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'impound')
end

-- ── Police impound command ──
RegisterCommand('impound', function(source, args)
    local reasonId = args[1] or 'other'
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        -- Try closest vehicle
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
    end
    if veh == 0 or not DoesEntityExist(veh) then
        return exports.sunset_ui:Notify('No vehicle nearby to impound.', 'error')
    end

    local plate = GetVehicleNumberPlateText(veh)
    local vehicleId = nil
    pcall(function()
        vehicleId = Sunset.AwaitCallback('sunset:vehicles:getVehicleIdByPlate', plate)
    end)
    if not vehicleId then
        return exports.sunset_ui:Notify('Could not identify this vehicle.', 'error')
    end

    local ok, err = Sunset.AwaitCallback('sunset:impound:confiscate', vehicleId, reasonId)
    if not ok then
        return exports.sunset_ui:Notify(err or 'Could not impound this vehicle.', 'error')
    end

    -- Delete the entity locally
    if DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
end, false)

-- ── NUI callbacks ──
AddEventHandler('sunset:nui:impoundClose', function()
    closeImpoundUI()
end)

AddEventHandler('sunset:nui:impoundRecover', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:impound:recover', tonumber(data.impoundId))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not recover the vehicle.', 'error')
            return
        end
        exports.sunset_ui:Notify(('Vehicle %s recovered for $%s!'):format(res.plate or 'Unknown', res.fee or 0), 'success', 8000)
        -- Refresh the list
        local list = Sunset.AwaitCallback('sunset:impound:list')
        if list then
            exports.sunset_ui:Send('impoundUpdate', { vehicles = list })
        end
    end)
end)

-- ESC closes impound
CreateThread(function()
    while true do
        if impoundOpen and IsPauseMenuActive() then
            closeImpoundUI()
        end
        Wait(impoundOpen and 50 or 250)
    end
end)

-- Export for server-side proximity check
exports('IsNearLot', function(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    return #(coords - Cfg.lot) < 10.0
end)

exports('IsImpoundOpen', function() return impoundOpen end)
