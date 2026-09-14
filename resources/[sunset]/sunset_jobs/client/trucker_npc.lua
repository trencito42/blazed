-- sunset_jobs · client/trucker_npc.lua
-- Dispatcher NPC + laptop route selector.
-- NPC interaction mirrors sunset_fishingshop (Billy Ray) exactly.

local JC = Sunset.JobClient

local NPC_COORDS      = vector4(1200.59, -3107.89, 6.03, 312.11)
local NPC_PROMPT_DIST = 4.5
local NPC_MENU_DIST   = 2.15
local LAPTOP_COORDS   = vector4(1207.92, -3114.87, 5.54, 259.54)
local LAPTOP_DIST     = 2.5
local INTERACT_KEY    = 38   -- E

local truckerNpc          = nil
local nearNpc             = false
local nearLaptop          = false
local npcMenuOpen         = false
local laptopOpen          = false
local inCooldown          = false
local npcMenuCloseArmed   = false
local npcTooltipVisible   = false
local truckerUnlockAt     = 0   -- 0 = unlocked immediately (no 60s dead-zone bug)

local TRUCKER_ACTIONS = {
    hire_trucker       = true,
    start_trucker_shift = true,
    end_trucker_shift  = true,
}

-- ── Helpers ───────────────────────────────────────────────────

local function npcCenter()
    return vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
end

local function laptopCenter()
    return vector3(LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z)
end

local function truckerInteractionsReady()
    if GetGameTimer() < truckerUnlockAt then return false end
    if not NetworkIsPlayerActive(PlayerId()) then return false end
    if IsNuiFocused() or IsPauseMenuActive() then return false end
    return true
end

local function armGrace(ms)
    truckerUnlockAt = GetGameTimer() + (ms or 3000)
end

-- ── Cross-resource tooltip helpers ────────────────────────────

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

-- ── NPC tooltip ───────────────────────────────────────────────

local function showNpcTooltip()
    if not truckerNpc or not DoesEntityExist(truckerNpc) then return end
    local shown = worldShowTooltip('trucker_dispatcher', truckerNpc, {
        badge      = 'TRUCKER JOB',
        badgeClass = 'trucker',
        icon       = 'ph-truck',
        title      = 'Dispatcher',
        desc       = 'Interaction / Trucker Job',
        key        = 'E',
    })
    npcTooltipVisible = shown == true
    if not shown then
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ — Dispatcher')
        EndTextCommandDisplayHelp(0, false, true, 100)
    end
end

local function hideNpcTooltip()
    if not npcTooltipVisible then return end
    npcTooltipVisible = false
    worldHideTooltip('trucker_dispatcher')
end

-- ── Close menus ───────────────────────────────────────────────

local function closeNpcMenu()
    if not npcMenuOpen then return end
    npcMenuOpen = false
    npcMenuCloseArmed = false
    hideNpcTooltip()
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

-- ── Open laptop UI ────────────────────────────────────────────

local function openLaptopUi()
    if laptopOpen then return end
    laptopOpen = true
    CreateThread(function()
        local rankData  = Sunset.AwaitCallback('sunset:jobs:trucker:getRank')
        local routeData = Sunset.AwaitCallback('sunset:jobs:trucker:getRoutes')
        exports.sunset_ui:Send('truckerLaptopOpen', {
            rank   = (rankData and rankData.level)  or 1,
            xp     = (rankData and rankData.xp)     or 0,
            xpNext = (rankData and rankData.xpNext) or 300,
            routes = routeData or {},
        })
        exports.sunset_ui:SetFocus(true, true)
    end)
end

-- ── Open NPC menu ─────────────────────────────────────────────

local function openTruckerNpcMenu()
    if npcMenuOpen or not truckerInteractionsReady() then return end
    CreateThread(function()
        local data, err = Sunset.AwaitCallback('sunset:jobs:trucker:getNpcMenu')
        if not data then
            if err then exports.sunset_ui:Notify(err, 'error', 5000) end
            return
        end
        if npcMenuOpen or not truckerInteractionsReady() then return end

        local actions = {}
        if data.job ~= 'trucker' then
            actions[#actions + 1] = { id = 'hire_trucker', label = 'Become a Trucker', group = 'CIVILIAN' }
        end
        if data.job == 'trucker' then
            if data.onShift then
                actions[#actions + 1] = { id = 'end_trucker_shift', label = 'End Shift', group = 'TRUCKER' }
            else
                actions[#actions + 1] = { id = 'start_trucker_shift', label = 'Start Shift', group = 'TRUCKER' }
            end
        end
        if #actions == 0 then return end

        npcMenuCloseArmed = false
        hideNpcTooltip()
        exports.sunset_ui:Send('playerInteractionShow', {
            menuTitle = 'Trucker Actions',
            target    = { name = 'Dispatcher', id = '' },
            actions   = actions,
        })
        exports.sunset_ui:SetFocus(true, true)
        npcMenuOpen = true
    end)
end

-- ── Reset on spawn / character flow ──────────────────────────

local function resetTruckerUiOnEntry()
    armGrace(3500)
    npcMenuOpen     = false
    laptopOpen      = false
    inCooldown      = false
    npcMenuCloseArmed = false
    hideNpcTooltip()
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
    -- Subtract 1.0 from z so the NPC stands on the ground at the correct height.
    truckerNpc = CreatePed(4,
        hash,
        NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z - 1.0,
        NPC_COORDS.w,
        false, true)
    if not truckerNpc or not DoesEntityExist(truckerNpc) then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    SetEntityAsMissionEntity(truckerNpc, true, true)
    FreezeEntityPosition(truckerNpc, true)
    SetEntityInvincible(truckerNpc, true)
    SetBlockingOfNonTemporaryEvents(truckerNpc, true)
    SetEntityCanBeDamaged(truckerNpc, false)
    SetPedCanRagdoll(truckerNpc, false)
    SetPedComponentVariation(truckerNpc, 3, 5,  0, 0)
    SetPedComponentVariation(truckerNpc, 4, 24, 0, 0)
    SetPedComponentVariation(truckerNpc, 6, 24, 0, 0)
    SetPedPropIndex(truckerNpc, 0, 14, 0, true)
    TaskStartScenarioInPlace(truckerNpc, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(hash)

    local blip = AddBlipForCoord(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
    SetBlipSprite(blip, 477)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Trucker Dispatcher')
    EndTextCommandSetBlipName(blip)
end)

-- ── Proximity loop (tooltip + laptop marker + auto-close) ─────

CreateThread(function()
    while true do
        local pos   = GetEntityCoords(PlayerPedId())
        local dNpc  = (truckerNpc and DoesEntityExist(truckerNpc)) and #(pos - npcCenter()) or 999
        local dLap  = #(pos - laptopCenter())
        local wasNpc = nearNpc
        nearNpc     = dNpc  < NPC_PROMPT_DIST
        nearLaptop  = dLap  < LAPTOP_DIST

        -- Auto-close NPC menu when walking away
        if wasNpc and not nearNpc and npcMenuOpen then
            closeNpcMenu()
        end

        -- NPC tooltip (mirrors fisherman shouldShowBillyRayPrompt)
        if nearNpc and truckerInteractionsReady() and not npcMenuOpen and not laptopOpen then
            showNpcTooltip()
        else
            hideNpcTooltip()
        end

        -- Laptop marker + native help
        if nearLaptop then
            DrawMarker(2,
                LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.35, 0.35, 0.25,
                255, 140, 0, 180,
                false, false, 2, false, nil, nil, false)
            if not laptopOpen and not npcMenuOpen then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ — Route Laptop')
                EndTextCommandDisplayHelp(0, false, true, 100)
            end
        end

        Wait((nearNpc or nearLaptop) and 0 or 350)
    end
end)

-- ── E key handler ─────────────────────────────────────────────

CreateThread(function()
    while true do
        if nearNpc or nearLaptop then
            DisableControlAction(0, INTERACT_KEY, true)
            local pos = GetEntityCoords(PlayerPedId())

            -- ── NPC zone ──────────────────────────────────────
            if nearNpc then
                if npcMenuOpen then
                    -- Close on next press after first release (mirrors Billy Ray)
                    if IsDisabledControlJustPressed(0, INTERACT_KEY) and npcMenuCloseArmed then
                        closeNpcMenu()
                    end
                    if IsDisabledControlJustReleased(0, INTERACT_KEY) then
                        npcMenuCloseArmed = true
                    end
                elseif truckerInteractionsReady() and not inCooldown and not laptopOpen then
                    -- Simple press — matches Billy Ray (no hold required)
                    if #(pos - npcCenter()) < NPC_MENU_DIST and IsDisabledControlJustReleased(0, INTERACT_KEY) then
                        openTruckerNpcMenu()
                    end
                end
            end

            -- ── Laptop zone (only when not at NPC and no menu open) ──
            if nearLaptop and not nearNpc and not laptopOpen and not npcMenuOpen
               and not inCooldown and truckerInteractionsReady() then
                if IsDisabledControlJustReleased(0, INTERACT_KEY) then
                    openLaptopUi()
                end
            end

            Wait(0)
        else
            npcMenuCloseArmed = false
            Wait(200)
        end
    end
end)

-- ── NUI events ────────────────────────────────────────────────

-- playerInteraction menu closed (ESC or backdrop click)
AddEventHandler('sunset:nui:playerInteractionClose', function()
    if not npcMenuOpen then return end
    closeNpcMenu()
    armGrace(1500)
end)

-- playerInteraction action selected
AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not data or not data.action then return end
    if not TRUCKER_ACTIONS[data.action] then return end   -- ignore other resources' menus
    if not npcMenuOpen then return end

    local action = data.action
    closeNpcMenu()
    armGrace(2000)

    if action == 'hire_trucker' then
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:hireJob', 'trucker')
            if ok then
                exports.sunset_ui:Notify('You are now a Trucker! Use the laptop to pick a route.', 'success', 8000)
            else
                local msg = err or 'Hiring failed.'
                if msg:find('already work', 1, true) or msg:find('already', 1, true) then
                    exports.sunset_ui:Notify('You are already a Trucker! Use the laptop to pick a route.', 'info', 6000)
                else
                    exports.sunset_ui:Notify(msg, 'error', 6000)
                end
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif action == 'start_trucker_shift' then
        -- Opens the laptop UI directly from the NPC menu
        openLaptopUi()

    elseif action == 'end_trucker_shift' then
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:jobs:cancelWork')
            if ok then
                if JC then JC.cleanup() ; JC.hideObjective() end
                exports.sunset_ui:Notify('Shift cancelled.', 'info', 4000)
            else
                exports.sunset_ui:Notify(err or 'Could not cancel shift.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)
    end
end)

-- Laptop close (ESC or js call)
AddEventHandler('sunset:nui:truckerLaptopClose', function()
    if not laptopOpen then return end
    laptopOpen = false
    exports.sunset_ui:SetFocus(false, false)
    armGrace(1500)
end)

-- Route picked from laptop
AddEventHandler('sunset:nui:truckerPickRoute', function(data)
    if not data or not data.routeIndex then return end
    laptopOpen = false
    exports.sunset_ui:SetFocus(false, false)
    armGrace(2000)
    if Sunset.Jobs and Sunset.Jobs.StartTrucker then
        Sunset.Jobs.StartTrucker(data.routeIndex)
    end
end)
