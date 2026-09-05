local inCharacterFlow = false
local pendingSpawnCharacter = nil

local function showSpawnSelection(char)
    pendingSpawnCharacter = char
    local pos = char and char.position
    exports.sunset_ui:Show('spawn', {
        hasLastLocation = type(pos) == 'table' and tonumber(pos.x) ~= nil and tonumber(pos.y) ~= nil,
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

AddEventHandler('sunset:nui:spawnSelect', function(data)
    if not pendingSpawnCharacter then return end
    local choice = data and data.location
    if choice ~= 'default' and choice ~= 'last' then
        return exports.sunset_ui:Notify('Choose Default Spawn or Last Location.', 'error')
    end
    local char = pendingSpawnCharacter
    pendingSpawnCharacter = nil
    exports.sunset_ui:Show('loading')
    TriggerEvent('sunset:client:spawnCharacter', char, choice)
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

    DoScreenFadeOut(300)
    Wait(400)

    local result, err = Sunset.AwaitCallback('sunset:enterGame')
    if result and result.character then
        spawnCharacter(result.character)
        return
    end

    inCharacterFlow = false
    exports.sunset_ui:Hide()
    exports.sunset_ui:Notify(err or 'Could not load your character', 'error')
    DoScreenFadeIn(500)
end

AddEventHandler('sunset:client:onPlayerReady', function()
    Wait(500)
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
