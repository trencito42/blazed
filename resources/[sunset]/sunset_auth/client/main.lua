local authenticated = false
local sessionLicense = nil
local pendingAuth = nil
local authenticatedUsername = nil
local loadedCharacter = nil
local profileSaveRevision = 0

local function setBootState(state, reason)
    if GetResourceState('sunset_core') == 'started' then
        pcall(function() exports.sunset_core:SetBootState(state, reason) end)
    end
end

local function authUiSend(action, data)
    if GetResourceState('sunset_auth_ui') == 'started' then
        pcall(function() exports.sunset_auth_ui:Send(action, data or {}) end)
    end
end

local function uiNotify(msg, kind, dur)
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:Notify(msg, kind or 'info', dur or 4000) end)
    end
end

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
    authUiSend('authAccounts', authPayload())
end

local function openAuth()
    setBootState('AUTH_FORM', 'login form')
    if GetResourceState('sunset_auth_ui') == 'started' then
        pcall(function()
            exports.sunset_auth_ui:Show('auth', authPayload())
            exports.sunset_auth_ui:SetFocus(true, true)
        end)
    end
end
exports('OpenLogin', openAuth)

local function openQuickAuth(username)
    setBootState('AUTH_BOOT', 'saved login presentation')
    if GetResourceState('sunset_auth_ui') == 'started' then
        local payload = authPayload()
        payload.presentation = 'quick-login'
        payload.loadingText = 'Signing in...'
        payload.username = username
        pcall(function() exports.sunset_auth_ui:Show('auth', payload) end)
    end
end

local function scheduleAuthWatchdog()
    -- Retry only when the dedicated auth UI is not actually visible/open.
    -- Covers both late resource start and dropped NUI messages.
    CreateThread(function()
        for i = 1, 20 do
            Wait(1000)
            if authenticated then return end
            if GetResourceState('sunset_auth_ui') == 'started' then
                local isOpen = false
                pcall(function() isOpen = exports.sunset_auth_ui:IsAuthOpen() end)
                if not isOpen then
                    openAuth()
                else
                    return
                end
            end
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
    setBootState('CHARACTER_LOADING', 'authentication complete')
    -- Even a very fast saved-token response must present at least one stable
    -- auth frame before transition ownership changes.
    if GetResourceState('sunset_auth_ui') == 'started' then
        local visibleDeadline = GetGameTimer() + 1500
        while GetGameTimer() < visibleDeadline do
            local ok, visible = pcall(function() return exports.sunset_auth_ui:IsVisibleRendered() end)
            if ok and visible then break end
            Wait(0)
        end
    end
    authUiSend('authSuccess', { text = 'Loading character...' })
    -- Paint the permanent shell transition before the auth surface is removed.
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:ShowTransition('Loading character...') end)
        local deadline = GetGameTimer() + 2500
        while GetGameTimer() < deadline do
            local ok, visible = pcall(function() return exports.sunset_ui:IsTransitionVisible() end)
            if ok and visible then break end
            Wait(0)
        end
    end
    -- Transition ownership is established; auth can now disappear safely.
    if GetResourceState('sunset_auth_ui') == 'started' then
        pcall(function() exports.sunset_auth_ui:Hide() end)
        pcall(function() exports.sunset_auth_ui:SetFocus(false, false) end)
    end
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:SetFocus(false, false, false, 'force') end)
    end
    if isEnabled(rememberQuickLogin) and not saved then
        uiNotify('Login succeeded, but Quick Login could not be saved on this PC.', 'warning', 7000)
    end
    TriggerEvent('sunset:client:authenticationComplete')
end

local function promptEmailSync(username, password, rememberQuickLogin)
    setBootState('AUTH_FORM', 'email confirmation required')
    pendingAuth = {
        username = username,
        password = password,
        rememberQuickLogin = isEnabled(rememberQuickLogin),
    }
    authUiSend('authNeedsEmail', { username = username })
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
        setBootState('AUTH_FORM', 'password login failed')
        authUiSend('authError', { message = err })
        uiNotify(err or 'Login failed', 'error')
        pushAuthAccounts()
        return false
    end
    if result.needsEmail then
        authUiSend('authError', {})
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

    -- Attempt silent quick login before showing the auth screen.
    -- If there is a saved account with a valid token on this device,
    -- the player skips the screen entirely on every subsequent join.
    local store = SunsetAuthAccounts.load(activeLicense())
    local saved = SunsetAuthAccounts.mostRecent(store)
    if saved and type(saved.token) == 'string' and saved.token ~= '' then
        print('^5[BOOT]^7 auth: saved token found for ' .. tostring(saved.username) .. ', attempting silent quick login')
        openQuickAuth(saved.username)
        setBootState('AUTHENTICATING', 'quick login request')
        CreateThread(function()
            local result, err = Sunset.AwaitCallback('sunset:authQuickLogin', saved.username, saved.token)
            if result and not result.needsEmail then
                print('^5[BOOT]^7 auth: silent quick login succeeded')
                completeAuthentication(saved.username, result.quickToken, true)
            else
                -- Token expired or invalid — remove it and fall back to the form.
                print('^5[BOOT]^7 auth: silent quick login failed (' .. tostring(err) .. '), showing auth screen')
                SunsetAuthAccounts.remove(activeLicense(), saved.username)
                openAuth()
                scheduleAuthWatchdog()
            end
        end)
        return
    end

    print('^5[BOOT]^7 auth: no saved token, opening auth screen')
    openAuth()
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
        uiNotify('You are already logged in.', 'info')
        return
    end
    openAuth()
end, false)
TriggerEvent('chat:addSuggestion', '/fixlogin', 'Re-open the login screen if you only see a black screen')

RegisterNetEvent('sunset:client:playerReady', function()
    authenticated = true
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:SetFocus(false, false) end)
    end
end)

AddEventHandler('sunset:nui:authLogin', function(data)
    local remember = isEnabled(data and data.rememberQuickLogin)
    CreateThread(function()
        setBootState('AUTHENTICATING', 'password login request')
        performLogin(data.username, data.password, remember)
    end)
end)

AddEventHandler('sunset:nui:authRegister', function(data)
    local remember = isEnabled(data and data.rememberQuickLogin)
    setBootState('AUTHENTICATING', 'registration request')
    local result, err = Sunset.AwaitCallback(
        'sunset:authRegister',
        data.username,
        data.password,
        data.passwordConfirm,
        data.email
    )
    if not result then
        setBootState('AUTH_FORM', 'registration failed')
        authUiSend('authError', { message = err })
        uiNotify(err or 'Registration failed', 'error')
        return
    end
    uiNotify('Account created! Logging in...', 'success')
    handleAuthResult(result, data.username, data.password, remember)
end)

AddEventHandler('sunset:nui:authSetEmail', function(data)
    local result, err = Sunset.AwaitCallback('sunset:authSetEmail', data and data.email)
    if not result then
        authUiSend('authEmailResult', { ok = false, message = err })
        uiNotify(err or 'Could not save email', 'error')
        return
    end

    local pending = pendingAuth or {}
    uiNotify('Email saved. Welcome back!', 'success')
    authUiSend('authEmailResult', { ok = true })
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
        uiNotify('Session not ready — try again in a moment', 'error')
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
            setBootState('AUTHENTICATING', 'saved account login request')
            authUiSend('authLoading', { loading = true, text = 'Signing in...' })
            local result, err = Sunset.AwaitCallback('sunset:authQuickLogin', row.username, row.token)
            if result and result.needsEmail then
                promptEmailSync(row.username, nil, true)
            elseif result then
                completeAuthentication(row.username, result.quickToken, store.quickLogin ~= false)
            else
                SunsetAuthAccounts.remove(license, row.username)
                setBootState('AUTH_FORM', 'saved token rejected')
                authUiSend('authError', { message = err or 'Saved login expired. Enter your password again.' })
                pushAuthAccounts()
            end
        end)
        return
    end

    authUiSend('authAccountFill', { username = row.username, password = '' })
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
