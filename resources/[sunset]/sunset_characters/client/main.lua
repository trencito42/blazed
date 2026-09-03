local inCharacterFlow = false

local function openCharacterSelect()
    if inCharacterFlow then return end
    inCharacterFlow = true

    DoScreenFadeOut(500)
    Wait(600)

    local playerData = exports.sunset_core:GetPlayer()
    local characters = Sunset.AwaitCallback('sunset:getCharacters')

    exports.sunset_ui:Show('characters', {
        characters = characters or {},
        playerName = playerData and playerData.name or 'Player',
        maxSlots = Sunset.Config.MaxCharacters,
    })

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, -1037.0, -2737.0, 22.0)
    PointCamAtCoord(cam, -1037.0, -2735.0, 20.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1000, true, true)

    DisplayRadar(false)
    DoScreenFadeIn(800)
end

AddEventHandler('sunset:client:onPlayerReady', function()
    Wait(500)
    openCharacterSelect()
end)

AddEventHandler('sunset:nui:select', function(data)
    local char = Sunset.AwaitCallback('sunset:selectCharacter', data.charId)
    if not char then
        exports.sunset_ui:Notify('Failed to select character', 'error')
        return
    end

    exports.sunset_ui:Show('loading')
    TriggerEvent('sunset:client:spawnCharacter', char)
end)

AddEventHandler('sunset:nui:create', function(data)
    local char, err = Sunset.AwaitCallback('sunset:createCharacter', data)
    if not char then
        exports.sunset_ui:Notify(err or 'Failed to create character', 'error')
        return
    end

    exports.sunset_ui:Notify('Character created', 'success')
    exports.sunset_ui:Show('loading')
    TriggerEvent('sunset:client:spawnCharacter', char)
end)

AddEventHandler('sunset:nui:delete', function(data)
    local success = Sunset.AwaitCallback('sunset:deleteCharacter', data.charId)
    if success then
        exports.sunset_ui:Notify('Character deleted', 'warning')
        local characters = Sunset.AwaitCallback('sunset:getCharacters')
        exports.sunset_ui:Show('characters', {
            characters = characters or {},
            playerName = exports.sunset_core:GetPlayer().name,
            maxSlots = Sunset.Config.MaxCharacters,
        })
    else
        exports.sunset_ui:Notify('Could not delete character', 'error')
    end
end)

AddEventHandler('sunset:nui:characterCreate', function()
    exports.sunset_ui:Show('create', {
        nationalities = Sunset.Nationalities,
    })
end)

AddEventHandler('sunset:nui:characterBack', function()
    local characters = Sunset.AwaitCallback('sunset:getCharacters')
    exports.sunset_ui:Show('characters', {
        characters = characters or {},
        playerName = exports.sunset_core:GetPlayer().name,
        maxSlots = Sunset.Config.MaxCharacters,
    })
end)

AddEventHandler('sunset:client:characterFlowComplete', function()
    inCharacterFlow = false
    RenderScriptCams(false, true, 1000, true, true)
    DestroyAllCams(true)
    exports.sunset_ui:Hide()
    DisplayRadar(true)
end)
