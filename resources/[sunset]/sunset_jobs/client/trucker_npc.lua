-- ============================================================
--  sunset_jobs  ·  client/trucker_npc.lua
--  NPC dispatcher + laptop route selector for the Trucker job
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
local npcHoldStart      = nil
local npcHoldVisual     = false
local npcUnlockAt       = GetGameTimer() + 60000
local HOLD_MS           = 800

local TRUCKER_ROUTES = {
    { id = 'route_food',  label = 'Food Delivery',       desc = 'Pick up food → deliver to the 24/7 in Blaine County',   pickup = vector3(892.15, -3204.55, 5.90),  delivery = vector3(2678.55, 3279.25, 55.24) },
    { id = 'route_fuel',  label = 'Fuel Transport',        desc = 'LS Port → Sandy Shores gas station',                     pickup = vector3(-424.88, -2789.33, 6.0),  delivery = vector3(1701.53, 3757.68, 33.95) },
    { id = 'route_build', label = 'Construction Materials', desc = 'Sandy Shores → Vinewood warehouse',                       pickup = vector3(2747.32, 3472.88, 55.67), delivery = vector3(297.01, 188.41, 103.17) },
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
    npcHoldStart = nil
    if npcHoldVisual then
        npcHoldVisual = false
    end
end

local function hideNpcPrompt()
    if not npcPromptVisible then return end
    npcPromptVisible = false
    npcHoldStart = nil
    npcHoldVisual = false
    if SunsetWorld and SunsetWorld.Npc then
        SunsetWorld.Npc.hideTooltip('trucker_horia')
    end
end

local function sendHoldState(_active)
    -- Hold feedback handled in-game; world tooltip stays visible.
end

local function showNpcPrompt()
    local ped = truckerNpc
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        hideNpcPrompt()
        return
    end
    npcPromptVisible = true
    SunsetWorld.Npc.showTooltip('trucker_horia', ped, {
        badge = 'JOB TRUCKER',
        badgeClass = 'trucker',
        bodyClass = 'trucker',
        icon = 'ph-truck',
        title = 'Horia (Dispatcher)',
        desc = 'Interaction / Trucker Shift',
        key = 'E',
    })
end

-- ── Build NPC menu actions ────────────────────────────────────

local function buildNpcActions()
    local job = getCharJob()
    local actions = {}
    if job ~= 'trucker' then
        actions[#actions + 1] = { id = 'hire_trucker',   label = 'Devino Trucker',  group = 'CIVILIAN' }
    end
    if job == 'trucker' then
        if isTruckerShiftActive() then
            actions[#actions + 1] = { id = 'stop_trucker_shift', label = 'Stop Shift', group = 'TRUCKER' }
        else
            actions[#actions + 1] = { id = 'laptop_info', label = 'Pick a Route (Laptop)', group = 'TRUCKER' }
        end
    end
    return actions
end

-- ── Open menus ────────────────────────────────────────────────

local function openNpcMenu()
    if menuOpen or not interactionsReady() then return end
    local actions = buildNpcActions()
    if #actions == 0 then
        exports.sunset_ui:Notify('You have no actions available at the dispatcher.', 'info')
        return
    end
    exports.sunset_ui:Send('playerInteractionShow', {
        target  = { name = 'Horia (Dispatcher)', id = '' },
        actions = actions,
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = true
end

local function openLaptopMenu()
    if menuOpen or not interactionsReady() then return end
    if getCharJob() ~= 'trucker' then
        exports.sunset_ui:Notify('You must be a Trucker to pick a route.', 'error')
        return
    end
    if isTruckerShiftActive() then
        exports.sunset_ui:Notify('You already have an active shift! Finish it first.', 'info')
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
        target  = { name = 'Dispatcher Laptop', id = '' },
        actions = routeActions,
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = true
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

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
    truckerNpc = CreatePed(4,
        hash,
        NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z,
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

    -- 4 components
    SetPedComponentVariation(truckerNpc, 1, 0,  0, 0)  -- mask: none
    SetPedComponentVariation(truckerNpc, 3, 5,  0, 0)  -- upper body
    SetPedComponentVariation(truckerNpc, 4, 24, 0, 0)  -- lower body
    SetPedComponentVariation(truckerNpc, 6, 24, 0, 0)  -- feet

    -- 2 props
    SetPedPropIndex(truckerNpc, 0, 14, 0, true)  -- hat
    SetPedPropIndex(truckerNpc, 1, 0,  0, true)  -- glasses

    TaskStartScenarioInPlace(truckerNpc, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(hash)

    -- Blip NPC
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
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local distNpc    = truckerNpc and DoesEntityExist(truckerNpc) and #(pos - npcCenter()) or 999
        local distLaptop = #(pos - laptopCenter())
        local nearNpc    = distNpc    < NPC_PROMPT_DIST
        local nearLaptop = distLaptop < LAPTOP_DIST

        -- Auto-close menu when walking away
        if menuOpen and not nearNpc and not nearLaptop then
            closeMenu()
        end

        if nearNpc and not menuOpen then
            if interactionsReady() then
                showNpcPrompt()
            else
                hideNpcPrompt()
            end
        elseif not nearNpc then
            hideNpcPrompt()
        end

        -- Laptop: draw marker
        if nearLaptop then
            DrawMarker(2, LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.35, 0.35, 0.25,
                255, 140, 0, 180,
                false, false, 2, false, nil, nil, false)
        end

        Wait((nearNpc or nearLaptop) and 0 or 300)
    end
end)

-- ── E key handler ─────────────────────────────────────────────

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local distNpc    = truckerNpc and DoesEntityExist(truckerNpc) and #(pos - npcCenter()) or 999
        local distLaptop = #(pos - laptopCenter())
        local nearNpc    = distNpc    < NPC_PROMPT_DIST
        local nearLaptop = distLaptop < LAPTOP_DIST

        if (nearNpc or nearLaptop) and not menuOpen and not inCooldown and interactionsReady() then
            DisableControlAction(0, INTERACT_KEY, true)

            if nearNpc and distNpc < NPC_MENU_DIST then
                -- Hold-to-interact for NPC
                if IsDisabledControlPressed(0, INTERACT_KEY) then
                    if not npcHoldStart then npcHoldStart = GetGameTimer() end
                    local held = GetGameTimer() - npcHoldStart
                    sendHoldState(held > HOLD_MS * 0.3)
                    if held >= HOLD_MS then
                        npcHoldStart = nil
                        sendHoldState(false)
                        hideNpcPrompt()
                        openNpcMenu()
                    end
                else
                    if npcHoldStart then
                        npcHoldStart = nil
                        sendHoldState(false)
                    end
                end
            elseif nearLaptop then
                -- Single press for laptop
                if IsDisabledControlJustPressed(0, INTERACT_KEY) then
                    openLaptopMenu()
                end
            end

            Wait(0)
        else
            npcHoldStart = nil
            sendHoldState(false)
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
    closeMenu()
    armGrace(2000)

    local action = data.action

    -- NPC actions
    if action == 'hire_trucker' then
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:hireJob', 'trucker')
            if ok then
                exports.sunset_ui:Notify('You are now a Trucker! Pick a route from the laptop.', 'success', 8000)
            else
                local errMsg = err or 'Nu a functionat angajarea.'
                if errMsg:find('already work', 1, true) then
                    exports.sunset_ui:Notify('You are already a Trucker! Pick a route from the laptop.', 'info', 6000)
                else
                    exports.sunset_ui:Notify(errMsg, 'error', 6000)
                end
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif action == 'laptop_info' then
        exports.sunset_ui:Notify('Go to the laptop to pick a route.', 'info', 4000)

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

    -- Laptop route actions
    else
        local selectedRoute = nil
        for _, r in ipairs(TRUCKER_ROUTES) do
            if r.id == action then selectedRoute = r break end
        end
        if selectedRoute then
            inCooldown = true
            CreateThread(function()
                -- Store selected route and set GPS to pickup
                exports.sunset_ui:Notify(
                    ('Route selected: %s\nHead to the pickup location!'):format(selectedRoute.label),
                    'success', 7000)
                SetNewWaypoint(selectedRoute.pickup.x, selectedRoute.pickup.y)
                -- TODO: when vehicle spawn is ready, trigger shift start here with selectedRoute.id
                SetTimeout(2000, function() inCooldown = false end)
            end)
        end
    end
end)
