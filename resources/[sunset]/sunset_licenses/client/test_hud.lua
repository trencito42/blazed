local hudVisible = false

local function send(action, data)
    exports.sunset_ui:Send(action, data or {})
end

function ShowLicenseTestHud(data)
    hudVisible = true
    send('licenseTestShow', data)
end

function UpdateLicenseTestHud(data)
    if not hudVisible then return end
    send('licenseTestUpdate', data)
end

function HideLicenseTestHud()
    if not hudVisible then return end
    hudVisible = false
    send('licenseTestHide')
end

function GetTestVehicleState()
    if GetResourceState('sunset_vehicles') ~= 'started' then return nil end
    local ok, state = pcall(function()
        return exports.sunset_vehicles:GetVehicleState()
    end)
    return ok and state or nil
end
