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
local function findVaultEntity(loc)
    local vault = loc.vault
    if not vault then return nil end
    local c = vault.coords
    local obj = GetClosestObjectOfType(c.x, c.y, c.z, vault.searchRadius or 2.5,
        vault.model, false, false, false)
    if obj ~= 0 and DoesEntityExist(obj) then return obj end
    return nil
end

-- Capture the CLOSED heading baseline only while the door is locked and not
-- animating. First sighting at boot is closed by definition (server state
-- starts locked); re-capture is refused once known so an open heading can
-- never become the baseline.
local function ensureBaseline(loc, allowCapture)
    local id = loc.id
    local known = vaultBaseline[id]
    if known and DoesEntityExist(known.entity) then return known end
    if known then vaultBaseline[id] = nil end -- entity went away (map reload)
    -- New capture only allowed while the door is known-closed (or state
    -- unknown at boot). Never baseline from an unlocked door's heading.
    if allowCapture == false then return nil end
    if doorStates[id] == true then return nil end -- open state — cannot baseline
    local entity = findVaultEntity(loc)
    if not entity then return nil end
    local heading = GetEntityHeading(entity)
    vaultBaseline[id] = { entity = entity, closedHeading = heading }
    rlog('vault baseline loc=%s entity=%d closedHeading=%.2f', id, entity, heading)
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
    local target = open and (base.closedHeading + (vault.openDelta or 90.0)) or base.closedHeading
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
                    SetEntityHeading(anim.entity, anim.to)
                    vaultAnim[id] = nil
                    rlog('vault anim done loc=%s heading=%.1f', id, anim.to)
                else
                    anyActive = true
                    -- ease-out cubic: heavy vault door decelerates into place
                    local eased = 1.0 - ((1.0 - t) ^ 3)
                    SetEntityHeading(anim.entity, anim.from + (anim.to - anim.from) * eased)
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
    -- [ORDER FIX] Capture the closed baseline BEFORE flipping doorStates —
    -- at this moment the physical door is still where the server left it
    -- (closed at boot), so the heading we read now is the closed heading.
    -- Doing it after the flag flip would make ensureBaseline refuse.
    if loc.vault and unlocked and not prev then
        ensureBaseline(loc)
    end
    doorStates[loc.id] = unlocked
    setStoreDoors(loc, unlocked)
    if loc.vault and unlocked ~= prev then
        if instant then
            -- Late join / reconnect: snap without animation
            local base = vaultBaseline[loc.id]
            if base and DoesEntityExist(base.entity) then
                local vault = loc.vault
                SetEntityHeading(base.entity,
                    unlocked and (base.closedHeading + (vault.openDelta or 90.0)) or base.closedHeading)
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

-- ── Periodic DoorSystem refresh (keeps lock state sticky vs other scripts) ──
CreateThread(function()
    while true do
        for _, loc in pairs(SunsetRobbery.Locations or {}) do
            if loc.doors then setStoreDoors(loc, doorStates[loc.id] == true) end
        end
        Wait(2000)
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

-- ── Dev inspection: /robdoor — dump vault/door entities near the player ──
RegisterCommand('robdoor', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    print('^3[ROBDOOR]^7 inspecting entities within 5m of player...')
    for _, loc in pairs(SunsetRobbery.Locations or {}) do
        for _, door in ipairs(loc.doors or {}) do
            local c = door.coords
            local obj = GetClosestObjectOfType(c.x, c.y, c.z, 5.0, door.model, false, false, false)
            if obj ~= 0 and DoesEntityExist(obj) then
                local ec = GetEntityCoords(obj)
                print(('^3[ROBDOOR]^7 loc=%s model=%s ent=%d hash=%d pos=(%.2f,%.2f,%.2f) heading=%.2f dist=%.2f collision=%s frozen=%s networked=%s netId=%d unlocked=%s'):format(
                    loc.id, tostring(door.model), obj, GetEntityModel(obj), ec.x, ec.y, ec.z,
                    GetEntityHeading(obj), #(pos - ec),
                    tostring(GetEntityCollisionEnabled(obj)), tostring(IsEntityPositionFrozen(obj)),
                    tostring(NetworkGetEntityIsNetworked(obj)), NetworkGetNetworkIdFromEntity(obj),
                    tostring(doorStates[loc.id] == true)))
            else
                print(('^3[ROBDOOR]^7 loc=%s model=%s NOT FOUND near (%.2f,%.2f,%.2f)'):format(
                    loc.id, tostring(door.model), c.x, c.y, c.z))
            end
        end
        local base = loc.vault and vaultBaseline[loc.id]
        if base then
            print(('^3[ROBDOOR]^7 loc=%s VAULT baseline closedHeading=%.2f entity=%d'):format(
                loc.id, base.closedHeading, base.entity))
        end
    end
end, false)
