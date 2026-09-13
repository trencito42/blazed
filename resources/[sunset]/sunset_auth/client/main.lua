local authenticated = false
local sessionLicense = nil
local pendingAuth = nil
local authenticatedUsername = nil
local loadedCharacter = nil
local profileSaveRevision = 0

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
        quickLogin = store.quickLogin ~= false,
    }
end

local function pushAuthAccounts()
    exports.sunset_ui:Send('authAccounts', authPayload())
end

local function openAuth()
    exports.sunset_ui:Show('auth', authPayload())
    -- [SAVED ACCOUNTS FIX] Show('auth') only initializes the account list when
    -- the screen is NOT already open (Panels.showAuth skips AuthAccounts.init
    -- for re-opens). Always push the list explicitly so quick-login accounts
    -- render even when the auth screen was pre-shown by the loadscreen handoff.
    pushAuthAccounts()
    exports.sunset_ui:SetFocus(true, true)
end
exports('OpenLogin', openAuth)

local function scheduleAuthWatchdog()
    CreateThread(function()
        Wait(1500)
        if authenticated then return end
        if not exports.sunset_ui:IsOpen() then
            openAuth()
        end
    end)
end

local function persistLogin(username, token, rememberQuickLogin)
    local license = activeLicense()
    if not license then return false end
    local _, saved = SunsetAuthAccounts.upsert(license, username, token, isEnabled(rememberQuickLogin))
    return saved == true
end

local function completeAuthentication(username, quickToken, rememberQuickLogin)
    local saved = true
    if quickToken and username then
        saved = persistLogin(username, quickToken, rememberQuickLogin)
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
    completeAuthentication(username, result and result.quickToken, rememberQuickLogin)
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
    completeAuthentication(username, result.quickToken, rememberQuickLogin)
    return true
end

RegisterNetEvent('sunset:client:sessionReady', function(data)
    print('^5[BOOT]^7 auth: sessionReady received (license=' .. tostring(data and data.license ~= nil) .. ')')
    sessionLicense = data and data.license
    if authenticated then return end
    exports.sunset_ui:Send('preloadEntryBackground', { screen = 'auth' })
    print('^5[BOOT]^7 auth: opening auth screen')
    openAuth()
    print('^5[BOOT]^7 auth: openAuth done')
    scheduleAuthWatchdog()
end)

RegisterNetEvent('sunset:auth:openLogin', openAuth)

-- [SAVED ACCOUNTS FIX] The auth screen announces itself once it is rendered;
-- (re)push the saved-account list then, because SendNUIMessage issued before
-- the NUI page is live can be dropped (accounts only appeared after toggling
-- the quick-login checkbox, which triggered a fresh push).
AddEventHandler('sunset:nui:authReady', function()
    if not authenticated then
        pushAuthAccounts()
    end
end)

RegisterCommand('fixlogin', function()
    if authenticated then
        exports.sunset_ui:Notify('You are already logged in.', 'info')
        return
    end
    openAuth()
end, false)
TriggerEvent('chat:addSuggestion', '/fixlogin', 'Re-open the login screen if you only see a black screen')

RegisterNetEvent('sunset:client:playerReady', function()
    authenticated = true
    exports.sunset_ui:SetFocus(false, false)
end)

AddEventHandler('sunset:nui:authLogin', function(data)
    local remember = isEnabled(data and data.rememberQuickLogin)
    CreateThread(function()
        performLogin(data.username, data.password, remember)
    end)
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
        result.quickToken,
        pending.rememberQuickLogin
    )
end)

AddEventHandler('sunset:nui:authPickAccount', function(data)
    local username = tostring(data and data.username or '')
    if username == '' then return end

    local license = activeLicense()
    if not license then
        exports.sunset_ui:Notify('Session not ready — try again in a moment', 'error')
        return
    end

    local store = SunsetAuthAccounts.load(license)
    local row = SunsetAuthAccounts.find(store, username)
    if not row then
        pushAuthAccounts()
        return
    end

    if type(row.token) == 'string' and row.token ~= '' then
        CreateThread(function()
            exports.sunset_ui:Send('authQuickLoginStart', { username = row.username })
            local result, err = Sunset.AwaitCallback('sunset:authQuickLogin', row.username, row.token)
            if result and result.needsEmail then
                promptEmailSync(row.username, nil, true)
            elseif result then
                completeAuthentication(row.username, result.quickToken, store.quickLogin ~= false)
            else
                SunsetAuthAccounts.remove(license, row.username)
                exports.sunset_ui:Send('authError', { message = err or 'Saved login expired. Enter your password again.' })
                pushAuthAccounts()
            end
        end)
        return
    end

    exports.sunset_ui:Send('authAccountFill', {
        username = row.username,
        password = '',
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
    local enabled = isEnabled(data and data.enabled)
    SunsetAuthAccounts.setQuickLogin(license, enabled)
    pushAuthAccounts()
end)

AddEventHandler('sunset:client:onCharacterLoaded', function(char)
    loadedCharacter = char
end)

local function saveCharacterSnapshot()
    if not authenticatedUsername then return end
    local char = exports.sunset_core:GetCharacter() or loadedCharacter
    if not char then return end
    loadedCharacter = char
    SunsetAuthAccounts.updateProfile(activeLicense(), authenticatedUsername, {
        characterName = (tostring(char.firstname or '') .. ' ' .. tostring(char.lastname or '')):gsub('%s+$', ''),
        characterId = char.id,
        level = char.level,
        cash = char.cash,
        bank = char.bank,
    })
end

AddEventHandler('sunset:client:onCharacterUpdated', function()
    profileSaveRevision = profileSaveRevision + 1
    local revision = profileSaveRevision
    CreateThread(function()
        Wait(1500)
        if revision == profileSaveRevision then saveCharacterSnapshot() end
    end)
end)

AddEventHandler('sunset:client:characterFlowComplete', function()
    if not authenticatedUsername or not loadedCharacter then return end
    CreateThread(function()
        Wait(800)
        saveCharacterSnapshot()
        local currentCharacter = exports.sunset_core:GetCharacter() or loadedCharacter
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
                characterName = (tostring(currentCharacter.firstname or '') .. ' ' .. tostring(currentCharacter.lastname or '')):gsub('%s+$', ''),
                characterId = currentCharacter.id,
                level = currentCharacter.level,
                cash = currentCharacter.cash,
                bank = currentCharacter.bank,
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
        level = data and data.level,
        cash = data and data.cash,
        bank = data and data.bank,
    })
end)
