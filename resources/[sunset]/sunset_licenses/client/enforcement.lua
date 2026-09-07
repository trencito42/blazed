local blockedVehicle = false

local function notify(msg)
    exports.sunset_ui:Notify(msg, 'error', 6000)
end

local function isOnDuty()
    if GetResourceState('sunset_factions') ~= 'started' then return false end
    local ok, onDuty = pcall(function() return exports.sunset_factions:IsOnDuty() end)
    return ok and onDuty == true
end

local function inTest()
    if GetResourceState('sunset_licenses') ~= 'started' then return false end
    local ok, active = pcall(function() return exports.sunset_licenses:IsInLicenseTest() end)
    if ok and active then return true end
    ok, active = pcall(function() return exports.sunset_licenses:IsInLocalTest() end)
    return ok and active == true
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) and not isOnDuty() and not inTest() then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local classId = GetVehicleClass(veh)
                local licenseType = SunsetLicenses.vehicleClassForLicense(classId)
                if licenseType then
                    sleep = 0
                    local ok, reason = pcall(function()
                        return exports.sunset_licenses:HasLicense(licenseType)
                    end)
                    if not ok or reason == false then
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
