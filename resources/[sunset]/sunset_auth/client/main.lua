local authenticated = false
local sessionLicense = nil

local function authPayload()
    local store = SunsetAuthAccounts.load(sessionLicense)
    return {
        accounts = SunsetAuthAccounts.publicList(store),
        quickLogin = store.quickLogin,
    }
end

local function pushAuthAccounts()
    exports.sunset_ui:Send('authAccounts', authPayload())
end

local function openAuth()
    exports.sunset_ui:Show('auth', authPayload())
    exports.sunset_ui:SetFocus(true, true)
end

local function persistLogin(username, password, rememberQuickLogin)
    SunsetAuthAccounts.upsert(sessionLicense, username, password, rememberQuickLogin == true)
end

local function performLogin(username, password, rememberQuickLogin)
    local result, err = Sunset.AwaitCallback('sunset:authLogin', username, password)
    if not result then
        exports.sunset_ui:Send('authError', { message = err })
        exports.sunset_ui:Notify(err or 'Login failed', 'error')
        return false
    end
    persistLogin(username, password, rememberQuickLogin)
    authenticated = true
    exports.sunset_ui:Send('authHide', {})
    TriggerEvent('sunset:client:authenticationComplete')
    return true
end

RegisterNetEvent('sunset:client:sessionReady', function(data)
    sessionLicense = data and data.license
    if authenticated then return end
    Wait(300)
    openAuth()
end)

RegisterNetEvent('sunset:client:playerReady', function()
    authenticated = true
    exports.sunset_ui:SetFocus(false, false)
end)

AddEventHandler('sunset:nui:authLogin', function(data)
    local remember = data.rememberQuickLogin == true
    SunsetAuthAccounts.setQuickLogin(sessionLicense, remember)

    if not performLogin(data.username, data.password, remember) then
        return
    end
end)

AddEventHandler('sunset:nui:authRegister', function(data)
    local remember = data.rememberQuickLogin == true
    SunsetAuthAccounts.setQuickLogin(sessionLicense, remember)

    local result, err = Sunset.AwaitCallback('sunset:authRegister', data.username, data.password, data.passwordConfirm)
    if not result then
        exports.sunset_ui:Send('authError', { message = err })
        exports.sunset_ui:Notify(err or 'Registration failed', 'error')
        return
    end
    persistLogin(data.username, data.password, remember)
    exports.sunset_ui:Notify('Account created! Logging in...', 'success')
    authenticated = true
    exports.sunset_ui:Send('authHide', {})
    TriggerEvent('sunset:client:authenticationComplete')
end)

AddEventHandler('sunset:nui:authPickAccount', function(data)
    local username = tostring(data and data.username or '')
    if username == '' then return end

    local store = SunsetAuthAccounts.load(sessionLicense)
    local row = SunsetAuthAccounts.find(store, username)
    if not row then
        pushAuthAccounts()
        return
    end

    if store.quickLogin and type(row.password) == 'string' and row.password ~= '' then
        exports.sunset_ui:Send('authQuickLoginStart', { username = row.username })
        if performLogin(row.username, row.password, true) then
            return
        end
    end

    exports.sunset_ui:Send('authAccountFill', {
        username = row.username,
        password = row.password or '',
    })
end)

AddEventHandler('sunset:nui:authRemoveAccount', function(data)
    local username = tostring(data and data.username or '')
    if username == '' then return end
    SunsetAuthAccounts.remove(sessionLicense, username)
    pushAuthAccounts()
end)

AddEventHandler('sunset:nui:authSetQuickLogin', function(data)
    SunsetAuthAccounts.setQuickLogin(sessionLicense, data and data.enabled == true)
end)
