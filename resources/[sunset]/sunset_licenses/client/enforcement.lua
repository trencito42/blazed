local blockedVehicle = false

local function notify(msg)
    exports.sunset_ui:Notify(msg, 'error', 6000)
end

local function licensed(licenseType)
    if type(HasLicense) ~= 'function' then return false end
    return HasLicense(licenseType) == true
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local classId = GetVehicleClass(veh)
                local licenseType = SunsetLicenses.vehicleClassForLicense(classId)
                if licenseType then
                    sleep = 0
                    if not licensed(licenseType) then
                        SetVehicleEngineOn(veh, false, true, true)
                        DisableControlAction(0, 71, true)
                        DisableControlAction(0, 72, true)
                        if not blockedVehicle then
                            blockedVehicle = true
                            local def = SunsetLicenses.Types[licenseType]
                            notify(('You need a valid %s. Visit the school on your map.'):format(def and def.label or licenseType))
                        end
                    else
                        blockedVehicle = false
                    end
                end
            end
        else
            blockedVehicle = false
        end
        Wait(sleep)
    end
end)
