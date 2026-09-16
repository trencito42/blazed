-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Robbery (client/world.lua)
--  Door/vault physics. SERVER owns unlock state (broadcast via
--  sunset:robbery:doorState + doorSync callback); this file only renders it.
--
--  Vault doors (v_ilev_gb_vauldoor) are articulated map props: the
--  DoorSystem unlock alone does NOT swing them. We capture the CLOSED
--  heading baseline when the entity is first seen while locked, then
--  smoothly rotate to baseline+openDelta on unlock and back on lock.
-- ═══════════════════════════════════════════════════════════════

local function prepareJewelryInterior()
    RemoveIpl('jewel2fake')
    RequestIpl('post_hiest_unload')
    local interior = GetInteriorAtCoords(-622.25, -230.93, 38.06)
    if interior and interior ~= 0 then
        PinInteriorInMemory(interior)
        RefreshInterior(interior)
    end
end

local doorStates = {}     -- [locationId] = bool unlocked (server-driven)
local vaultBaseline = {}  -- [locationId] = { entity, closedHeading }
local vaultAnim = {}      -- [locationId] = { from, to, startTime, durationMs } (one anim per loc)

local function rlog(fmt, ...)
    if SunsetRobbery.Debug then
        print(('[ROBBERY] ' .. fmt):format(...))
    end
end

-- ── Normal doors (DoorSystem) ──
local function setStoreDoors(loc, unlocked)
    if not loc then return end
    for _, door in ipairs(loc.doors or {}) do
        local model = door.model
        local c = door.coords
        SetStateOfClosestDoorOfType(model, c.x, c.y, c.z, not unlocked, 1.0, false)
        local doorId = joaat(('sunset_rob_%s_%s'):format(loc.id, tostring(model)))
        AddDoorToSystem(doorId, model, c.x, c.y, c.z, false, false, false)
        -- 0 = unlocked (swings freely), 1 = locked. Vault opening is done by
        -- heading rotation below — state 4 would fight the animation.
        DoorSystemSetDoorState(doorId, unlocked and 0 or 1, false, false)
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, 2.2, model, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            SetEntityCollision(obj, true, true)
        end
    end
end

-- ── Vault entity lookup + baseline ──
local VAULT_MODEL_CANDIDATES = {
    `v_ilev_gb_vauldr`,
    `v_ilev_gb_vauldoor`,
    `v_ilev_bk_vaultdoor`,
    2121050683,
    1809936997,
    763497189,
}

local function findVaultEntity(loc)
    local vault = loc.vault
    if not vault then return nil end
    local c = vault.coords
    local radius = vault.searchRadius or 6.0

    -- 1. Try configured model first, then candidate hashes
    local modelsToTry = { vault.model }
    for _, m in ipairs(VAULT_MODEL_CANDIDATES) do
        if m ~= vault.model then modelsToTry[#modelsToTry + 1] = m end
    end

    for _, model in ipairs(modelsToTry) do
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, radius, model, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then return obj end
    end

    -- 2. Fallback: scan game CObject pool near vault coords
    for _, ent in ipairs(GetGamePool('CObject') or {}) do
        if DoesEntityExist(ent) then
            local em = GetEntityModel(ent)
            for _, model in ipairs(modelsToTry) do
                if em == model then
                    local ec = GetEntityCoords(ent)
                    if #(ec - c) <= radius + 3.0 then
                        return ent
                    end
                end
            end
        end
    end

    return nil
end

local function setVaultHeading(entity, heading)
    if not DoesEntityExist(entity) then return end
    SetEntityHeading(entity, heading)
    SetEntityRotation(entity, 0.0, 0.0, heading, 2, true)
    FreezeEntityPosition(entity, true)
end

-- Capture the CLOSED heading baseline. If closedHeading is configured, use it;
-- otherwise capture from the entity if available.
local function ensureBaseline(loc)
    local id = loc.id
    local known = vaultBaseline[id]
    if known and DoesEntityExist(known.entity) then return known end
    if known then vaultBaseline[id] = nil end -- entity went away (map reload)
    local entity = findVaultEntity(loc)
    if not entity then return nil end
    local closedHeading = (loc.vault and loc.vault.closedHeading)
    if not closedHeading then
        if doorStates[id] == true then
            closedHeading = GetEntityHeading(entity) - (loc.vault and loc.vault.openDelta or -90.0)
        else
            closedHeading = GetEntityHeading(entity)
        end
    end
    vaultBaseline[id] = { entity = entity, closedHeading = closedHeading }
    rlog('vault baseline loc=%s entity=%d closedHeading=%.2f', id, entity, closedHeading)
    return vaultBaseline[id]
end

local function animateVault(loc, open)
    local id = loc.id
    local vault = loc.vault
    if not vault then return end
    local base = ensureBaseline(loc)
    if not base then
        rlog('ERROR vault entity not found loc=%s coords=(%.2f,%.2f,%.2f) model=%s',
            id, vault.coords.x, vault.coords.y, vault.coords.z, tostring(vault.model))
        return
    end
    local target = open and (base.closedHeading + (vault.openDelta or -90.0)) or base.closedHeading
    vaultAnim[id] = {
        entity = base.entity,
        from = GetEntityHeading(base.entity),
        to = target,
        startTime = GetGameTimer(),
        durationMs = math.max(200, open and (vault.openMs or 2500) or (vault.closeMs or 2000)),
    }
    rlog('vault state loc=%s %s -> %s heading %.1f -> %.1f', id,
        open and 'CLOSED' or 'OPEN', open and 'OPENING' or 'CLOSING',
        vaultAnim[id].from, target)
end

-- Smooth animation ticker (only runs while an animation is active)
CreateThread(function()
    while true do
        local anyActive = false
        for id, anim in pairs(vaultAnim) do
            if DoesEntityExist(anim.entity) then
                local t = (GetGameTimer() - anim.startTime) / anim.durationMs
                if t >= 1.0 then
                    setVaultHeading(anim.entity, anim.to)
                    vaultAnim[id] = nil
                    rlog('vault anim done loc=%s heading=%.1f', id, anim.to)
                else
                    anyActive = true
                    -- ease-out cubic: heavy vault door decelerates into place
                    local eased = 1.0 - ((1.0 - t) ^ 3)
                    local cur = anim.from + (anim.to - anim.from) * eased
                    setVaultHeading(anim.entity, cur)
                end
            else
                vaultAnim[id] = nil
            end
        end
        Wait(anyActive and 0 or 300)
    end
end)

-- ── Server → client door state ──
local function applyDoorState(locationId, unlocked, instant)
    local loc = SunsetRobbery.Locations[tostring(locationId or '')]
    if not loc then return end
    unlocked = unlocked == true
    local prev = doorStates[loc.id] == true
    doorStates[loc.id] = unlocked
    setStoreDoors(loc, unlocked)
    if loc.vault and (unlocked ~= prev or instant) then
        if instant then
            -- Late join / reconnect / sync: snap without animation
            local base = ensureBaseline(loc)
            if base and DoesEntityExist(base.entity) then
                local vault = loc.vault
                local target = unlocked and (base.closedHeading + (vault.openDelta or -90.0)) or base.closedHeading
                SetEntityHeading(base.entity, target)
                FreezeEntityPosition(base.entity, true)
            end
        else
            animateVault(loc, unlocked)
        end
    end
end

RegisterNetEvent('sunset:robbery:doorState', function(locationId, unlocked)
    applyDoorState(locationId, unlocked, false)
end)

-- ── Late-join / boot sync: ask the server which locations are unlocked ──
local function syncDoorStates()
    CreateThread(function()
        local states = Sunset.AwaitCallback('sunset:robbery:doorSync')
        if type(states) ~= 'table' then return end
        for locationId, unlocked in pairs(states) do
            applyDoorState(locationId, unlocked == true, true)
        end
        rlog('door sync applied (%d locations)', (function()
            local n = 0 for _ in pairs(states) do n = n + 1 end return n
        end)())
    end)
end

CreateThread(function()
    prepareJewelryInterior()
    -- Capture baselines while everything is still locked, then sync state.
    Wait(2000)
    for _, loc in pairs(SunsetRobbery.Locations or {}) do
        if loc.vault then ensureBaseline(loc) end
    end
    syncDoorStates()
end)

RegisterNetEvent('sunset:client:playerSpawned', function()
    syncDoorStates()
end)

-- ── Periodic DoorSystem + Vault refresh (keeps lock/heading state sticky vs GTA map streaming) ──
CreateThread(function()
    while true do
        for _, loc in pairs(SunsetRobbery.Locations or {}) do
            if loc.doors and #loc.doors > 0 then
                setStoreDoors(loc, doorStates[loc.id] == true)
            end
            if loc.vault and not vaultAnim[loc.id] then
                local base = ensureBaseline(loc)
                if base and DoesEntityExist(base.entity) then
                    local targetHeading = (doorStates[loc.id] == true)
                        and (base.closedHeading + (loc.vault.openDelta or -90.0))
                        or base.closedHeading
                    local curHeading = GetEntityHeading(base.entity)
                    if math.abs(curHeading - targetHeading) > 0.5 then
                        SetEntityHeading(base.entity, targetHeading)
                        FreezeEntityPosition(base.entity, true)
                    end
                end
            end
        end
        Wait(1500)
    end
end)

-- ── Resource stop: restore closed heading so no rotated door is left ──
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id, base in pairs(vaultBaseline) do
        if DoesEntityExist(base.entity) then
            SetEntityHeading(base.entity, base.closedHeading)
        end
        vaultBaseline[id] = nil
    end
    vaultAnim = {}
end)

-- ── Dev inspection: /robdoor — real world-object inspector ──
-- Usage: /robdoor [radius]   (default 5m, max 30m)
-- Scans ALL streamed CObjects within radius, prints full entity details,
-- highlights likely door candidates, then verifies configured robbery doors.
RegisterCommand('robdoor', function(source, args)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local radius = math.min(30.0, math.max(1.0, tonumber(args[1]) or 5.0))

    print(('^3[ROBDOOR]^7 player=(%.2f, %.2f, %.2f) heading=%.2f'):format(pos.x, pos.y, pos.z, GetEntityHeading(ped)))
    print(('^3[ROBDOOR]^7 scanning CObjects within %.1fm...'):format(radius))

    -- ── Section 1: Raw nearby CObject scan ──
    local nearby = {}
    for _, ent in ipairs(GetGamePool('CObject') or {}) do
        if DoesEntityExist(ent) then
            local ec = GetEntityCoords(ent)
            local dist = #(ec - pos)
            if dist <= radius then
                nearby[#nearby + 1] = {
                    ent = ent,
                    model = GetEntityModel(ent),
                    x = ec.x, y = ec.y, z = ec.z,
                    heading = GetEntityHeading(ent),
                    dist = dist,
                    collision = not GetEntityCollisionDisabled(ent),
                    frozen = IsEntityPositionFrozen(ent),
                    networked = NetworkGetEntityIsNetworked(ent),
                    netId = NetworkGetNetworkIdFromEntity(ent),
                }
            end
        end
    end
    -- Sort by distance ascending
    table.sort(nearby, function(a, b) return a.dist < b.dist end)

    if #nearby == 0 then
        print('^3[ROBDOOR]^7 no CObjects found within radius')
    else
        print(('^3[ROBDOOR]^7 nearby CObjects within %.1fm: %d found'):format(radius, #nearby))
        for _, o in ipairs(nearby) do
            -- Highlight likely door candidates: close to any configured door/vault coords
            local candidate = ''
            for _, loc in pairs(SunsetRobbery.Locations or {}) do
                for _, door in ipairs(loc.doors or {}) do
                    local dc = door.coords
                    local dToConfig = math.sqrt((o.x - dc.x)^2 + (o.y - dc.y)^2 + (o.z - dc.z)^2)
                    if dToConfig < 2.0 then
                        candidate = (' ^2POSSIBLE_MATCH(%s, %.2fm from config)^7'):format(loc.id, dToConfig)
                    end
                end
                if loc.vault then
                    local vc = loc.vault.coords
                    local dToVault = math.sqrt((o.x - vc.x)^2 + (o.y - vc.y)^2 + (o.z - vc.z)^2)
                    if dToVault < 2.0 then
                        candidate = (' ^2POSSIBLE_MATCH(%s vault, %.2fm from config)^7'):format(loc.id, dToVault)
                    end
                end
            end
            print(('^3[ROBDOOR]^7 ent=%d model=%d pos=(%.2f,%.2f,%.2f) heading=%.1f dist=%.2f collision=%s frozen=%s networked=%s netId=%d%s'):format(
                o.ent, o.model, o.x, o.y, o.z, o.heading, o.dist,
                tostring(o.collision), tostring(o.frozen),
                tostring(o.networked), o.netId, candidate))
        end
    end

    -- ── Section 2: Configured robbery door verification ──
    print('^3[ROBDOOR]^7 configured robbery doors:')
    for _, loc in pairs(SunsetRobbery.Locations or {}) do
        for _, door in ipairs(loc.doors or {}) do
            local c = door.coords
            local obj = GetClosestObjectOfType(c.x, c.y, c.z, 5.0, door.model, false, false, false)
            if obj ~= 0 and DoesEntityExist(obj) then
                local ec = GetEntityCoords(obj)
                print(('^3[ROBDOOR]^7 loc=%s model=%d FOUND ent=%d pos=(%.2f,%.2f,%.2f) heading=%.2f dist=%.2f collision=%s frozen=%s networked=%s netId=%d unlocked=%s'):format(
                    loc.id, door.model, obj, ec.x, ec.y, ec.z,
                    GetEntityHeading(obj), #(pos - ec),
                    tostring(not GetEntityCollisionDisabled(obj)), tostring(IsEntityPositionFrozen(obj)),
                    tostring(NetworkGetEntityIsNetworked(obj)), NetworkGetNetworkIdFromEntity(obj),
                    tostring(doorStates[loc.id] == true)))
            else
                print(('^3[ROBDOOR]^7 loc=%s model=%d NOT FOUND near (%.2f,%.2f,%.2f) — inspect nearby CObjects above'):format(
                    loc.id, door.model, c.x, c.y, c.z))
            end
        end
        local base = loc.vault and vaultBaseline[loc.id]
        if base then
            print(('^3[ROBDOOR]^7 loc=%s VAULT baseline closedHeading=%.2f entity=%d'):format(
                loc.id, base.closedHeading, base.entity))
        end
    end
end, false)

RegisterCommand('testvault', function(source, args)
    local action = string.lower(tostring(args[1] or 'open'))
    local open = action ~= 'close'
    local loc = SunsetRobbery.Locations['fleeca_legion']
    if loc and loc.vault then
        applyDoorState('fleeca_legion', open, false)
        print(('^2[TESTVAULT]^7 fleeca_legion door state -> %s'):format(open and 'OPEN' or 'CLOSED'))
    end
end, false)

