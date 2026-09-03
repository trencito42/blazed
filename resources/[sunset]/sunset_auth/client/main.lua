local authenticated = false

local function openAuth()
    exports.sunset_ui:Show('auth', {})
    exports.sunset_ui:SetFocus(true, true)
end

RegisterNetEvent('sunset:client:sessionReady', function()
    if authenticated then return end
    Wait(300)
    openAuth()
end)

RegisterNetEvent('sunset:client:playerReady', function()
    authenticated = true
    exports.sunset_ui:SetFocus(false, false)
end)

AddEventHandler('sunset:nui:authLogin', function(data)
    local result, err = Sunset.AwaitCallback('sunset:authLogin', data.username, data.password)
    if not result then
        exports.sunset_ui:Notify(err or 'Login failed', 'error')
        return
    end
    authenticated = true
    exports.sunset_ui:Send('authHide', {})
    exports.sunset_ui:SetFocus(false, false)
end)

AddEventHandler('sunset:nui:authRegister', function(data)
    local result, err = Sunset.AwaitCallback('sunset:authRegister', data.username, data.password, data.passwordConfirm)
    if not result then
        exports.sunset_ui:Notify(err or 'Registration failed', 'error')
        return
    end
    exports.sunset_ui:Notify('Account created! Logging in...', 'success')
    authenticated = true
    exports.sunset_ui:Send('authHide', {})
    exports.sunset_ui:SetFocus(false, false)
end)
