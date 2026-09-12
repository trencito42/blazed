-- ============================================================
--  sunset_clothing client — developer compatibility tool (C11)
--  ADMIN/DEV ONLY (gated by sunset_admin level 4 server-side).
--  /clothingdebug — dumps current ped clothing state and lets
--  the developer walk top/torso/undershirt combinations and
--  print a ready-to-paste compatibility entry.
-- ============================================================

local debugActive = false
local debugFocusTop = 0

local function dumpState()
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    local model = GetEntityModel(ped)
    print(('^3[clothingdebug]^7 model=%s gender=%s'):format(tostring(model), tostring(char and char.gender)))
    for comp = 0, 11 do
        print(('  comp %2d: drawable=%3d texture=%2d (variations=%d/%d)'):format(
            comp, GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp),
            GetNumberOfPedDrawableVariations(ped, comp),
            GetNumberOfPedTextureVariations(ped, comp, GetPedDrawableVariation(ped, comp))))
    end
    for _, prop in ipairs({ 0, 1, 2, 6, 7 }) do
        print(('  prop %2d: drawable=%3d texture=%2d'):format(
            prop, GetPedPropIndex(ped, prop), GetPedPropTextureIndex(ped, prop)))
    end
    local top = GetPedDrawableVariation(ped, 11)
    local topTex = GetPedTextureVariation(ped, 11)
    local torso, torsoTex = SunsetAppearance.resolveTorso(ped, char and char.gender or 0, top, topTex)
    print(('^3[clothingdebug]^7 besttorso says: top(%d,%d) -> torso(%d,%d); actual torso=(%d,%d) undershirt=(%d,%d)'):format(
        top, topTex, torso or -1, torsoTex or -1,
        GetPedDrawableVariation(ped, 3), GetPedTextureVariation(ped, 3),
        GetPedDrawableVariation(ped, 8), GetPedTextureVariation(ped, 8)))
end

local function printCompatEntry()
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    local genderKey = (char and char.gender == 1) and 'female' or 'male'
    local top = GetPedDrawableVariation(ped, 11)
    local topTex = GetPedTextureVariation(ped, 11)
    print(('^2[clothingdebug] COMPAT ENTRY^7 %s top %d tex %d -> torso %d tex %d undershirt %d'):format(
        genderKey, top, topTex,
        GetPedDrawableVariation(ped, 3), GetPedTextureVariation(ped, 3),
        GetPedDrawableVariation(ped, 8)))
    print(('  JSON (besttorso_%s.json): "%d": { "%d": { "BestTorsoDrawable": %d, "BestTorsoTexture": %d } }'):format(
        genderKey, top, topTex,
        GetPedDrawableVariation(ped, 3), GetPedTextureVariation(ped, 3)))
end

RegisterNetEvent('sunset:clothing:debugToggle', function(enabled)
    debugActive = enabled ~= false
    if debugActive then
        dumpState()
        print('^3[clothingdebug]^7 ON: [ = top drawable-, ] = top drawable+, - = undershirt-, = = undershirt+, \\ = torso-, Enter(release) = dump, P = print compat entry, ESC-off = /clothingdebug')
    else
        print('^3[clothingdebug]^7 OFF')
    end
end)

CreateThread(function()
    while true do
        if debugActive then
            local ped = PlayerPedId()
            local changed = false
            if IsDisabledControlJustPressed(0, 273) then debugActive = false end
            if IsControlJustPressed(0, 26) then -- [
                local d = math.max(0, GetPedDrawableVariation(ped, 11) - 1)
                SetPedComponentVariation(ped, 11, d, 0, 2)
                changed = true
            elseif IsControlJustPressed(0, 27) then -- ]
                local maxD = GetNumberOfPedDrawableVariations(ped, 11) - 1
                local d = math.min(maxD, GetPedDrawableVariation(ped, 11) + 1)
                SetPedComponentVariation(ped, 11, d, 0, 2)
                changed = true
            elseif IsControlJustPressed(0, 84) then -- -
                local d = math.max(0, GetPedDrawableVariation(ped, 8) - 1)
                SetPedComponentVariation(ped, 8, d, 0, 2)
                changed = true
            elseif IsControlJustPressed(0, 83) then -- =
                local maxD = GetNumberOfPedDrawableVariations(ped, 8) - 1
                local d = math.min(maxD, GetPedDrawableVariation(ped, 8) + 1)
                SetPedComponentVariation(ped, 8, d, 0, 2)
                changed = true
            elseif IsControlJustPressed(0, 73) then -- backslash = torso -
                local d = math.max(0, GetPedDrawableVariation(ped, 3) - 1)
                SetPedComponentVariation(ped, 3, d, 0, 2)
                changed = true
            elseif IsControlJustPressed(0, 81) then -- comma = torso +
                local maxD = GetNumberOfPedDrawableVariations(ped, 3) - 1
                local d = math.min(maxD, GetPedDrawableVariation(ped, 3) + 1)
                SetPedComponentVariation(ped, 3, d, 0, 2)
                changed = true
            elseif IsControlJustPressed(0, 22) then -- SPACE = dump
                dumpState()
            elseif IsControlJustPressed(0, 199) then -- P... mapped: pause key = print entry
                printCompatEntry()
            end
            if changed then
                debugFocusTop = debugFocusTop + 1
                if debugFocusTop % 8 == 0 then dumpState() end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterCommand('clothingdebug', function()
    -- Server validates admin level through the callback before enabling.
    CreateThread(function()
        local ok = Sunset.AwaitCallback('sunset:clothing:debug')
        if ok then
            TriggerEvent('sunset:clothing:debugToggle', not debugActive)
        else
            exports.sunset_ui:Notify('clothingdebug: admin level 4+ required.', 'error')
        end
    end)
end, false)
