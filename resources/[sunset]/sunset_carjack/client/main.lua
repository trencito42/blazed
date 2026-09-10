-- ============================================================
--  sunset_carjack  ·  client/main.lua
-- ============================================================

local LOCKPICK_DIST     = 2.5
local NPC_INTERACT_DIST = 3.5

local CHOP_NPCS = {
    { coords = vector4(835.6, -3001.4, 5.9,  270.0), label = 'Samsar Dubios' },
    { coords = vector4(-151.9, -1716.8, 29.3, 90.0),  label = 'Samsar Dubios' },
    { coords = vector4(115.2,  -1947.8, 20.8, 180.0), label = 'Samsar Dubios' },
}

local spawnedNpcs  = {}
local npcBlips     = {}
local nearVehicle  = nil
local nearNpcIdx   = nil
local menuOpen     = nil   -- 'vehicle' | 'npc' | nil
local inCooldown   = false
local hasStolenCar = false

-- ── UI helpers ───────────────────────────────────────────────
local function notify(msg, t) exports.sunset_ui:Notify(msg, t or 'info') end

local function openVehicleMenu(veh)
    local modelHash = GetEntityModel(veh)
    local modelName = 'Vehicul'
    for _, name in ipairs(GetAllVehicleModels and GetAllVehicleModels() or {}) do
        if GetHashKey(name) == modelHash then modelName = name:upper() break end
    end
    exports.sunset_ui:Send('playerInteractionShow', {
        target  = { name = modelName, id = '' },
        actions = {
            { id = 'lockpick_vehicle', label = 'Forteaza usa (Lockpick)', group = 'CIVILIAN' },
        },
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = 'vehicle'
end

local function openNpcMenu(idx)
    exports.sunset_ui:Send('playerInteractionShow', {
        target  = { name = CHOP_NPCS[idx].label, id = '' },
        actions = {
            { id = 'sell_stolen_car', label = 'Vinde masina', group = 'CIVILIAN' },
        },
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = 'npc'
end

local function closeMenu()
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
    menuOpen = nil
end

-- ── Blipuri NPC (apar doar dupa lockpick reusit) ─────────────
local function showNpcBlips()
    for i, npc in ipairs(CHOP_NPCS) do
        if not npcBlips[i] then
            local b = AddBlipForCoord(npc.coords.x, npc.coords.y, npc.coords.z)
            SetBlipSprite(b, 120)
            SetBlipColour(b, 2)
            SetBlipScale(b, 0.85)
            SetBlipAsShortRange(b, false)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(npc.label)
            EndTextCommandSetBlipName(b)
            npcBlips[i] = b
        end
    end
end

local function hideNpcBlips()
    for i, b in pairs(npcBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
        npcBlips[i] = nil
    end
end

-- ── Spawn NPC-uri ────────────────────────────────────────────
CreateThread(function()
    local model = GetHashKey('g_m_y_famca_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end
    for i, npc in ipairs(CHOP_NPCS) do
        local ped = CreatePed(4, model,
            npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.coords.w,
            false, true)
        SetEntityAsMissionEntity(ped, true, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SMOKING', 0, true)
        spawnedNpcs[i] = ped
    end
    SetModelAsNoLongerNeeded(model)
end)

-- ── Proximitate ──────────────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 600
        local ped   = PlayerPedId()
        local pos   = GetEntityCoords(ped)

        local prevNpc = nearNpcIdx
        local prevVeh = nearVehicle

        nearNpcIdx = nil
        for i, npc in ipairs(CHOP_NPCS) do
            if spawnedNpcs[i] and DoesEntityExist(spawnedNpcs[i]) then
                if #(pos - vector3(npc.coords.x, npc.coords.y, npc.coords.z)) < NPC_INTERACT_DIST then
                    nearNpcIdx = i
                    sleep = 0
                    break
                end
            end
        end

        nearVehicle = nil
        if not nearNpcIdx then
            local bestDist = LOCKPICK_DIST
            for _, v in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(v) and not IsEntityDead(v) then
                    if GetPedInVehicleSeat(v, -1) == 0 then
                        local d = #(pos - GetEntityCoords(v))
                        if d < bestDist then bestDist = d; nearVehicle = v end
                    end
                end
            end
            if nearVehicle then sleep = 0 end
        end

        -- Inchide meniu daca ne-am mutat
        if menuOpen then
            if menuOpen == 'vehicle' and nearVehicle ~= prevVeh then closeMenu()
            elseif menuOpen == 'npc' and nearNpcIdx ~= prevNpc then closeMenu() end
        end

        Wait(sleep)
    end
end)

-- ── G key → deschide meniu ───────────────────────────────────
-- Cand suntem langa vehicul sau NPC, blocam G-ul de la sunset_interactions
-- si il gestionam noi cu IsDisabledControlJustPressed
CreateThread(function()
    while true do
        local active = nearVehicle ~= nil or nearNpcIdx ~= nil

        if active then
            -- Blocam G ca sa nu ajunga la sunset_interactions (care ar da "no player nearby")
            DisableControlAction(0, 51, true)

            if IsDisabledControlJustPressed(0, 51) and not inCooldown then
                if nearNpcIdx and menuOpen ~= 'npc' then
                    openNpcMenu(nearNpcIdx)
                elseif nearVehicle and DoesEntityExist(nearVehicle) and menuOpen ~= 'vehicle' then
                    local plate = (GetVehicleNumberPlateText(nearVehicle) or ''):gsub('%s+', ''):upper()
                    if plate ~= '' and Sunset.AwaitCallback('sunset:hasVehicleKeys', plate) then
                        -- Owned / keyed vehicles use the normal vehicle menu, not lockpick.
                    else
                        openVehicleMenu(nearVehicle)
                    end
                end
            end
            Wait(0)
        else
            -- Nimic in apropiere — G merge normal la sunset_interactions
            Wait(200)
        end
    end
end)

-- ── Actiuni NUI ──────────────────────────────────────────────
AddEventHandler('sunset:nui:playerInteractionClose', function()
    if menuOpen then menuOpen = nil end
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not data or not data.action then return end

    if data.action == 'lockpick_vehicle' then
        closeMenu()
        if not nearVehicle or not DoesEntityExist(nearVehicle) then return end
        inCooldown = true
        local ok, err = Sunset.AwaitCallback('sunset:carjack:tryLockpick')
        if ok then
            notify('Usa fortata! Urca repede.', 'success')
            SetPedIntoVehicle(PlayerPedId(), nearVehicle, -1)
            hasStolenCar = true
            showNpcBlips()
        else
            notify(err or 'Lockpick-ul s-a rupt.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'sell_stolen_car' then
        closeMenu()
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh == 0 then notify('Trebuie sa fii in masina ca s-o vinzi.', 'error') return end
        inCooldown = true
        local modelHash = GetEntityModel(veh)
        local modelName = tostring(modelHash)
        for _, name in ipairs(GetAllVehicleModels and GetAllVehicleModels() or {}) do
            if GetHashKey(name) == modelHash then modelName = name break end
        end
        local netId = NetworkGetNetworkIdFromEntity(veh)
        local ok, result = Sunset.AwaitCallback('sunset:carjack:sell', { model = modelName, netId = netId })
        if ok then
            notify(('Vandut! Ai primit $%d cash.'):format(result), 'success')
            SetEntityAsMissionEntity(veh, false, true)
            DeleteVehicle(veh)
            hasStolenCar = false
            hideNpcBlips()
        else
            notify(result or 'Nu s-a putut vinde.', 'error')
        end
        SetTimeout(1500, function() inCooldown = false end)
    end
end)
