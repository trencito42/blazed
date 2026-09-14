local authenticated = false
local sessionLicense = nil
local pendingAuth = nil
local authenticatedUsername = nil
local loadedCharacter = nil
local profileSaveRevision = 0

-- sunset_ui is ensured at boot (original Forza auth design). Calls are still
-- guarded in case the resource hasn't finished starting yet.
local function uiSend(action, data)
    if GetResourceState('sunset_ui') ~= 'started' then return end
    pcall(function() exports.sunset_ui:Send(action, data or {}) end)
end

local function uiNotify(msg, kind, dur)
    if GetResourceState('sunset_ui') ~= 'started' then return end
    pcall(function() exports.sunset_ui:Notify(msg, kind or 'info', dur or 4000) end)
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
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:Send('authAccounts', authPayload()) end)
    end
end

local function openAuth()
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function()
            exports.sunset_ui:Show('auth', authPayload())
            exports.sunset_ui:SetFocus(true, true, false, 'auth')
        end)
    end
end
exports('OpenLogin', openAuth)

local function scheduleAuthWatchdog()
    -- Retry until sunset_ui is started AND the auth screen is actually open.
    -- Covers both late resource start and dropped NUI messages.
    CreateThread(function()
        for i = 1, 20 do
            Wait(1000)
            if authenticated then return end
            if GetResourceState('sunset_ui') == 'started' then
                local isOpen = false
                pcall(function() isOpen = exports.sunset_ui:IsOpen() end)
                if not isOpen then
                    openAuth()
                end
                -- re-push saved accounts each retry (early sends can be dropped)
                pushAuthAccounts()
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
    -- Hide auth screen and release focus
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:Send('authHide', {}) end)
        pcall(function() exports.sunset_ui:SetFocus(false, false) end)
    end
    if isEnabled(rememberQuickLogin) and not saved then
        uiNotify('Login succeeded, but Quick Login could not be saved on this PC.', 'warning', 7000)
    end
    TriggerEvent('sunset:client:authenticationComplete')
end

local function promptEmailSync(username, password, rememberQuickLogin)
    pendingAuth = {
        username = username,
        password = password,
        rememberQuickLogin = isEnabled(rememberQuickLogin),
    }
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:Send('authNeedsEmail', { username = username }) end)
    end
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
        if GetResourceState('sunset_ui') == 'started' then
            pcall(function() exports.sunset_ui:Send('authError', { message = err }) end)
        end
        uiNotify(err or 'Login failed', 'error')
        pushAuthAccounts()
        return false
    end
    if result.needsEmail then
        if GetResourceState('sunset_ui') == 'started' then
            pcall(function() exports.sunset_ui:Send('authError', {}) end)
        end
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
        if GetResourceState('sunset_ui') == 'started' then
            pcall(function() exports.sunset_ui:Send('authError', { message = err }) end)
        end
        uiNotify(err or 'Registration failed', 'error')
        return
    end
    uiNotify('Account created! Logging in...', 'success')
    handleAuthResult(result, data.username, data.password, remember)
end)

AddEventHandler('sunset:nui:authSetEmail', function(data)
    local result, err = Sunset.AwaitCallback('sunset:authSetEmail', data and data.email)
    if not result then
        if GetResourceState('sunset_ui') == 'started' then
            pcall(function() exports.sunset_ui:Send('authEmailError', { message = err }) end)
        end
        uiNotify(err or 'Could not save email', 'error')
        return
    end

    local pending = pendingAuth or {}
    uiNotify('Email saved. Welcome back!', 'success')
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function() exports.sunset_ui:Send('authEmailSaved', {}) end)
    end
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
            if GetResourceState('sunset_ui') == 'started' then
                pcall(function() exports.sunset_ui:Send('authQuickLoginStart', { username = row.username }) end)
            end
            local result, err = Sunset.AwaitCallback('sunset:authQuickLogin', row.username, row.token)
            if result and result.needsEmail then
                promptEmailSync(row.username, nil, true)
            elseif result then
                completeAuthentication(row.username, result.quickToken, store.quickLogin ~= false)
            else
                SunsetAuthAccounts.remove(license, row.username)
                if GetResourceState('sunset_ui') == 'started' then
                    pcall(function() exports.sunset_ui:Send('authError', { message = err or 'Saved login expired. Enter your password again.' }) end)
                end
                pushAuthAccounts()
            end
        end)
        return
    end

    if GetResourceState('sunset_ui') == 'started' then
        pcall(function()
            exports.sunset_ui:Send('authAccountFill', {
                username = row.username,
                password = '',
            })
        end)
    end
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
