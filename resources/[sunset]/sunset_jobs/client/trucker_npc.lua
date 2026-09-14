-- sunset_jobs · client/trucker_npc.lua
-- NPC dispatcher (visual/tooltip only) and laptop job selector.

local JC = Sunset.JobClient

local NPC_COORDS      = vector4(1200.59, -3107.89, 6.03, 312.11)
local NPC_PROMPT_DIST = 4.5
local LAPTOP_COORDS   = vector4(1207.92, -3114.87, 5.54, 259.54)
local LAPTOP_DIST     = 2.5
local INTERACT_KEY    = 38   -- E

local truckerNpc        = nil
local laptopOpen        = false
local npcUnlockAt       = 0
local npcTooltipVisible = false

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
        desc       = 'Use the laptop nearby to pick a route',
    })
    npcTooltipVisible = shown == true
end

local function hideNpcTooltip()
    if not npcTooltipVisible then return end
    npcTooltipVisible = false
    worldHideTooltip('trucker_dispatcher')
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

-- ── Proximity loop (tooltip + laptop marker) ──────────────────

CreateThread(function()
    while true do
        local pos     = GetEntityCoords(PlayerPedId())
        local npcPos  = vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
        local lapPos  = vector3(LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z)
        local distNpc = (truckerNpc and DoesEntityExist(truckerNpc)) and #(pos - npcPos) or 999
        local distLap = #(pos - lapPos)
        local nearNpc = distNpc < NPC_PROMPT_DIST
        local nearLap = distLap < LAPTOP_DIST

        if nearNpc and not laptopOpen then
            showNpcTooltip()
        else
            hideNpcTooltip()
        end

        if nearLap then
            DrawMarker(2,
                LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.35, 0.35, 0.25,
                255, 140, 0, 180,
                false, false, 2, false, nil, nil, false)
            if not laptopOpen then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ — Open Laptop')
                EndTextCommandDisplayHelp(0, false, true, 100)
            end
        end

        Wait((nearNpc or nearLap) and 0 or 300)
    end
end)

-- ── E key — open laptop ───────────────────────────────────────

CreateThread(function()
    while true do
        local pos    = GetEntityCoords(PlayerPedId())
        local lapPos = vector3(LAPTOP_COORDS.x, LAPTOP_COORDS.y, LAPTOP_COORDS.z)
        local nearLap = #(pos - lapPos) < LAPTOP_DIST

        if nearLap and GetGameTimer() >= npcUnlockAt and not IsNuiFocused() and not IsPauseMenuActive() then
            DisableControlAction(0, INTERACT_KEY, true)
            if not laptopOpen and IsDisabledControlJustReleased(0, INTERACT_KEY) then
                laptopOpen = true
                CreateThread(function()
                    local rankData  = Sunset.AwaitCallback('sunset:jobs:trucker:getRank')
                    local routeData = Sunset.AwaitCallback('sunset:jobs:trucker:getRoutes')
                    exports.sunset_ui:Send('truckerLaptopOpen', {
                        rank   = (rankData and rankData.level)  or 1,
                        xp     = (rankData and rankData.xp)     or 0,
                        xpNext = (rankData and rankData.xpNext) or 100,
                        routes = routeData or {},
                    })
                    exports.sunset_ui:SetFocus(true, true)
                end)
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

-- ── NUI events ────────────────────────────────────────────────

AddEventHandler('sunset:nui:truckerLaptopClose', function()
    if not laptopOpen then return end
    laptopOpen = false
    exports.sunset_ui:SetFocus(false, false)
    npcUnlockAt = GetGameTimer() + 1500
end)

AddEventHandler('sunset:nui:truckerPickRoute', function(data)
    if not data or not data.routeIndex then return end
    laptopOpen = false
    exports.sunset_ui:SetFocus(false, false)
    npcUnlockAt = GetGameTimer() + 2000

    if Sunset.Jobs and Sunset.Jobs.StartTrucker then
        Sunset.Jobs.StartTrucker(data.routeIndex)
    end
end)
