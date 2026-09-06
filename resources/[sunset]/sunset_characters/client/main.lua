local inCharacterFlow = false
local pendingSpawnCharacter = nil

local function trace(stage, detail)
    print(('[SunsetFlow] %s%s'):format(stage, detail and (' | ' .. tostring(detail)) or ''))
    TriggerServerEvent('sunset:server:flowTrace', stage, detail and tostring(detail) or '')
end

local function showSpawnSelection(char)
    trace('spawn_selector_open', char and char.id or 'missing_character')
    pendingSpawnCharacter = char
    local pos = char and char.position
    if type(pos) == 'string' then
        local ok, decoded = pcall(json.decode, pos)
        if ok then pos = decoded end
    end
    local jail = Sunset.AwaitCallback('sunset:getJailSpawnLock')
    if jail and jail.locked then
        pendingSpawnCharacter = char
        exports.sunset_ui:Show('loading')
        TriggerEvent('sunset:client:spawnCharacter', char, {
            x = jail.x, y = jail.y, z = jail.z, w = jail.w or 0.0,
        })
        return
    end
    local homes = Sunset.AwaitCallback('sunset:getSpawnHomes') or {}
    local factionHq = Sunset.AwaitCallback('sunset:getLeaderSpawnHq')
    local playedBefore = char and (char.last_played_before or char.last_played)
    local hasLast = playedBefore ~= nil and playedBefore ~= ''
        and type(pos) == 'table' and tonumber(pos.x) ~= nil and tonumber(pos.y) ~= nil
    exports.sunset_ui:Show('spawn', {
        hasLastLocation = hasLast,
        homes = homes,
        factionHq = factionHq,
    })
end

local function spawnCharacter(char)
    if not char.appearance or not next(char.appearance) then
        TriggerEvent('sunset:client:appearanceRequired', char)
        return
    end
    showSpawnSelection(char)
end

AddEventHandler('sunset:client:spawnSelectionRequired', showSpawnSelection)

local function openSpawnMenuNow(force)
    if inCharacterFlow and not force then
        exports.sunset_ui:Notify('Finish the current login flow first.', 'error')
        return false
    end
    local char = exports.sunset_core:GetCharacter()
    if not char or not char.id then
        exports.sunset_ui:Notify('No character loaded.', 'error')
        return false
    end
    if GetResourceState('sunset_appearance') == 'started' and exports.sunset_appearance:IsEditing() then
        exports.sunset_ui:Notify('Finish character appearance first.', 'error')
        return false
    end
    showSpawnSelection(char)
    return true
end

RegisterNetEvent('sunset:client:openSpawnMenu', function()
    openSpawnMenuNow(true)
end)

RegisterCommand('spawnmenu', function()
    openSpawnMenuNow(false)
end, false)

exports('OpenSpawnMenu', function(force)
    return openSpawnMenuNow(force == true)
end)

CreateThread(function()
    Wait(1500)
    TriggerEvent('chat:addSuggestion', '/spawnmenu', 'Open the spawn location selector without reconnecting')
end)

AddEventHandler('sunset:nui:spawnSelect', function(data)
    if not pendingSpawnCharacter then return end
    local choice = data and data.location
    if choice ~= 'default' and choice ~= 'last' and choice ~= 'house' and choice ~= 'hq' then
        return exports.sunset_ui:Notify('Choose one of the available spawn locations.', 'error')
    end
    local resolved, err = Sunset.AwaitCallback('sunset:resolveSpawnChoice', choice, tonumber(data and data.propertyId))
    if not resolved then
        exports.sunset_ui:Send('spawnSelectFailed', {})
        return exports.sunset_ui:Notify(err or 'That spawn location is unavailable.', 'error', 6000)
    end
    local char = pendingSpawnCharacter
    pendingSpawnCharacter = nil
    trace('spawn_selected', choice)
    exports.sunset_ui:Show('loading')
    TriggerEvent('sunset:client:spawnCharacter', char, resolved)
end)

local function showCharacterList()
    local characters, err = Sunset.AwaitCallback('sunset:getCharacters')
    if type(characters) ~= 'table' then
        exports.sunset_ui:Notify(err or 'Could not load your characters', 'error')
        return
    end
    exports.sunset_ui:Show('characters', {
        characters = characters,
        maxSlots = Sunset.Config.MaxCharacters or 1,
    })
end

local function autoEnterGame()
    if inCharacterFlow then return end
    inCharacterFlow = true
    trace('character_request_started')

    DoScreenFadeOut(300)
    Wait(400)

    local result, err = Sunset.AwaitCallback('sunset:enterGame')
    if result and result.character then
        trace('character_request_complete', result.character.id)
        spawnCharacter(result.character)
        return
    end

    trace('character_request_failed', err or 'empty_response')
    inCharacterFlow = false
    exports.sunset_ui:Hide()
    exports.sunset_ui:Notify(err or 'Could not load your character', 'error')
    DoScreenFadeIn(500)
end

AddEventHandler('sunset:client:onPlayerReady', function()
    Wait(500)
    autoEnterGame()
end)

-- Authentication callbacks and playerReady are separate network messages.
-- Starting from both is intentional; inCharacterFlow makes this idempotent.
AddEventHandler('sunset:client:authenticationComplete', function()
    autoEnterGame()
end)

AddEventHandler('sunset:client:characterFlowComplete', function()
    inCharacterFlow = false
    RenderScriptCams(false, true, 1000, true, true)
    DestroyAllCams(true)
    exports.sunset_ui:Hide()
    DisplayRadar(true)
end)

AddEventHandler('sunset:client:loadingTimedOut', function()
    inCharacterFlow = false
end)

AddEventHandler('sunset:nui:characterCreate', function()
    exports.sunset_ui:Show('create', { firstLogin = false })
end)

AddEventHandler('sunset:nui:characterBack', function()
    CreateThread(showCharacterList)
end)

AddEventHandler('sunset:nui:select', function(data)
    CreateThread(function()
        local char, err = Sunset.AwaitCallback('sunset:selectCharacter', tonumber(data and data.charId))
        if not char then
            exports.sunset_ui:Notify(err or 'Could not select that character', 'error')
            return
        end
        spawnCharacter(char)
    end)
end)

AddEventHandler('sunset:nui:create', function(data)
    CreateThread(function()
        local char, err = Sunset.AwaitCallback('sunset:createCharacter', data or {})
        if not char then
            exports.sunset_ui:Notify(err or 'Could not create the character', 'error')
            return
        end
        spawnCharacter(char)
    end)
end)

AddEventHandler('sunset:nui:delete', function(data)
    CreateThread(function()
        local deleted, err = Sunset.AwaitCallback('sunset:deleteCharacter', tonumber(data and data.charId))
        if not deleted then
            exports.sunset_ui:Notify(err or 'Could not delete that character', 'error')
            return
        end
        exports.sunset_ui:Notify('Character deleted', 'success')
        showCharacterList()
    end)
end)
