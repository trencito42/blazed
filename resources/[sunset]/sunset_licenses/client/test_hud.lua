local hudVisible = false
local helpText = nil

local function send(action, data)
    exports.sunset_ui:Send(action, data or {})
end

function SetLicenseTestHelp(text)
    helpText = text and tostring(text) or nil
end

function ShowLicenseTestHud(data)
    hudVisible = true
    if data and data.message then
        SetLicenseTestHelp(data.message)
    end
    send('licenseTestShow', data)
end

function UpdateLicenseTestHud(data)
    if not hudVisible then
        hudVisible = true
    end
    if data and data.message then
        SetLicenseTestHelp(data.message)
    end
    send('licenseTestUpdate', data)
end

function HideLicenseTestHud()
    if not hudVisible and not helpText then return end
    hudVisible = false
    helpText = nil
    send('licenseTestHide')
end

function GetTestVehicleState()
    if GetResourceState('sunset_vehicles') ~= 'started' then return nil end
    local ok, state = pcall(function()
        return exports.sunset_vehicles:GetVehicleState()
    end)
    return ok and state or nil
end

CreateThread(function()
    while true do
        if helpText then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(helpText)
            EndTextCommandDisplayHelp(0, false, true, -1)
            Wait(0)
        else
            Wait(250)
        end
    end
end)
