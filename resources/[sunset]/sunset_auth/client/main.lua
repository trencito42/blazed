local authenticated = false
local sessionLicense = nil
local pendingAuth = nil
local authenticatedUsername = nil
local loadedCharacter = nil

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
        quickLogin = true,
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
    if not license then return false end
    local _, saved = SunsetAuthAccounts.upsert(license, username, password, isEnabled(rememberQuickLogin))
    return saved == true
end

local function completeAuthentication(username, password, rememberQuickLogin)
    local saved = true
    if password and username then
        saved = persistLogin(username, password, rememberQuickLogin)
    end
    pendingAuth = nil
    authenticated = true
    authenticatedUsername = username
    exports.sunset_ui:Send('authHide', {})
    if isEnabled(rememberQuickLogin) and not saved then
        exports.sunset_ui:Notify('Login succeeded, but Quick Login could not be saved on this PC.', 'warning', 7000)
    end
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
        pushAuthAccounts()
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
    local remember = isEnabled(data and data.rememberQuickLogin)
    performLogin(data.username, data.password, remember)
end)

AddEventHandler('sunset:nui:authRegister', function(data)
    local remember = isEnabled(data and data.rememberQuickLogin)
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

    if type(row.password) == 'string' and row.password ~= '' then
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
    -- This preference applies only to the credentials currently being submitted.
    -- Existing saved identities remain available independently.
end)

AddEventHandler('sunset:client:onCharacterLoaded', function(char)
    loadedCharacter = char
end)

AddEventHandler('sunset:client:characterFlowComplete', function()
    if not authenticatedUsername or not loadedCharacter then return end
    CreateThread(function()
        Wait(800)
        local ped = PlayerPedId()
        local handle = RegisterPedheadshot(ped)
        local timeout = GetGameTimer() + 4000
        while (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) and GetGameTimer() < timeout do
            Wait(25)
        end
        if IsPedheadshotValid(handle) then
            local txd = GetPedheadshotTxdString(handle)
            exports.sunset_ui:Send('authCapturePortrait', {
                username = authenticatedUsername,
                characterName = (tostring(loadedCharacter.firstname or '') .. ' ' .. tostring(loadedCharacter.lastname or '')):gsub('%s+$', ''),
                characterId = loadedCharacter.id,
                source = ('https://nui-img/%s/%s'):format(txd, txd),
            })
            Wait(2500)
        end
        UnregisterPedheadshot(handle)
    end)
end)

AddEventHandler('sunset:nui:authSavePortrait', function(data)
    local username = tostring(data and data.username or '')
    if username == '' or string.lower(username) ~= string.lower(tostring(authenticatedUsername or '')) then return end
    SunsetAuthAccounts.updateProfile(activeLicense(), username, {
        avatar = data and data.avatar,
        characterName = data and data.characterName,
        characterId = data and data.characterId,
    })
end)
