local authenticated = false
local sessionLicense = nil
local pendingAuth = nil

local function isEnabled(value)
    if value == true or value == 1 then return true end
    if type(value) == 'string' then
        local normalized = string.lower(value)
        return normalized == 'true' or normalized == '1' or normalized == 'on'
    end
    return false
end

local function activeLicense()
    if type(sessionLicense) == 'string' and sessionLicense ~= '' then
        return sessionLicense
    end
    return nil
end

local function authPayload()
    local store = SunsetAuthAccounts.load(activeLicense())
    return {
        accounts = SunsetAuthAccounts.publicList(store),
        quickLogin = store.quickLogin == true,
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
    local license = activeLicense()
    if not license then return end
    SunsetAuthAccounts.upsert(license, username, password, isEnabled(rememberQuickLogin))
end

local function completeAuthentication(username, password, rememberQuickLogin)
    if password and username then
        persistLogin(username, password, rememberQuickLogin)
    end
    pendingAuth = nil
    authenticated = true
    exports.sunset_ui:Send('authHide', {})
    TriggerEvent('sunset:client:authenticationComplete')
end

local function promptEmailSync(username, password, rememberQuickLogin)
    pendingAuth = {
        username = username,
        password = password,
        rememberQuickLogin = isEnabled(rememberQuickLogin),
    }
    exports.sunset_ui:Send('authNeedsEmail', {
        username = username,
    })
end

local function handleAuthResult(result, username, password, rememberQuickLogin)
    if result and result.needsEmail then
        promptEmailSync(result.username or username, password, rememberQuickLogin)
        return false
    end
    completeAuthentication(username, password, rememberQuickLogin)
    return true
end

local function performLogin(username, password, rememberQuickLogin)
    local result, err = Sunset.AwaitCallback('sunset:authLogin', username, password)
    if not result then
        exports.sunset_ui:Send('authError', { message = err })
        exports.sunset_ui:Notify(err or 'Login failed', 'error')
        return false
    end
    if result.needsEmail then
        exports.sunset_ui:Send('authError', {})
        promptEmailSync(result.username or username, password, rememberQuickLogin)
        return false
    end
    completeAuthentication(username, password, rememberQuickLogin)
    return true
end

local function tryAutoQuickLogin()
    local license = activeLicense()
    if not license then return false end

    local store = SunsetAuthAccounts.load(license)
    if store.quickLogin ~= true then return false end

    local row = SunsetAuthAccounts.mostRecent(store)
    if not row or type(row.password) ~= 'string' or row.password == '' then
        return false
    end

    exports.sunset_ui:Show('auth', authPayload())
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('authQuickLoginStart', { username = row.username })
    return performLogin(row.username, row.password, true)
end

RegisterNetEvent('sunset:client:sessionReady', function(data)
    sessionLicense = data and data.license
    if authenticated then return end
    Wait(300)
    if tryAutoQuickLogin() then return end
    openAuth()
end)

RegisterNetEvent('sunset:client:playerReady', function()
    authenticated = true
    exports.sunset_ui:SetFocus(false, false)
end)

AddEventHandler('sunset:nui:authLogin', function(data)
    local remember = isEnabled(data and data.rememberQuickLogin)
    local license = activeLicense()
    if license then
        SunsetAuthAccounts.setQuickLogin(license, remember)
    end
    performLogin(data.username, data.password, remember)
end)

AddEventHandler('sunset:nui:authRegister', function(data)
    local remember = isEnabled(data and data.rememberQuickLogin)
    local license = activeLicense()
    if license then
        SunsetAuthAccounts.setQuickLogin(license, remember)
    end

    local result, err = Sunset.AwaitCallback(
        'sunset:authRegister',
        data.username,
        data.password,
        data.passwordConfirm,
        data.email
    )
    if not result then
        exports.sunset_ui:Send('authError', { message = err })
        exports.sunset_ui:Notify(err or 'Registration failed', 'error')
        return
    end
    exports.sunset_ui:Notify('Account created! Logging in...', 'success')
    handleAuthResult(result, data.username, data.password, remember)
end)

AddEventHandler('sunset:nui:authSetEmail', function(data)
    local result, err = Sunset.AwaitCallback('sunset:authSetEmail', data and data.email)
    if not result then
        exports.sunset_ui:Send('authEmailError', { message = err })
        exports.sunset_ui:Notify(err or 'Could not save email', 'error')
        return
    end

    local pending = pendingAuth or {}
    exports.sunset_ui:Notify('Email saved. Welcome back!', 'success')
    exports.sunset_ui:Send('authEmailSaved', {})
    completeAuthentication(
        pending.username or result.username,
        pending.password,
        pending.rememberQuickLogin
    )
end)

AddEventHandler('sunset:nui:authPickAccount', function(data)
    local username = tostring(data and data.username or '')
    if username == '' then return end

    local license = activeLicense()
    if not license then return end

    local store = SunsetAuthAccounts.load(license)
    local row = SunsetAuthAccounts.find(store, username)
    if not row then
        pushAuthAccounts()
        return
    end

    if store.quickLogin and type(row.password) == 'string' and row.password ~= '' then
        exports.sunset_ui:Send('authQuickLoginStart', { username = row.username })
        performLogin(row.username, row.password, true)
        return
    end

    exports.sunset_ui:Send('authAccountFill', {
        username = row.username,
        password = row.password or '',
    })
end)

AddEventHandler('sunset:nui:authRemoveAccount', function(data)
    local username = tostring(data and data.username or '')
    if username == '' then return end
    local license = activeLicense()
    if not license then return end
    SunsetAuthAccounts.remove(license, username)
    pushAuthAccounts()
end)

AddEventHandler('sunset:nui:authSetQuickLogin', function(data)
    local license = activeLicense()
    if not license then return end
    SunsetAuthAccounts.setQuickLogin(license, isEnabled(data and data.enabled))
    pushAuthAccounts()
end)
