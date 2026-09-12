-- ============================================================
--  sunset_admintools client — Raycast Laser Inspector + Orphan
--  Entity Sweeper.
--
--  /inspect  — toggles the laser inspector: aim at any entity to
--              see model hash/name, net id, owner, entity type,
--              coords, health, statebags, population type.
--  /sweeporphans (server-broadcast) — reports/deletes mission
--  entities with no owner that are NOT player-owned vehicles
--  (conservative criteria: mission flag + no network owner + not
--  near any player + older than 5 min tracked locally).
-- ============================================================

local inspectActive = false
local InspectTrack = {} -- [entity] = firstSeen (ms) for sweep age criteria

local function isToolAdmin(cb)
    CreateThread(function()
        local ok = Sunset.AwaitCallback('sunset:admintools:check')
        cb(ok == true)
    end)
end

-- ============================================================
-- RAYCAST INSPECTOR
-- ============================================================
local function raycastEntity()
    local ped = PlayerPedId()
    local cam = GetGameplayCamCoord()
    local dir = GetGameplayCamRot(2)
    local rad = math.rad(dir.x)
    local rotx = math.rad(dir.z)
    dir.x = -math.sin(rotx) * math.abs(math.cos(rad))
    dir.y = math.cos(rotx) * math.abs(math.cos(rad))
    dir.z = math.sin(rad)
    local len = 120.0
    local dest = vector3(cam.x + dir.x * len, cam.y + dir.y * len, cam.z + dir.z * len)
    local ray = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, ped, 4)
    local _, hit, endCoords, _, entity = GetShapeTestResult(ray)
    if hit == 1 and entity ~= 0 then
        return entity, endCoords
    end
    return nil, nil
end

local function describeEntity(ent)
    local lines = {}
    local etype = GetEntityType(ent)
    local typeNames = { [0] = 'none', [1] = 'PED', [2] = 'VEHICLE', [3] = 'OBJECT' }
    local model = GetEntityModel(ent)
    local modelHex = ('0x%08X'):format(model & 0xFFFFFFFF)
    local coords = GetEntityCoords(ent)
    lines[#lines + 1] = ('TYPE: %s | NETID: %d'):format(typeNames[etype] or '?', NetworkGetNetworkIdFromEntity(ent))
    lines[#lines + 1] = ('MODEL: %d (%s)'):format(model, modelHex)
    if etype == 2 then
        local plate = (GetVehicleNumberPlateText(ent) or ''):gsub('%s+', '')
        local class = GetVehicleClass(ent)
        lines[#lines + 1] = ('PLATE: %s | CLASS: %d | FUEL: %.0f%% | ENGINE: %.0f | BODY: %.0f'):format(
            plate, class, GetVehicleFuelLevel(ent), GetVehicleEngineHealth(ent), GetVehicleBodyHealth(ent))
    end
    local ownerSrc = NetworkGetEntityOwner(ent)
    lines[#lines + 1] = ('OWNER: %s | POP: %d | HEALTH: %d | MISSION: %s'):format(
        ownerSrc > 0 and ('src ' .. ownerSrc .. ' (' .. (GetPlayerName(ownerSrc) or '?') .. ')') or 'SERVER/none',
        GetEntityPopulationType(ent), GetEntityHealth(ent),
        tostring(IsEntityAMissionEntity(ent)))
    lines[#lines + 1] = ('POS: %.2f, %.2f, %.2f | HEADING: %.1f'):format(coords.x, coords.y, coords.z, GetEntityHeading(ent))
    -- statebags (sunset* + clanTag*)
    local bags = {}
    for _, key in ipairs({ 'sunsetProtectedVehicle', 'sunsetFactionVehicle', 'sunsetPropertyExit', 'sunsetName' }) do
        local v = Entity(ent).state:get(key)
        if v ~= nil then bags[#bags + 1] = ('%s=%s'):format(key, tostring(v)) end
    end
    if #bags > 0 then lines[#lines + 1] = 'BAGS: ' .. table.concat(bags, ', ') end
    return lines
end

CreateThread(function()
    while true do
        if inspectActive then
            local ent, hitCoords = raycastEntity()
            if ent and DoesEntityExist(ent) then
                InspectTrack[ent] = InspectTrack[ent] or GetGameTimer()
                local lines = describeEntity(ent)
                -- laser line
                local ped = PlayerPedId()
                local from = GetPedBoneCoords(ped, 24818, 0.0, 0.0, 0.0)
                DrawLine(from.x, from.y, from.z, hitCoords.x, hitCoords.y, hitCoords.z, 0, 255, 204, 200)
                DrawMarker(28, hitCoords.x, hitCoords.y, hitCoords.z + 0.1, 0, 0, 0, 0, 0, 0,
                    0.4, 0.4, 0.4, 0, 255, 204, 120, false, false, 2, false, nil, nil, false)
                -- on-screen text (throttled redraw each frame)
                SetTextFont(4)
                SetTextScale(0.3, 0.3)
                SetTextColour(0, 255, 204, 255)
                SetTextEntry('STRING')
                AddTextComponentString('INSPECTOR')
                DrawText(0.02, 0.30)
                for i, line in ipairs(lines) do
                    SetTextFont(4)
                    SetTextScale(0.26, 0.26)
                    SetTextColour(255, 255, 255, 230)
                    SetTextEntry('STRING')
                    AddTextComponentString(line)
                    DrawText(0.02, 0.30 + (i * 0.022))
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterCommand('inspect', function()
    isToolAdmin(function(ok)
        if not ok then
            exports.sunset_ui:Notify('Inspector: admin level 3+ required.', 'error')
            return
        end
        inspectActive = not inspectActive
        exports.sunset_ui:Notify(inspectActive and 'Laser inspector ON — aim at any entity.' or 'Laser inspector OFF.', 'info')
        if not inspectActive then InspectTrack = {} end
    end)
end, false)
TriggerEvent('chat:addSuggestion', '/inspect', 'Admin: toggle 3D raycast entity inspector')

-- ============================================================
-- ORPHAN ENTITY SWEEPER
-- ============================================================
-- Conservative orphan criteria (avoid deleting live gameplay entities):
--  * CVehicle/CObject with the MISSION flag set (script-spawned)
--  * no network owner (owner left / server-side leftover)
--  * farther than 80m from every player (nobody is interacting)
--  * first observed by this sweeper at least 30s ago (transient
--    mission entities being spawned right now are skipped)
--  * NOT in the protected set (statebags sunsetProtectedVehicle /
--    sunsetFactionVehicle are re-checked live)
local SWEEP_AGE_MS = 30000
local SWEEP_DIST = 80.0
local sweepReports = 0

local function playerPositions()
    local out = {}
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= 0 and DoesEntityExist(ped) then
            out[#out + 1] = GetEntityCoords(ped)
        end
    end
    return out
end

local function isOrphan(ent, positions, now)
    if not DoesEntityExist(ent) then return false end
    if not IsEntityAMissionEntity(ent) then return false end
    local owner = NetworkGetEntityOwner(ent)
    if owner and owner > 0 then return false end
    local st = Entity(ent).state
    if st:get('sunsetProtectedVehicle') or st:get('sunsetFactionVehicle') then return false end
    local coords = GetEntityCoords(ent)
    for _, pos in ipairs(positions) do
        if #(coords - pos) <= SWEEP_DIST then return false end
    end
    local firstSeen = InspectTrack[ent]
    if not firstSeen then
        InspectTrack[ent] = now
        return false
    end
    return (now - firstSeen) >= SWEEP_AGE_MS
end

RegisterNetEvent('sunset:admintools:sweep', function(dryRun)
    local now = GetGameTimer()
    local positions = playerPositions()
    local swept = 0
    local candidates = 0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if isOrphan(veh, positions, now) then
            candidates = candidates + 1
            if not dryRun then
                SetEntityAsMissionEntity(veh, true, true)
                DeleteEntity(veh)
                swept = swept + 1
            end
            InspectTrack[veh] = nil
        end
    end
    for _, obj in ipairs(GetGamePool('CObject')) do
        if isOrphan(obj, positions, now) then
            candidates = candidates + 1
            if not dryRun then
                SetEntityAsMissionEntity(obj, true, true)
                DeleteEntity(obj)
                swept = swept + 1
            end
            InspectTrack[obj] = nil
        end
    end
    if candidates > 0 then
        print(('[admintools] orphan sweep (%s): %d candidate(s), %d deleted'):format(
            dryRun and 'dry-run' or 'force', candidates, swept))
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    inspectActive = false
    InspectTrack = {}
end)
