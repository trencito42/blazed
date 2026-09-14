-- ═══════════════════════════════════════════════════════════════
--  CASINO DISCOVERY PROBE (client-side, run in-game)
--  Command: /casinoprobe        — full interior + entity dump
--  Command: /casinoscan [m]     — entity scan with radius (default 60m)
--  Command: /casinoanim         — animation dict availability test
--  Command: /casinoprops        — prop model availability test
--  Results print to F8 console AND the server log (docker logs).
--
--  ONE-TIME discovery tool. Model NAMES cannot be read from entities
--  (FiveM has no reverse-hash native), so we match entity hashes against
--  a candidate name list; unmatched hashes are still printed so they can
--  be identified by position/visual inspection.
-- ═══════════════════════════════════════════════════════════════

-- Candidate model names to reverse-match against entity hashes.
local CANDIDATE_MODELS = {
    -- slot machines (vw = Diamond Casino DLC prefix)
    'vw_prop_vw_slot_01a', 'vw_prop_vw_slot_02a', 'vw_prop_vw_slot_03a',
    'vw_prop_vw_slot_04a', 'vw_prop_vw_slot_05a', 'vw_prop_vw_slot_06a',
    'vw_prop_vw_slot_07a', 'vw_prop_vw_slot_08a',
    'prop_vw_slot_01', 'prop_vw_slot_02', 'prop_vw_slot_03',
    'prop_casino_slot_01', 'vw_prop_casino_slot_01a',
    -- lucky wheel
    'vw_prop_vw_lucky_wheel_01a', 'vw_prop_vw_lucky_wheel_02a',
    'vw_prop_vw_luckywheel', 'prop_vw_lucky_wheel',
    'vw_prop_vw_table_01a', -- wheel table base
    -- blackjack / roulette / poker tables
    'vw_prop_vw_card_club_01a', 'vw_prop_casino_card_01',
    'vw_prop_vw_table_casino_short_01', 'vw_prop_vw_table_casino_short_02',
    'vw_prop_vw_table_casino_tall_01', 'vw_prop_casino_roulette_01',
    'vw_prop_casino_roulette_01b', 'vw_prop_roulette_ball',
    'vw_prop_roulette_marker', 'vw_prop_cas_calc_roulette_01',
    -- chairs / stools
    'vw_prop_casino_stool_02a', 'vw_prop_casino_stool_01a',
    'vw_prop_casino_chair_01a', 'vw_prop_casino_chair_02a',
    'vw_prop_casino_chair_03a', 'prop_casino_chair_01',
    'prop_casino_chair_01b', 'prop_casino_chair_02',
    -- chips / bar / misc
    'vw_prop_vw_chip_carrier_01a', 'vw_prop_chip_01a', 'vw_prop_chip_02a',
    'vw_prop_chip_03a', 'vw_prop_chip_04a', 'vw_prop_chip_05a',
    'vw_prop_vw_barstool_01a', 'vw_prop_vw_bar_01a',
    -- screens
    'vw_prop_vw_tv_video_01a', 'vw_prop_vw_screen_tv_01a',
}

local ANIM_DICTS = {
    'anim_casino_poker@player@enter', 'anim_casino_poker@player@exit',
    'anim_casino_poker@dealer',
    'anim_casino_blackjack@dealer', 'anim_casino_blackjack@player',
    'anim_casino_roulette@dealer', 'anim_casino_roulette@player',
    'anim_casino_slots@sit', 'anim_casino_slots@player',
    'anim_casino_slot_machine@base', 'anim_casino_slot_machine@sit',
    'anim_casino_lucky_wheel@enter', 'anim_casino_lucky_wheel@spin',
    'anim_casino@lucky7wheel', 'anim_casino@lucky7wheel@base',
    'anim_casino@lucky7wheel@female', 'anim_casino@lucky7wheel@male',
    'mp_casino@lucky7wheel@base', 'mp_casino@lucky7wheel@enter',
    'anim_casino_wof@spin', 'anim_casino_wof@enter',
    'anim_casino_wof@exit', 'anim_casino_wof@base',
    'casino@slots@male_a@base', 'casino@slots@female_a@base',
    'amb@prop_human_slot_machine@idle_a',
    'amb@prop_human_slot_machine@base',
    'anim@mp_player_intmenu@key_fob@base',
    'anim@heists@money_grab@briefcase',
}

-- [OVERFLOW FIX] Each probe line used to fire its own TriggerServerEvent.
-- A 60m scan can enumerate hundreds of entities -> hundreds of events ->
-- "Reliable network event overflow". Buffer lines and flush in small batches
-- (max 5 lines per event) with a small delay between flushes.
local probeBuffer = {}
local BATCH_SIZE = 5

local function flushProbeBuffer()
    while #probeBuffer > 0 do
        local batch = {}
        for i = 1, math.min(BATCH_SIZE, #probeBuffer) do
            batch[#batch + 1] = table.remove(probeBuffer, 1)
        end
        TriggerServerEvent('sunset:casino:probeLogBatch', batch)
        Wait(50)
    end
end

local function serverPrint(line)
    probeBuffer[#probeBuffer + 1] = line
end

local function log(line)
    print('^3[CASINOPROBE]^7 ' .. line)
    serverPrint(line)
    -- Flush immediately for small outputs (anim/prop tests, interior IDs)
    if #probeBuffer >= BATCH_SIZE then
        CreateThread(flushProbeBuffer)
    end
end

local function logFlush()
    CreateThread(flushProbeBuffer)
end

local function scanEntities(radius)
    radius = tonumber(radius) or 60.0
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local interiorId = GetInteriorFromEntity(ped)
    log(('interior id=%d ready=%s'):format(interiorId, tostring(IsInteriorReady(interiorId))))
    log(('player coords=(%.2f, %.2f, %.2f) radius=%d'):format(coords.x, coords.y, coords.z, radius))

    -- build reverse-hash table for candidates
    local hashToName = {}
    for _, name in ipairs(CANDIDATE_MODELS) do
        hashToName[joaat(name)] = name
    end

    local pool = GetGamePool('CObject') or {}
    log(('CObject pool size=%d'):format(#pool))

    local matched, unmatched = 0, 0
    local matchedNames = {}
    -- [OVERFLOW FIX] Aggregate UNMATCHED by hash instead of one line per
    -- entity — a 60m casino scan can have hundreds of decor objects.
    local unmatchedByHash = {}
    for _, ent in ipairs(pool) do
        local ok, ec = pcall(GetEntityCoords, ent)
        if ok and ec then
            local dist = #(ec - coords)
            if dist < radius then
                local model = GetEntityModel(ent)
                local name = hashToName[model]
                if name then
                    matched = matched + 1
                    matchedNames[name] = matchedNames[name] or {}
                    table.insert(matchedNames[name], {
                        entity = ent,
                        hash = model,
                        x = ec.x, y = ec.y, z = ec.z,
                        heading = GetEntityHeading(ent),
                        dist = dist,
                    })
                    log(('MATCH %s ent=%d hash=%d pos=(%.2f,%.2f,%.2f) h=%.1f d=%.1f'):format(
                        name, ent, model, ec.x, ec.y, ec.z, GetEntityHeading(ent), dist))
                else
                    unmatched = unmatched + 1
                    if not unmatchedByHash[model] then
                        unmatchedByHash[model] = { count = 0, x = ec.x, y = ec.y, z = ec.z }
                    end
                    unmatchedByHash[model].count = unmatchedByHash[model].count + 1
                end
            end
        end
    end
    log(('scan done: matched=%d unmatched=%d unique_unmatched_hashes=%d'):format(
        matched, unmatched, (function() local n = 0 for _ in pairs(unmatchedByHash) do n = n + 1 end return n end)()))

    -- summary per matched model
    for name, list in pairs(matchedNames) do
        log(('SUMMARY %s count=%d first=(%.2f,%.2f,%.2f)'):format(
            name, #list, list[1].x, list[1].y, list[1].z))
    end

    -- summary per unmatched hash (aggregated)
    for model, info in pairs(unmatchedByHash) do
        log(('UNMATCHED_HASH %d count=%d first_pos=(%.2f,%.2f,%.2f)'):format(
            model, info.count, info.x, info.y, info.z))
    end
    return matched, unmatched
end

-- [DISCOVERY] Enumerate interior entity sets. FiveM has NO count native and
-- IsInteriorEntitySetActive takes the set NAME (string), so we probe a list of
-- candidate names known from the community/vw IPL naming scheme. Sets that do
-- not exist simply report false/error and are ignored.
local ENTITY_SET_CANDIDATES = {
    -- main floor shells/props (vw naming)
    'Set_Slots', 'Set_Slot_Machines', 'set_slots', 'slots',
    'Set_Main_Room', 'Set_Casino_Main', 'Set_Interior',
    'Set_Tables', 'Set_Blackjack', 'Set_Roulette', 'Set_Poker',
    'Set_Bar', 'Set_Bar_1', 'Set_Bar_2', 'Bar',
    'Set_Lounge', 'Set_Lounge_1', 'Set_Lounge_2',
    'Set_Cashier', 'Set_Cashier_1',
    'Set_Lucky_Wheel', 'Set_Wheel', 'Set_Wheel_1', 'lucky_wheel',
    'Set_Wheel_Anim', 'Set_Screen_1', 'Set_Screen_2', 'Set_Screens',
    'Set_Dealers', 'Set_Dealer_1', 'Set_DLC_Guns',
    'Set_Valet', 'Set_Valet_1',
    -- heist variants
    'Set_Casino_Shell', 'Set_Vault', 'Set_Vault_Door',
}

local function probeEntitySets(interiorId)
    log(('entity sets: probing %d candidate names on interiorId=%d'):format(#ENTITY_SET_CANDIDATES, interiorId))
    if type(IsInteriorEntitySetActive) ~= 'function' then
        log('  IsInteriorEntitySetActive native unavailable')
        return
    end
    for _, setName in ipairs(ENTITY_SET_CANDIDATES) do
        local ok, active = pcall(IsInteriorEntitySetActive, interiorId, setName)
        if ok then
            log(('  set "%s": active=%s'):format(setName, tostring(active)))
        end
        -- silently skip names the interior does not know
    end
end

local function probeInteriorDetails(coords)
    local ok, interiorId = pcall(GetInteriorAtCoords, coords.x, coords.y, coords.z)
    if not ok or not interiorId or interiorId == 0 then
        log(('GetInteriorAtCoords(%.2f,%.2f,%.2f) -> none'):format(coords.x, coords.y, coords.z))
        return 0
    end
    local groupName = ''
    pcall(function() groupName = GetInteriorGroupName(interiorId) or '' end)
    log(('GetInteriorAtCoords(%.2f,%.2f,%.2f) -> id=%d ready=%s group=%s'):format(
        coords.x, coords.y, coords.z, interiorId, tostring(IsInteriorReady(interiorId)), groupName))
    probeEntitySets(interiorId)
    return interiorId
end

RegisterCommand('casinoprobe', function()
    CreateThread(function()
        log('=== FULL PROBE START ===')

        -- Interior ID: from the player entity AND from the three verified
        -- anchor coords (exit/bar/cashier) — they must all resolve to the same
        -- main-floor interior.
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local pedInterior = GetInteriorFromEntity(ped)
        log(('ped interior id=%d ready=%s at (%.2f,%.2f,%.2f)'):format(
            pedInterior, tostring(IsInteriorReady(pedInterior)), pedCoords.x, pedCoords.y, pedCoords.z))
        probeEntitySets(pedInterior)

        local anchors = {
            { name = 'interiorExit', coords = vector3(1089.63, 205.89, -49.00) },
            { name = 'bar',          coords = vector3(1108.45, 208.87, -49.44) },
            { name = 'cashier',      coords = vector3(1116.03, 219.69, -49.44) },
            { name = 'floorCenter',  coords = vector3(1110.20, 216.60, -49.45) },
        }
        for _, a in ipairs(anchors) do
            log(('--- anchor %s ---'):format(a.name))
            probeInteriorDetails(a.coords)
        end

        scanEntities(60.0)
        log('=== entity scan complete; run /casinoanim and /casinoprops next ===')
        logFlush()
    end)
end, false)

RegisterCommand('casinoscan', function(_, args)
    CreateThread(function()
        scanEntities(args[1])
        logFlush()
    end)
end, false)

RegisterCommand('casinoanim', function()
    CreateThread(function()
        log('=== ANIM DICT AVAILABILITY ===')
        for _, dict in ipairs(ANIM_DICTS) do
            local ok, loaded = pcall(function()
                RequestAnimDict(dict)
                local timeout = GetGameTimer() + 1500
                while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
                    Wait(50)
                end
                local has = HasAnimDictLoaded(dict)
                if has then RemoveAnimDict(dict) end
                return has
            end)
            log(('  anim %s: %s'):format(dict, (ok and loaded) and 'AVAILABLE' or 'missing'))
        end
        log('=== anim probe complete ===')
        logFlush()
    end)
end, false)

RegisterCommand('casinoprops', function()
    CreateThread(function()
        log('=== PROP MODEL AVAILABILITY ===')
        for _, name in ipairs(CANDIDATE_MODELS) do
            local hash = joaat(name)
            local valid = IsModelValid(hash)
            local inCd = IsModelInCdimage(hash)
            log(('  prop %s: valid=%s incdimage=%s'):format(name, tostring(valid), tostring(inCd)))
        end
        log('=== prop probe complete ===')
        logFlush()
    end)
end, false)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/casinoprobe', 'Casino discovery: dump interior + all entities (F8 + server log)')
    TriggerEvent('chat:addSuggestion', '/casinoscan', 'Casino discovery: entity scan', { { name = 'radius', help = 'meters (default 60)' } })
    TriggerEvent('chat:addSuggestion', '/casinoanim', 'Casino discovery: test animation dicts')
    TriggerEvent('chat:addSuggestion', '/casinoprops', 'Casino discovery: test prop models')
end)
