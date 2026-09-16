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

-- [CLOTHING LAB] Coverage report: how many tops have usable mapping data
local function reportCoverage()
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    local gender = char and char.gender or 0
    local genderKey = gender == 1 and 'female' or 'male'
    local maxTop = GetNumberOfPedDrawableVariations(ped, 11) - 1

    local bank = (gender == 1) and TorsoData.female or TorsoData.male
    local overrides = SunsetClothingRules.Overrides[genderKey] or {}

    local countOverride = 0
    local countBestTorso = 0
    local countFallback = 0

    for d = 0, maxTop do
        if overrides[d] then
            countOverride = countOverride + 1
        else
            local topEntry = bank[tostring(d)] or bank[d]
            local hasUsable = false
            if topEntry then
                for _, texVal in pairs(topEntry) do
                    if type(texVal) == 'table' and texVal.BestTorsoDrawable and texVal.BestTorsoDrawable >= 0 then
                        hasUsable = true
                        break
                    end
                end
            end
            if hasUsable then
                countBestTorso = countBestTorso + 1
            else
                countFallback = countFallback + 1
            end
        end
    end

    local total = maxTop + 1
    local totalMapped = countOverride + countBestTorso
    print(('^2[clothinglab] COVERAGE^7 gender=%s maxTop=%d totalTops=%d'):format(genderKey, maxTop, total))
    print(('  - Authored Overrides: %d (%.1f%%)'):format(countOverride, (countOverride / total) * 100))
    print(('  - Usable BestTorso:    %d (%.1f%%)'):format(countBestTorso, (countBestTorso / total) * 100))
    print(('  - Gender Fallback:     %d (%.1f%%)'):format(countFallback, (countFallback / total) * 100))
    print(('  - Total Valid Mapped:  %d / %d (%.1f%%)'):format(totalMapped, total, (totalMapped / total) * 100))
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
    local actualUnderTex = GetPedTextureVariation(ped, 8)

    local bundle = SunsetClothingRules.resolveUpperBody(ped, gender, top, topTex, actualUnder, actualUnderTex, false)

    local expectedTorso = bundle.torso.drawable
    local expectedTorsoTex = bundle.torso.texture
    local expectedUnder = bundle.undershirt.drawable
    local expectedUnderTex = bundle.undershirt.texture

    local torsoValid = (actualTorso == expectedTorso and actualTorsoTex == expectedTorsoTex)
    local underValid = SunsetClothingRules.isUndershirtAllowed(gender, top, actualUnder)

    print(('^3[clothinglab] VALIDATE^7 top=(%d,%d) source=%s'):format(top, topTex, bundle.source))
    print(('  Actual:   torso=(%d,%d) undershirt=(%d,%d)'):format(actualTorso, actualTorsoTex, actualUnder, actualUnderTex))
    print(('  Expected: torso=(%d,%d) undershirt=(%d,%d)'):format(expectedTorso, expectedTorsoTex, expectedUnder, expectedUnderTex))

    local valid = torsoValid and underValid
    if valid then
        print('^2[clothinglab] STATUS: VALID^7')
    else
        print(('^1[clothinglab] STATUS: INVALID (torsoValid=%s, underValid=%s)^7'):format(tostring(torsoValid), tostring(underValid)))
        if repair then
            if not torsoValid then
                SetPedComponentVariation(ped, 3, expectedTorso, expectedTorsoTex, 2)
            end
            if not underValid then
                SetPedComponentVariation(ped, 8, expectedUnder, expectedUnderTex, 2)
            end
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

-- Standalone validate command
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

-- [CLOTHING TEST SUITE] Comprehensive automated acceptance test suite
RegisterCommand('clothingtest', function(source, args)
    CreateThread(function()
        local ok = Sunset.AwaitCallback('sunset:clothing:debug')
        if not ok then
            exports.sunset_ui:Notify('clothingtest: admin level 4+ required.', 'error')
            return
        end

        local ped = PlayerPedId()
        local char = exports.sunset_core:GetCharacter()
        if not char then
            print('^1[clothingtest] ERROR: No character loaded.^7')
            return
        end

        local gender = char.gender or 0
        local genderKey = gender == 1 and 'female' or 'male'
        local snapshot = SunsetAppearance.GetClothingSnapshot(ped)
        local baseAppearance = char.appearance or SunsetAppearance.default(gender)

        local count = tonumber(args[1]) or 50
        local maxTop = GetNumberOfPedDrawableVariations(ped, 11) - 1
        count = math.min(count, maxTop)

        print(('^3[clothingtest] Starting automated clothing compatibility audit (%s, %d tops)...^7'):format(genderKey, count))

        local passed = 0
        local failed = 0
        local issues = {}

        -- Test 1: Start with a long sleeve undershirt (8=0 or 8=1), cycle tops -> verify no stale undershirt survives
        for top = 0, count do
            local testApp = SunsetClothing.normalizeWardrobe(baseAppearance, gender)
            -- Simulate prior outfit with long sleeve undershirt (drawable 0)
            testApp.components['8'] = { drawable = 0, texture = 0 }
            testApp = SunsetClothing.setCategorySelection(testApp, ped, gender, 'top', top, 0)

            local torso = testApp.components['3'] and testApp.components['3'].drawable
            local under = testApp.components['8'] and testApp.components['8'].drawable

            if torso == nil or torso < 0 then
                failed = failed + 1
                issues[#issues + 1] = ('Top %03d: Invalid torso (%s)'):format(top, tostring(torso))
            elseif under == nil or under < 0 then
                failed = failed + 1
                issues[#issues + 1] = ('Top %03d: Invalid undershirt (%s)'):format(top, tostring(under))
            elseif not SunsetClothingRules.isUndershirtAllowed(gender, top, under) then
                failed = failed + 1
                issues[#issues + 1] = ('Top %03d: Stale/incompatible undershirt retained (%d)'):format(top, under)
            else
                passed = passed + 1
            end
        end

        -- Test 2: Specific check for Top 27
        local top27App = SunsetClothing.normalizeWardrobe(baseAppearance, gender)
        top27App = SunsetClothing.setCategorySelection(top27App, ped, gender, 'top', 27, 0)
        if top27App.components['3'].drawable == 1 then
            failed = failed + 1
            issues[#issues + 1] = 'Top 027: Torso is 1 (clipping white sleeves); must be 0.'
        end

        -- Test 3: Specific check for Top 44
        local top44App = SunsetClothing.normalizeWardrobe(baseAppearance, gender)
        top44App.components['8'] = { drawable = 0, texture = 0 }
        top44App = SunsetClothing.setCategorySelection(top44App, ped, gender, 'top', 44, 0)
        if top44App.components['8'].drawable ~= 15 then
            failed = failed + 1
            issues[#issues + 1] = ('Top 044: Undershirt is %d; must be 15 None.'):format(top44App.components['8'].drawable)
        end

        -- Restore original appearance
        SunsetAppearance.ApplyClothingSnapshot(ped, snapshot)

        print(('^2[clothingtest] Results: %d PASSED, %d FAILED (Total tested: %d)^7'):format(passed, failed, count + 1))
        if #issues > 0 then
            print('^1[clothingtest] Failures detected:^7')
            for _, err in ipairs(issues) do
                print('  - ' .. err)
            end
            exports.sunset_ui:Notify(('Clothing test completed: %d failed'):format(failed), 'error')
        else
            print('^2[clothingtest] ALL CLOTHING COMPATIBILITY ACCEPTANCE TESTS PASSED!^7')
            exports.sunset_ui:Notify('All clothing compatibility checks passed!', 'success')
        end
    end)
end, false)
