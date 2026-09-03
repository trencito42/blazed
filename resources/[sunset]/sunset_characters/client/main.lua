local inCharacterFlow = false

local function spawnCharacter(char)
    if not char.appearance or not next(char.appearance) then
        TriggerEvent('sunset:client:appearanceRequired', char)
        return
    end
    exports.sunset_ui:Show('loading')
    TriggerEvent('sunset:client:spawnCharacter', char)
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
