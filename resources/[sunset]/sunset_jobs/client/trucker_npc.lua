-- ============================================================
--  sunset_jobs  ·  client/trucker_npc.lua
--  NPC dispatcher + laptop route selector for the Trucker job
--  Visual system mirrors sunset_fishingshop (Billy Ray NPC).
-- ============================================================

local JC = Sunset.JobClient

local NPC_COORDS        = vector4(1200.59, -3107.89, 6.03, 312.11)
local NPC_PROMPT_DIST   = 4.5
local NPC_MENU_DIST     = 2.15
local LAPTOP_COORDS     = vector4(1207.92, -3114.87, 5.54, 259.54)
local LAPTOP_DIST       = 2.5
local INTERACT_KEY      = 38   -- E key

local truckerNpc        = nil
local menuOpen          = false
local inCooldown        = false
local npcPromptVisible  = false
local menuCloseArmed    = false
-- [FIX] Billy Ray starts unlocked (0). Old code used GetGameTimer()+60000 which
-- created a 60-second dead zone right after every resource start / player join.
local npcUnlockAt       = 0

local TRUCKER_ROUTES = {
    { id = 'route_food',  label = 'Food Delivery',          desc = 'Terminal → Blaine County 24/7',            pickup = vector3(892.15, -3204.55, 5.90),  delivery = vector3(2678.55, 3279.25, 55.24) },
    { id = 'route_fuel',  label = 'Fuel Transport',          desc = 'LS Port → Sandy Shores Gas Station',        pickup = vector3(-424.88, -2789.33, 6.0),  delivery = vector3(1701.53, 3757.68, 33.95) },
    { id = 'route_build', label = 'Construction Materials',  desc = 'Sandy Shores → Vinewood Warehouse',         pickup = vector3(2747.32, 3472.88, 55.67), delivery = vector3(297.01, 188.41, 103.17) },
}

-- ── Helpers ───────────────────────────────────────────────────

local function getCharJob()
    local char = Sunset.Character or {}
    return select(1, Sunset.GetCharacterJob(char))
end

local function isTruckerShiftActive()
    return JC.jobId == 'trucker' and JC.state ~= 'IDLE'
end

local function npcCenter()
    return vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
end

local function laptopCenter()
    return vector3(LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z)
end

local function interactionsReady()
    if GetGameTimer() < npcUnlockAt then return false end
    if not NetworkIsPlayerActive(PlayerId()) then return false end
    if IsNuiFocused() or IsPauseMenuActive() then return false end
    return true
end

local function armGrace(ms)
    npcUnlockAt = GetGameTimer() + (ms or 3000)
    menuCloseArmed = false
end

-- ── Cross-resource tooltip helpers ───────────────────────────
-- [FIX] sunset_world Lua globals are NOT visible from this resource
-- (separate script environments). Always use the exports.

local function worldShowTooltip(id, ped, meta)
    if GetResourceState('sunset_world') ~= 'started' then return false end
    local ok, shown = pcall(function()
        return exports.sunset_world:NpcShowTooltip(id, ped, meta)
    end)
    return ok and shown == true
end

local function worldHideTooltip(id)
    if GetResourceState('sunset_world') ~= 'started' then return end
    pcall(function() exports.sunset_world:NpcHideTooltip(id) end)
end

-- ── NPC prompt (world tooltip above head) ────────────────────

local function hideNpcPrompt()
    if not npcPromptVisible then return end
    npcPromptVisible = false
    worldHideTooltip('trucker_dispatcher')
end

local function showNpcPrompt()
    local ped = truckerNpc
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        hideNpcPrompt()
        return
    end
    local shown = worldShowTooltip('trucker_dispatcher', ped, {
        badge      = 'TRUCKER JOB',
        badgeClass = 'trucker',
        bodyClass  = 'trucker',
        icon       = 'ph-truck',
        title      = 'Horia (Dispatcher)',
        desc       = 'Interaction / Trucker Shift',
        key        = 'E',
    })
    npcPromptVisible = shown == true
    if not shown then
        -- Native fallback so the interaction is never silently invisible
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ — Horia (Dispatcher)')
        EndTextCommandDisplayHelp(0, false, true, 100)
    end
end

-- ── Build NPC menu actions ────────────────────────────────────

local function buildNpcActions()
    local job     = getCharJob()
    local actions = {}

    if job ~= 'trucker' then
        actions[#actions + 1] = { id = 'hire_trucker', label = 'Become a Trucker', group = 'CIVILIAN' }
    end

    if job == 'trucker' then
        if isTruckerShiftActive() then
            actions[#actions + 1] = { id = 'stop_trucker_shift', label = 'Stop Shift', group = 'TRUCKER' }
        else
            -- [FIX] "Start Shift" sets a waypoint to the laptop so the player
            -- knows exactly where to go. Route selection happens at the laptop.
            actions[#actions + 1] = { id = 'start_shift', label = 'Start Shift', group = 'TRUCKER' }
        end
    end

    return actions
end

-- ── Open / close menus ────────────────────────────────────────

local function openNpcMenu()
    if menuOpen or not interactionsReady() then return end
    local actions = buildNpcActions()
    if #actions == 0 then
        exports.sunset_ui:Notify('No actions available at the dispatcher.', 'info')
        return
    end
    hideNpcPrompt()
    exports.sunset_ui:Send('playerInteractionShow', {
        menuTitle = 'Trucker Actions',
        target    = { name = 'Horia (Dispatcher)', id = '' },
        actions   = actions,
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen      = true
    menuCloseArmed = false
end

local function openLaptopMenu()
    if menuOpen or not interactionsReady() then return end
    if getCharJob() ~= 'trucker' then
        exports.sunset_ui:Notify('You must be a Trucker to pick a route.', 'error')
        return
    end
    if isTruckerShiftActive() then
        exports.sunset_ui:Notify('You already have an active shift!', 'info')
        return
    end

    local routeActions = {}
    for _, r in ipairs(TRUCKER_ROUTES) do
        routeActions[#routeActions + 1] = {
            id    = r.id,
            label = r.label,
            group = r.desc,
        }
    end
    exports.sunset_ui:Send('playerInteractionShow', {
        menuTitle = 'Select Route',
        target    = { name = 'Dispatcher Laptop', id = '' },
        actions   = routeActions,
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen      = true
    menuCloseArmed = false
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen      = false
    menuCloseArmed = false
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

-- ── Reset on player spawn / character flow ────────────────────
-- Mirrors Billy Ray's resetBillyUiOnEntry so the NPC is ready
-- immediately when the player spawns in.

local function resetTruckerUiOnEntry()
    armGrace(3500)
    menuOpen       = false
    menuCloseArmed = false
    npcPromptVisible = false
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

AddEventHandler('sunset:client:playerSpawned', resetTruckerUiOnEntry)
AddEventHandler('sunset:client:characterFlowComplete', function()
    armGrace(3500)
end)

-- ── Spawn NPC ─────────────────────────────────────────────────

CreateThread(function()
    local hash = GetHashKey('g_m_y_strpunk_02')
    RequestModel(hash)
    local timeout = GetGameTimer() + 20000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(200) end
    if not HasModelLoaded(hash) then
        print('[sunset_jobs] ERR: trucker NPC model failed to load')
        return
    end
    Wait(500)
    -- [FIX] Subtract 1.0 from z so the NPC stands on the ground at the right
    -- height (same correction npc_lib.lua applies via SunsetWorld.Npc.spawn).
    truckerNpc = CreatePed(4,
        hash,
        NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z - 1.0,
        NPC_COORDS.w,
        false, true)
    if not truckerNpc or truckerNpc == 0 or not DoesEntityExist(truckerNpc) then
        print('[sunset_jobs] ERR: trucker NPC CreatePed failed')
        SetModelAsNoLongerNeeded(hash)
        return
    end
    SetEntityAsMissionEntity(truckerNpc, true, true)
    FreezeEntityPosition(truckerNpc, true)
    SetEntityInvincible(truckerNpc, true)
    SetBlockingOfNonTemporaryEvents(truckerNpc, true)
    SetEntityCanBeDamaged(truckerNpc, false)
    SetPedCanRagdoll(truckerNpc, false)

    -- Clothing
    SetPedComponentVariation(truckerNpc, 1, 0,  0, 0)  -- mask: none
    SetPedComponentVariation(truckerNpc, 3, 5,  0, 0)  -- upper body
    SetPedComponentVariation(truckerNpc, 4, 24, 0, 0)  -- lower body
    SetPedComponentVariation(truckerNpc, 6, 24, 0, 0)  -- feet
    SetPedPropIndex(truckerNpc, 0, 14, 0, true)         -- hat
    SetPedPropIndex(truckerNpc, 1, 0,  0, true)         -- glasses

    TaskStartScenarioInPlace(truckerNpc, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(hash)

    -- Blip
    local blip = AddBlipForCoord(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
    SetBlipSprite(blip, 477)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Horia — Trucker Dispatcher')
    EndTextCommandSetBlipName(blip)
end)

-- ── Proximity + prompt loop ───────────────────────────────────

CreateThread(function()
    local nearNpcLast    = false
    local nearLaptopLast = false

    while true do
        local pos        = GetEntityCoords(PlayerPedId())
        local distNpc    = (truckerNpc and DoesEntityExist(truckerNpc)) and #(pos - npcCenter()) or 999
        local distLaptop = #(pos - laptopCenter())
        local nearNpc    = distNpc    < NPC_PROMPT_DIST
        local nearLaptop = distLaptop < LAPTOP_DIST

        -- Auto-close when player walks away
        if menuOpen and not nearNpc and not nearLaptop then
            closeMenu()
        end

        -- NPC tooltip
        if nearNpc and not menuOpen then
            if interactionsReady() then
                showNpcPrompt()
                -- Native fallback (mirrors Billy Ray)
                if not npcPromptVisible then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ — Horia (Dispatcher)')
                    EndTextCommandDisplayHelp(0, false, true, 100)
                end
            else
                hideNpcPrompt()
            end
        elseif not nearNpc then
            hideNpcPrompt()
        end

        -- Laptop marker
        if nearLaptop then
            DrawMarker(2,
                LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.35, 0.35, 0.25,
                255, 140, 0, 180,
                false, false, 2, false, nil, nil, false)
        end

        nearNpcLast    = nearNpc
        nearLaptopLast = nearLaptop
        Wait((nearNpc or nearLaptop) and 0 or 300)
    end
end)

-- ── E key handler (simple press — mirrors Billy Ray) ──────────

CreateThread(function()
    while true do
        local pos        = GetEntityCoords(PlayerPedId())
        local distNpc    = (truckerNpc and DoesEntityExist(truckerNpc)) and #(pos - npcCenter()) or 999
        local distLaptop = #(pos - laptopCenter())
        local nearNpc    = distNpc    < NPC_PROMPT_DIST
        local nearLaptop = distLaptop < LAPTOP_DIST

        if nearNpc or nearLaptop then
            DisableControlAction(0, INTERACT_KEY, true)

            -- NPC (menu open: close on next E; menu closed: open on E release)
            if nearNpc then
                if menuOpen then
                    if IsDisabledControlJustPressed(0, INTERACT_KEY) and menuCloseArmed then
                        closeMenu()
                    end
                    if IsDisabledControlJustReleased(0, INTERACT_KEY) then
                        menuCloseArmed = true
                    end
                elseif interactionsReady() and not inCooldown and distNpc < NPC_MENU_DIST then
                    -- [FIX] Simple press (JustReleased) — matches Billy Ray's UX.
                    -- Old code required holding E for 800ms with no visual feedback.
                    if IsDisabledControlJustReleased(0, INTERACT_KEY) then
                        openNpcMenu()
                    end
                end
            end

            -- Laptop (single press)
            if nearLaptop and not nearNpc and not menuOpen and not inCooldown and interactionsReady() then
                if IsDisabledControlJustPressed(0, INTERACT_KEY) then
                    openLaptopMenu()
                end
            end

            Wait(0)
        else
            menuCloseArmed = false
            Wait(200)
        end
    end
end)

-- ── NUI event handlers ────────────────────────────────────────

AddEventHandler('sunset:nui:playerInteractionClose', function()
    if not menuOpen then return end
    closeMenu()
    armGrace(1500)
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not data or not data.action then return end
    if not menuOpen then return end
    local action = data.action
    closeMenu()
    armGrace(2000)

    -- ── NPC menu actions ──────────────────────────────────────

    if action == 'hire_trucker' then
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:hireJob', 'trucker')
            if ok then
                exports.sunset_ui:Notify(
                    'You are now a Trucker! Come back and press Start Shift.',
                    'success', 8000)
            else
                local msg = err or 'Hiring failed.'
                if msg:find('already work', 1, true) then
                    exports.sunset_ui:Notify(
                        'You are already a Trucker! Press Start Shift to begin.',
                        'info', 6000)
                else
                    exports.sunset_ui:Notify(msg, 'error', 6000)
                end
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif action == 'start_shift' then
        -- [FIX] Place a GPS waypoint to the laptop so the player can find it.
        -- The actual shift/vehicle spawn happens once a route is selected there.
        SetNewWaypoint(LAPTOP_COORDS.x, LAPTOP_COORDS.y)
        exports.sunset_ui:Notify(
            'GPS set to the dispatcher laptop.\nHead there and pick a route to start your shift!',
            'info', 7000)

    elseif action == 'stop_trucker_shift' then
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:jobs:cancelWork')
            if ok then
                JC.cleanup()
                JC.hideObjective()
                exports.sunset_ui:Notify('Shift cancelled.', 'info', 4000)
            else
                exports.sunset_ui:Notify(err or 'Could not cancel the shift.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    -- ── Laptop route selection ────────────────────────────────
    else
        local selectedRoute = nil
        for _, r in ipairs(TRUCKER_ROUTES) do
            if r.id == action then selectedRoute = r; break end
        end

        if selectedRoute then
            inCooldown = true
            CreateThread(function()
                exports.sunset_ui:Notify(
                    ('Route: %s — starting your shift now…'):format(selectedRoute.label),
                    'info', 5000)
                -- Delegate to the full shift-start logic in trucker.lua.
                -- That function spawns the truck, registers vehicles, and sets
                -- the GPS to the pickup (server picks the actual route randomly,
                -- which is fine — the route preview the player saw is cosmetic).
                if Sunset.Jobs and Sunset.Jobs.StartTrucker then
                    Sunset.Jobs.StartTrucker()
                else
                    -- Fallback: just place the GPS and let the player drive there
                    SetNewWaypoint(selectedRoute.pickup.x, selectedRoute.pickup.y)
                    exports.sunset_ui:Notify(
                        'GPS set to pickup. Use /recovertrailer if your trailer detaches.',
                        'success', 8000)
                end
                SetTimeout(2000, function() inCooldown = false end)
            end)
        end
    end
end)
