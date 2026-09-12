-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Turf Wars Client
--  SAMP-style map zones, war HUD, clan-colored enemy blips
-- ═══════════════════════════════════════════════════════════════

local LocalTurfs = {}
local ActiveWar = nil
local CurrentTurf = nil
local TurfBlips = {}
local WarPlayerBlips = {}
local WarBlipPulse = false

local BLIP_DISPLAY_PAUSE_MAP = 3 -- pause map (M) only — never minimap
local BLIP_DISPLAY_BOTH = 2
local BLIP_SPRITE_PLAYER = 1

local function hexToBlipColour(hex)
    if not hex or hex == '' then return 38 end
    hex = tostring(hex):gsub('#', '')
    if #hex ~= 6 then return 38 end
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    if g > r and g > b and g > 150 then return 2 end
    if r > g and r > b and r > 150 then return 1 end
    if b > r and b > g and b > 150 then return 3 end
    if r > 200 and g > 120 and b < 90 then return 46 end
    if r > 200 and g > 200 then return 5 end
    if g > 180 and b > 180 then return 43 end
    return 38
end

local function removeBlipHandle(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function clearTurfBlips()
    for _, row in pairs(TurfBlips) do
        removeBlipHandle(row.area)
        removeBlipHandle(row.center)
    end
    TurfBlips = {}
end

local function clearWarPlayerBlips()
    for sid, blip in pairs(WarPlayerBlips) do
        removeBlipHandle(blip)
        WarPlayerBlips[sid] = nil
    end
end

local function turfAtWar(turfId)
    return ActiveWar and tonumber(ActiveWar.turfId) == tonumber(turfId)
end

local function turfAreaColour(turf, atWar)
    if atWar then
        return WarBlipPulse and 1 or 17
    end
    if turf.ownerClanId then
        return hexToBlipColour(turf.ownerColor)
    end
    return SunsetTurfs.FreeTurfBlipColour or 27
end

local function applyTurfBlipStyle(turf, row, atWar)
    local radius = turf.radius or 110.0
    local zoneAlpha = SunsetTurfs.TurfBlipAlpha or 80
    local zoneColour = turfAreaColour(turf, atWar)

    if atWar then
        zoneAlpha = SunsetTurfs.TurfBlipAlphaWar or 120
    end

    if row.area and DoesBlipExist(row.area) then
        SetBlipDisplay(row.area, BLIP_DISPLAY_PAUSE_MAP)
        SetBlipAlpha(row.area, zoneAlpha)
        SetBlipColour(row.area, zoneColour)
        SetBlipAsShortRange(row.area, false)
        SetBlipFlashes(row.area, atWar)
    end

    if row.center and DoesBlipExist(row.center) then
        SetBlipSprite(row.center, 437)
        SetBlipDisplay(row.center, BLIP_DISPLAY_PAUSE_MAP)
        SetBlipScale(row.center, 0.7)
        SetBlipColour(row.center, zoneColour)
        SetBlipAlpha(row.center, atWar and 255 or 210)
        SetBlipAsShortRange(row.center, false)
        SetBlipFlashes(row.center, atWar)
        BeginTextCommandSetBlipName('STRING')
        local suffix = atWar and ' | RAZBOI' or ''
        AddTextComponentSubstringPlayerName(('Turf #%d: %s [%s]%s'):format(
            turf.id, turf.name, turf.ownerTag or 'LIBER', suffix
        ))
        EndTextCommandSetBlipName(row.center)
    end
end

local function refreshBlips()
    clearTurfBlips()
    for id, t in pairs(LocalTurfs) do
        if not t.coords then goto continue end
        local atWar = turfAtWar(id)
        local radius = t.radius or 110.0
        local zoneBlip = AddBlipForRadius(t.coords.x, t.coords.y, t.coords.z, radius)
        local centerBlip = AddBlipForCoord(t.coords.x, t.coords.y, t.coords.z)
        TurfBlips[id] = { area = zoneBlip, center = centerBlip }
        applyTurfBlipStyle(t, TurfBlips[id], atWar)
        ::continue::
    end
end

local function refreshWarTurfBlipPulse()
    if not ActiveWar then return end
    local row = TurfBlips[ActiveWar.turfId]
    local turf = LocalTurfs[ActiveWar.turfId]
    if row and turf then
        applyTurfBlipStyle(turf, row, true)
    end
end

local function myWarClanRole()
    if not ActiveWar then return nil end
    local myClan = LocalPlayer.state.sunsetClanId
    if not myClan then return nil end
    if tonumber(myClan) == tonumber(ActiveWar.attackerClanId) then return 'attacker' end
    if ActiveWar.defenderClanId and tonumber(myClan) == tonumber(ActiveWar.defenderClanId) then return 'defender' end
    return nil
end

local function syncWarPlayerBlips()
    if not ActiveWar then
        clearWarPlayerBlips()
        return
    end

    local role = myWarClanRole()
    if not role then
        clearWarPlayerBlips()
        return
    end

    local turf = LocalTurfs[ActiveWar.turfId]
    if not turf or not turf.coords then
        clearWarPlayerBlips()
        return
    end

    local seen = {}
    local friendlyHex = ActiveWar.attackerColor
    local enemyHex = ActiveWar.defenderColor
    if role == 'defender' then
        friendlyHex = ActiveWar.defenderColor
        enemyHex = ActiveWar.attackerColor
    end
    local friendlyColour = hexToBlipColour(friendlyHex)
    local enemyColour = hexToBlipColour(enemyHex)

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped == 0 or not DoesEntityExist(ped) then goto continue end

        local sid = GetPlayerServerId(playerId)
        if sid <= 0 then goto continue end

        local pos = GetEntityCoords(ped)
        if #(pos - turf.coords) > (turf.radius or 110.0) then goto continue end

        local pClan = Player(sid).state.sunsetClanId
        if not pClan then goto continue end

        local isFriendly = (role == 'attacker' and tonumber(pClan) == tonumber(ActiveWar.attackerClanId))
            or (role == 'defender' and ActiveWar.defenderClanId and tonumber(pClan) == tonumber(ActiveWar.defenderClanId))

        seen[sid] = true
        local blip = WarPlayerBlips[sid]
        if not blip or not DoesBlipExist(blip) then
            blip = AddBlipForEntity(ped)
            WarPlayerBlips[sid] = blip
            SetBlipSprite(blip, BLIP_SPRITE_PLAYER)
            SetBlipDisplay(blip, BLIP_DISPLAY_BOTH)
            SetBlipScale(blip, 0.85)
            SetBlipAsShortRange(blip, false)
        end

        local colour = isFriendly and friendlyColour or enemyColour
        SetBlipColour(blip, colour)
        SetBlipFlashes(blip, not isFriendly)

        BeginTextCommandSetBlipName('STRING')
        if isFriendly then
            AddTextComponentSubstringPlayerName(('FRIENDLY %s'):format(Player(sid).state.clanTag or 'CLAN'))
        else
            AddTextComponentSubstringPlayerName(('ENEMY %s'):format(Player(sid).state.clanTag or 'CLAN'))
        end
        EndTextCommandSetBlipName(blip)

        ::continue::
    end

    for sid, blip in pairs(WarPlayerBlips) do
        if not seen[sid] then
            removeBlipHandle(blip)
            WarPlayerBlips[sid] = nil
        end
    end
end

RegisterNetEvent('sunset:turfs:syncAll', function(turfs)
    LocalTurfs = turfs or {}
    refreshBlips()
end)

RegisterNetEvent('sunset:turfs:warStart', function(war)
    ActiveWar = war
    refreshBlips()
    -- [WAR FIX] Only participants hear the war-start sting and see the HUD;
    -- the broadcast still updates blips/map for everyone, but the on-screen
    -- war panels are participant-only (warParticipant set via warJoined).
    if warParticipant then
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
        exports.sunset_ui:Send('warHudShow', {
            attackerName = war.attackerName,
            defenderName = war.defenderName,
            attackerScore = war.attackerScore or 0,
            defenderScore = war.defenderScore or 0,
            scoreTarget = war.scoreTarget,
            turfName = war.turfName,
            remainingSec = war.remainingSec or 0,
        })
    end
    if war.isNeutralCapture then
        exports.sunset_ui:Notify(
            ('Capturing %s: hold the zone for %d seconds (%d players = faster).'):format(
                war.turfName or 'turf',
                war.captureTarget or SunsetTurfs.NeutralCaptureSec or 180,
                1
            ),
            'info',
            9000
        )
    end
end)

RegisterNetEvent('sunset:turfs:warTick', function(war)
    if ActiveWar and ActiveWar.turfId == war.turfId then
        ActiveWar = war
    end
end)

RegisterNetEvent('sunset:turfs:warEnd', function(data)
    if ActiveWar and ActiveWar.turfId == data.turfId then
        ActiveWar = nil
    end
    clearWarPlayerBlips()
    refreshBlips()
    -- [WAR FIX] Hide participant panels first (harmless for non-participants).
    exports.sunset_ui:Send('warHudHide', {})
    exports.sunset_ui:Send('warRespawnHide', {})
    exports.sunset_ui:Send('warScoreboardHide', {})
    exports.sunset_ui:Send('warArmoryHide', {})
    if warParticipant then
        warParticipant = false
        local myRole = myWarRole or 'defender'
        PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
        -- [WAR FIX] Strip the loadout weapons granted for this war.
        TriggerEvent('sunset:turfs:warEndedLocal')
        exports.sunset_ui:Send('warEndShow', {
            turfId = data.turfId,
            turfName = data.turfName,
            attackerName = data.attackerName,
            defenderName = data.defenderName,
            attackerWon = data.attackerWon,
            attackerScore = data.attackerScore,
            defenderScore = data.defenderScore,
            mvp = data.mvp,
            myRole = myRole,
        })
        exports.sunset_ui:SetFocus(true, true)
    end
    myWarRole = nil
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('sunset:turfs:requestSync')

    while true do
        Wait(800)
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            local pos = GetEntityCoords(ped)
            local insideAny = nil

            for _, t in pairs(LocalTurfs) do
                if #(pos - t.coords) <= (t.radius or 110.0) then
                    insideAny = t
                    break
                end
            end

            if insideAny and insideAny ~= CurrentTurf then
                CurrentTurf = insideAny
                local ownerStr = insideAny.ownerClanId
                    and ('[%s] %s'):format(insideAny.ownerTag, insideAny.ownerName)
                    or 'Free'
                exports.sunset_ui:Notify(
                    ('Territory: %s (%s)'):format(insideAny.name, ownerStr),
                    'info',
                    4500
                )
            elseif not insideAny and CurrentTurf then
                CurrentTurf = nil
            end
        end
    end
end)

CreateThread(function()
    while true do
        if ActiveWar then
            WarBlipPulse = not WarBlipPulse
            refreshWarTurfBlipPulse()
            Wait(650)
        else
            Wait(1200)
        end
    end
end)

CreateThread(function()
    while true do
        if ActiveWar and myWarClanRole() then
            syncWarPlayerBlips()
            Wait(450)
        else
            clearWarPlayerBlips()
            Wait(1000)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  [WAR REDESIGN] Participant flow: join -> armory (loadout) ->
--  fight -> death -> respawn in zone with HP/armor -> war end screen.
-- ═══════════════════════════════════════════════════════════════
warParticipant = false            -- server said we're in the war
myWarRole = nil                   -- 'attacker' | 'defender'
local warWeapons = {}             -- loadout weapon hashes to strip at war end
local armoryOpen = false
local respawnPending = false

local function closeArmory()
    if not armoryOpen then return end
    armoryOpen = false
    exports.sunset_ui:Send('warArmoryHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

RegisterNetEvent('sunset:turfs:warJoined', function(data)
    warParticipant = true
    myWarRole = data and data.role or 'defender'
    exports.sunset_ui:Notify('You joined the war! /armory for loadout. Z = war stats.', 'warning', 9000)
    -- [MOBILIZATION] Loud targeted alert for defenders: your turf is under
    -- attack, get there (rally window before zone scoring).
    if myWarRole == 'defender' then
        PlaySoundFrontend(-1, 'Event_Start_Text', 'HUD_MINI_GAME_SOUNDSET', true)
        exports.sunset_ui:Notify('YOUR TERRITORY IS UNDER ATTACK! Rally now - scoring starts after the rally window.', 'error', 12000)
    end
    -- [WAR FIX] warStart (-1 broadcast) arrives BEFORE the ticker registers us
    -- as participant, so the participant-gated warHudShow never fired for the
    -- attacker who started the war. Show the HUD here from the cached war data.
    if ActiveWar and ActiveWar.turfId == (data and data.turfId or ActiveWar.turfId) then
        exports.sunset_ui:Send('warHudShow', {
            attackerName = ActiveWar.attackerName,
            defenderName = ActiveWar.defenderName,
            attackerScore = ActiveWar.attackerScore or 0,
            defenderScore = ActiveWar.defenderScore or 0,
            scoreTarget = ActiveWar.scoreTarget,
            turfName = ActiveWar.turfName,
            remainingSec = ActiveWar.remainingSec or 0,
        })
    end
    -- Auto-open the armory on first join so players discover the loadout menu.
    if not armoryOpen and not IsNuiFocused() then
        CreateThread(function()
            local info = Sunset.AwaitCallback('sunset:turfs:armoryData')
            if info and warParticipant then
                armoryOpen = true
                exports.sunset_ui:Send('warArmoryShow', info)
                exports.sunset_ui:SetFocus(true, true)
            end
        end)
    end
end)

RegisterCommand('armory', function()
    if not warParticipant then
        exports.sunset_ui:Notify('You are not in an active war.', 'error')
        return
    end
    if armoryOpen then closeArmory() return end
    CreateThread(function()
        local info = Sunset.AwaitCallback('sunset:turfs:armoryData')
        if not info then exports.sunset_ui:Notify('The armory is not available right now.', 'error') return end
        armoryOpen = true
        exports.sunset_ui:Send('warArmoryShow', info)
        exports.sunset_ui:SetFocus(true, true)
    end)
end, false)

-- [ARMORY FIX] Legacy alias: players used to type /armurie and got an
-- "unknown command" error since the alias went missing. /armory is canonical.
RegisterCommand('armurie', function()
    ExecuteCommand('armory')
end, false)

AddEventHandler('sunset:nui:warArmoryClose', function()
    closeArmory()
end)

AddEventHandler('sunset:nui:warTakeLoadout', function(data)
    CreateThread(function()
        local ok, name = Sunset.AwaitCallback('sunset:turfs:takeLoadout', data and data.loadoutId)
        if ok then
            exports.sunset_ui:Notify(('Package equipped: %s'):format(tostring(name or '')), 'success')
            closeArmory()
        else
            exports.sunset_ui:Notify(name or 'Could not equip the package.', 'error')
        end
    end)
end)

RegisterNetEvent('sunset:turfs:grantLoadout', function(payload)
    local ped = PlayerPedId()
    if payload.heal then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    end
    if payload.armor and payload.armor > 0 then
        SetPedArmour(ped, math.min(100, payload.armor))
    end
    for _, w in ipairs(payload.weapons or {}) do
        local hash = type(w.weapon) == 'number' and w.weapon or joaat(w.weapon)
        GiveWeaponToPed(ped, hash, w.ammo or 120, false, true)
        -- [WAR FIX] Track granted hashes so they can be stripped when the war
        -- ends (previously the sniper kit stayed forever after the war).
        warWeapons[hash] = true
    end
end)

-- [WAR FIX] Strip every loadout weapon granted during the war.
local function stripWarWeapons()
    local ped = PlayerPedId()
    for hash in pairs(warWeapons) do
        if HasPedGotWeapon(ped, hash, false) then
            RemoveWeaponFromPed(ped, hash)
        end
        warWeapons[hash] = nil
    end
    SetPedArmour(ped, 0)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
end

-- War respawn: server picks the coords and re-grants the chosen loadout.
RegisterNetEvent('sunset:turfs:doWarRespawn', function(payload)
    respawnPending = false
    exports.sunset_ui:Send('warRespawnHide', {})
    -- [FOCUS FIX] Guarantee mouse/cursor release after the war respawn, even if
    -- some panel (armory/respawn UI) still held focus through the death.
    exports.sunset_ui:SetFocus(false, false)
    -- Clear sunset_death downed state (same pattern as the jail intake flow)
    -- so bleedout anim/controls do not race the war respawn.
    pcall(function() exports.sunset_death:ClearDead() end)
    NetworkResurrectLocalPlayer(payload.coords.x, payload.coords.y, payload.coords.z, 0.0, true, false)
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, math.min(100, payload.armor or 50))
    for _, w in ipairs(payload.weapons or {}) do
        local hash = type(w.weapon) == 'number' and w.weapon or joaat(w.weapon)
        GiveWeaponToPed(ped, hash, w.ammo or 120, false, true)
    end
    SetPlayerControl(PlayerId(), true, 0)
end)

local function startWarRespawnCountdown()
    if respawnPending then return end
    respawnPending = true
    closeArmory()
    CreateThread(function()
        local secs = SunsetTurfs.RespawnDelaySec or 5
        exports.sunset_ui:Send('warRespawnShow', { seconds = secs })
        while secs > 0 and warParticipant do
            Wait(1000)
            secs = secs - 1
            exports.sunset_ui:Send('warRespawnShow', { seconds = secs })
        end
        if warParticipant then
            Sunset.AwaitCallback('sunset:turfs:warRespawn')
        else
            respawnPending = false
            exports.sunset_ui:Send('warRespawnHide', {})
        end
    end)
end

-- Death watch: only for war participants (the normal death/EMS flow stays
-- intact for everyone else). Downed in war -> respawn inside the zone.
CreateThread(function()
    while true do
        if warParticipant and not respawnPending then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
                startWarRespawnCountdown()
            end
            Wait(400)
        else
            Wait(800)
        end
    end
end)

-- Z scoreboard during war (overrides the global player list for participants).
CreateThread(function()
    local zDown = false
    while true do
        if warParticipant and not IsNuiFocused() and not IsPauseMenuActive() then
            DisableControlAction(0, 20, true)
            local pressed = IsDisabledControlPressed(0, 20)
            if pressed and not zDown then
                zDown = true
                CreateThread(function()
                    local data = Sunset.AwaitCallback('sunset:turfs:warScoreboard')
                    if data and zDown then exports.sunset_ui:Send('warScoreboardShow', data) end
                end)
            elseif not pressed and zDown then
                zDown = false
                exports.sunset_ui:Send('warScoreboardHide', {})
            end
            Wait(0)
        else
            if zDown then
                zDown = false
                exports.sunset_ui:Send('warScoreboardHide', {})
            end
            Wait(300)
        end
    end
end)

AddEventHandler('sunset:nui:warEndClose', function()
    exports.sunset_ui:Send('warEndHide', {})
    exports.sunset_ui:SetFocus(false, false)
end)

-- [WAR FIX] Fired from the warEnd handler after warParticipant is cleared:
-- remove the loadout kit so players don't keep sniper/rifle weapons forever.
AddEventHandler('sunset:turfs:warEndedLocal', function()
    stripWarWeapons()
    myWarRole = nil
    respawnPending = false
    exports.sunset_ui:Send('warRespawnHide', {})
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeArmory()
    exports.sunset_ui:Send('warHudHide', {})
    exports.sunset_ui:Send('warRespawnHide', {})
    exports.sunset_ui:Send('warScoreboardHide', {})
    exports.sunset_ui:Send('warEndHide', {})
end)

CreateThread(function()
    while true do
        -- [WAR FIX] HUD updates only for participants (was sent to everyone).
        if ActiveWar and warParticipant then
            exports.sunset_ui:Send('warHudUpdate', {
                attackerName = ActiveWar.attackerName,
                defenderName = ActiveWar.defenderName,
                attackerScore = ActiveWar.attackerScore or 0,
                defenderScore = ActiveWar.defenderScore or 0,
                scoreTarget = ActiveWar.scoreTarget,
                turfName = ActiveWar.turfName,
                remainingSec = ActiveWar.remainingSec or 0,
            })
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

RegisterNetEvent('sunset:turfs:teleport', function(coords)
    local ped = PlayerPedId()
    if not coords then return end
    SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.5, false, false, false, false)
end)

CreateThread(function()
    Wait(1500)
TriggerEvent('chat:addSuggestion', '/attackturf', 'Attack the territory you are standing in (clan rank 5+)')
TriggerEvent('chat:addSuggestion', '/atac', 'Alias for /attackturf')
TriggerEvent('chat:addSuggestion', '/intervene', 'Claim an unowned turf being captured - your clan becomes the defender (rank 5+)')
TriggerEvent('chat:addSuggestion', '/armory', 'War loadout menu (alias: /armurie)')
    TriggerEvent('chat:addSuggestion', '/turflist', 'List territories + war status (admin)')
    TriggerEvent('chat:addSuggestion', '/gototurf', 'Teleport to a territory (admin)', { { name = 'id', help = '1-16' } })
    TriggerEvent('chat:addSuggestion', '/forceturf', 'Force-start a war (admin)', {
        { name = 'turfId', help = '1-16' },
        { name = 'clanId', help = 'optional' },
    })
    TriggerEvent('chat:addSuggestion', '/stopwar', 'Stop the active war (admin)', { { name = 'turfId', help = '1-16' } })
    TriggerEvent('chat:addSuggestion', '/resetturfcd', 'Reset territory cooldown (admin)', { { name = 'id|all' } })
end)

-- [WAR REDESIGN] Client export so sunset_death can skip the downed/EMS flow
-- for war participants (war respawn handles them instead).
exports('IsInWar', function() return warParticipant == true end)
-- Kill feed during wars (server broadcasts each war kill).
RegisterNetEvent('sunset:turfs:warKill', function(data)
    if not data then return end
    exports.sunset_ui:Notify(
                    ('WAR: %s [%s] took down %s'):format(tostring(data.killer), tostring(data.clanTag or ''), tostring(data.victim)),
        'error', 4000)
end)