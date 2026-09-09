-- ============================================================
--  sunset_carjack  ·  client/main.lua
-- ============================================================

local LOCKPICK_DIST    = 2.5
local NPC_INTERACT_DIST = 3.5

-- Samsari — coordonate verificate în zone dubioase LS
local CHOP_NPCS = {
    { coords = vector4(835.6, -3001.4, 5.9,  270.0), label = 'Samsar Dubios' }, -- Port terminal
    { coords = vector4(-151.9, -1716.8, 29.3, 90.0),  label = 'Samsar Dubios' }, -- Strawberry
    { coords = vector4(115.2,  -1947.8, 20.8, 180.0), label = 'Samsar Dubios' }, -- Davis
}

local spawnedNpcs = {}
local npcBlips    = {}   -- blipuri active spre NPC (apar doar dupa lockpick)
local nearVehicle = nil
local nearNpcIdx  = nil
local inCooldown  = false
local hasStolenCar = false  -- true dupa lockpick reusit → activeaza blipurile

-- ── Helpers ─────────────────────────────────────────────────
local function notify(msg, t) exports.sunset_ui:Notify(msg, t or 'info') end

local function drawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z + 0.9, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ── Blipuri NPC (apar doar dupa lockpick) ───────────────────
local function showNpcBlips()
    for i, npc in ipairs(CHOP_NPCS) do
        if not npcBlips[i] then
            local b = AddBlipForCoord(npc.coords.x, npc.coords.y, npc.coords.z)
            SetBlipSprite(b, 120)       -- masina cu cheie
            SetBlipColour(b, 2)         -- verde
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

-- ── Spawn NPC-uri la start ───────────────────────────────────
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

-- ── Detectie proximitate (mai robusta) ──────────────────────
CreateThread(function()
    while true do
        local sleep = 600
        local ped   = PlayerPedId()
        local pos   = GetEntityCoords(ped)

        -- NPC nearby?
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

        -- Vehicle nearby? (folosim game pool — mai fiabil decat GetClosestVehicle)
        nearVehicle = nil
        if not nearNpcIdx then
            local vehicles = GetGamePool('CVehicle')
            local bestDist = LOCKPICK_DIST
            local bestVeh  = nil
            for _, v in ipairs(vehicles) do
                if DoesEntityExist(v) and not IsEntityDead(v) then
                    -- Ignora daca e in mana unui ped / player
                    local driver = GetPedInVehicleSeat(v, -1)
                    if driver == 0 or driver == PlayerPedId() then
                        -- Nu te propui sa furi propria masina in care esti deja
                        if driver ~= PlayerPedId() then
                            local d = #(pos - GetEntityCoords(v))
                            if d < bestDist then
                                bestDist = d
                                bestVeh  = v
                            end
                        end
                    end
                end
            end
            if bestVeh then
                nearVehicle = bestVeh
                sleep = 0
            end
        end

        Wait(sleep)
    end
end)

-- ── Render prompt + handle G ─────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 500

        -- === Langa NPC ===
        if nearNpcIdx then
            sleep = 0
            local npc = CHOP_NPCS[nearNpcIdx]
            drawText3D(npc.coords.x, npc.coords.y, npc.coords.z,
                       '[G] Vinde masina — ' .. npc.label)

            if IsControlJustPressed(0, 51) and not inCooldown then
                inCooldown = true
                local playerPed = PlayerPedId()
                local veh = GetVehiclePedIsIn(playerPed, false)
                if veh == 0 then
                    notify('Trebuie sa fii in masina ca s-o vinzi.', 'error')
                else
                    local modelHash = GetEntityModel(veh)
                    -- Obtine numele modelului
                    local modelName = tostring(modelHash)
                    local allModels = GetAllVehicleModels and GetAllVehicleModels() or {}
                    for _, name in ipairs(allModels) do
                        if GetHashKey(name) == modelHash then
                            modelName = name
                            break
                        end
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
                end
                SetTimeout(1500, function() inCooldown = false end)
            end

        -- === Langa vehicul ===
        elseif nearVehicle and DoesEntityExist(nearVehicle) then
            sleep = 0
            local vPos = GetEntityCoords(nearVehicle)
            drawText3D(vPos.x, vPos.y, vPos.z, '[G] Incearca sa fortezi usa')

            if IsControlJustPressed(0, 51) and not inCooldown then
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
            end
        end

        Wait(sleep)
    end
end)
