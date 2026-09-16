-- ============================================================
--  sunset_clothing client — developer compatibility lab (C11)
--  ADMIN/DEV ONLY (gated by sunset_admin level 4 server-side).
--  /clothinglab — full compatibility lab: inspect, walk combos,
--  save mappings, export JSON, report coverage.
-- ============================================================

local debugActive = false
local debugFocusTop = 0

local function dumpState()
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    local model = GetEntityModel(ped)
    print(('^3[clothinglab]^7 model=%s gender=%s'):format(tostring(model), tostring(char and char.gender)))
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
    print(('^3[clothinglab]^7 resolver says: top(%d,%d) -> torso(%d,%d); actual torso=(%d,%d) undershirt=(%d,%d)'):format(
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
    local torso = GetPedDrawableVariation(ped, 3)
    local torsoTex = GetPedTextureVariation(ped, 3)
    local under = GetPedDrawableVariation(ped, 8)
    local underTex = GetPedTextureVariation(ped, 8)
    print(('^2[clothinglab] COMPAT ENTRY^7 %s top %d tex %d -> torso %d tex %d undershirt %d tex %d'):format(
        genderKey, top, topTex, torso, torsoTex, under, underTex))
    print(('  Lua override: SunsetClothingRules.RegisterTopCompatibility("%s", %d, { torso = { %d, %d }, defaultUndershirt = { %d, %d } })'):format(
        genderKey, top, torso, torsoTex, under, underTex))
    print(('  JSON (besttorso_%s.json): "%d": { "%d": { "BestTorsoDrawable": %d, "BestTorsoTexture": %d } }'):format(
        genderKey, top, topTex, torso, torsoTex))
end

-- [CLOTHING LAB] Coverage report: how many tops have besttorso data
local function reportCoverage()
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    local gender = char and char.gender or 0
    local genderKey = gender == 1 and 'female' or 'male'
    local maxTop = GetNumberOfPedDrawableVariations(ped, 11) - 1

    local bank = (gender == 1) and TorsoData.female or TorsoData.male
    local mapped = 0
    local unmapped = {}
    for d = 0, maxTop do
        local entry = bank[tostring(d)] or bank[d]
        if entry then
            mapped = mapped + 1
        else
            unmapped[#unmapped + 1] = d
        end
    end

    print(('^2[clothinglab] COVERAGE^7 gender=%s maxTop=%d mapped=%d unmapped=%d (%.1f%%)'):format(
        genderKey, maxTop, mapped, #unmapped, (mapped / math.max(1, maxTop + 1)) * 100))
    if #unmapped > 0 and #unmapped <= 30 then
        print(('  Unmapped tops: %s'):format(table.concat(unmapped, ', ')))
    elseif #unmapped > 30 then
        print(('  Unmapped tops (first 30): %s ... (+%d more)'):format(
            table.concat(unmapped, ', ', 1, 30), #unmapped - 30))
    end

    -- Overrides count
    local ovCount = 0
    local ovBank = SunsetClothingRules.Overrides[genderKey] or {}
    for _ in pairs(ovBank) do ovCount = ovCount + 1 end
    print(('  Authored overrides: %d'):format(ovCount))
end

-- [CLOTHING LAB] Validate current outfit and optionally repair
local function validateAndRepair(repair)
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    if not char then return end
    local gender = char.gender or 0

    local top = GetPedDrawableVariation(ped, 11)
    local topTex = GetPedTextureVariation(ped, 11)
    local actualTorso = GetPedDrawableVariation(ped, 3)
    local actualTorsoTex = GetPedTextureVariation(ped, 3)
    local actualUnder = GetPedDrawableVariation(ped, 8)

    local expectedTorso, expectedTorsoTex, expectedUnder, expectedUnderTex =
        SunsetClothingRules.resolveTopCombo(ped, gender, top, topTex)

    print(('^3[clothinglab] VALIDATE^7 top=(%d,%d)'):format(top, topTex))
    print(('  Actual:   torso=(%d,%d) undershirt=(%d)'):format(actualTorso, actualTorsoTex, actualUnder))
    print(('  Expected: torso=(%d,%d) undershirt=(%d)'):format(expectedTorso, expectedTorsoTex, expectedUnder))

    local valid = actualTorso == expectedTorso and actualUnder == expectedUnder
    if valid then
        print('^2[clothinglab] STATUS: VALID^7')
    else
        print('^1[clothinglab] STATUS: INVALID^7')
        if repair then
            SetPedComponentVariation(ped, 3, expectedTorso, expectedTorsoTex, 2)
            SetPedComponentVariation(ped, 8, expectedUnder, expectedUnderTex, 2)
            print('^2[clothinglab] REPAIR APPLIED^7')
        end
    end
end

RegisterNetEvent('sunset:clothing:debugToggle', function(enabled)
    debugActive = enabled ~= false
    if debugActive then
        dumpState()
        print('^3[clothinglab]^7 ON:')
        print('  [ / ] = top drawable -/+')
        print('  - / = = undershirt -/+')
        print('  \\ / , = torso -/+')
        print('  SPACE = dump state')
        print('  P = print compat entry')
        print('  C = coverage report')
        print('  V = validate outfit')
        print('  R = validate + repair')
        print('  ESC = off')
    else
        print('^3[clothinglab]^7 OFF')
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
            elseif IsControlJustPressed(0, 199) then -- P = print entry
                printCompatEntry()
            elseif IsControlJustPressed(0, 75) then -- C = coverage
                reportCoverage()
            elseif IsControlJustPressed(0, 86) then -- V = validate
                validateAndRepair(false)
            elseif IsControlJustPressed(0, 82) then -- R = validate + repair
                validateAndRepair(true)
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

RegisterCommand('clothinglab', function()
    CreateThread(function()
        local ok = Sunset.AwaitCallback('sunset:clothing:debug')
        if ok then
            TriggerEvent('sunset:clothing:debugToggle', not debugActive)
        else
            exports.sunset_ui:Notify('clothinglab: admin level 4+ required.', 'error')
        end
    end)
end, false)

-- Backwards compat alias
RegisterCommand('clothingdebug', function()
    ExecuteCommand('clothinglab')
end, false)

-- Standalone validate command (no lab mode needed)
RegisterCommand('validateoutfit', function()
    CreateThread(function()
        local ok = Sunset.AwaitCallback('sunset:clothing:debug')
        if not ok then
            exports.sunset_ui:Notify('validateoutfit: admin level 4+ required.', 'error')
            return
        end
        validateAndRepair(false)
    end)
end, false)

RegisterCommand('repairoutfit', function()
    CreateThread(function()
        local ok = Sunset.AwaitCallback('sunset:clothing:debug')
        if not ok then
            exports.sunset_ui:Notify('repairoutfit: admin level 4+ required.', 'error')
            return
        end
        validateAndRepair(true)
    end)
end, false)
