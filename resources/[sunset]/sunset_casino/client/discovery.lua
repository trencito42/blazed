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

local function serverPrint(line)
    -- mirror to server log so the operator can read it via docker logs
    TriggerServerEvent('sunset:casino:probeLog', line)
end

local function log(line)
    print('^3[CASINOPROBE]^7 ' .. line)
    serverPrint(line)
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
                    log(('UNMATCHED ent=%d hash=%d pos=(%.2f,%.2f,%.2f) h=%.1f d=%.1f'):format(
                        ent, model, ec.x, ec.y, ec.z, GetEntityHeading(ent), dist))
                end
            end
        end
    end
    log(('scan done: matched=%d unmatched=%d'):format(matched, unmatched))

    -- summary per matched model
    for name, list in pairs(matchedNames) do
        log(('SUMMARY %s count=%d first=(%.2f,%.2f,%.2f)'):format(
            name, #list, list[1].x, list[1].y, list[1].z))
    end
    return matched, unmatched
end

RegisterCommand('casinoprobe', function()
    CreateThread(function()
        log('=== FULL PROBE START ===')
        scanEntities(60.0)
        log('=== entity scan complete; run /casinoanim and /casinoprops next ===')
    end)
end, false)

RegisterCommand('casinoscan', function(_, args)
    CreateThread(function()
        scanEntities(args[1])
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
    end)
end, false)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/casinoprobe', 'Casino discovery: dump interior + all entities (F8 + server log)')
    TriggerEvent('chat:addSuggestion', '/casinoscan', 'Casino discovery: entity scan', { { name = 'radius', help = 'meters (default 60)' } })
    TriggerEvent('chat:addSuggestion', '/casinoanim', 'Casino discovery: test animation dicts')
    TriggerEvent('chat:addSuggestion', '/casinoprops', 'Casino discovery: test prop models')
end)
