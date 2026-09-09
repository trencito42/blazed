-- ============================================================
--  sunset_carjack  ·  client/main.lua
--  Lockpick flow + chop-shop NPC selling
-- ============================================================

local LOCKPICK_DIST   = 2.2   -- metres from driver door to show prompt
local NPC_INTERACT_DIST = 3.0 -- metres from NPC to sell

-- NPC samsari (no blip — discovered on foot)
local CHOP_NPCS = {
    { coords = vector4(453.2,  -3002.3, 6.0,  225.0), label = 'Samsar Dubios' },
    { coords = vector4(-147.4, -1718.5, 29.3, 90.0),  label = 'Samsar Dubios' },
    { coords = vector4(112.8,  -1948.4, 20.8, 180.0), label = 'Samsar Dubios' },
}

local spawnedNpcs    = {}
local nearVehicle    = nil   -- entity of nearby vehicle when prompt is active
local nearNpc        = nil   -- index of nearby NPC
local inCooldown     = false -- prevent spam
local stolenNetId    = nil   -- netId of the car we carjacked (set after lockpick)

-- ── Helpers ─────────────────────────────────────────────────

local function notify(msg, t)
    exports.sunset_ui:Notify(msg, t or 'info')
end

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

-- ── Spawn NPCs ───────────────────────────────────────────────
CreateThread(function()
    local model = GetHashKey('g_m_y_famca_01') -- shady street dude
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(50) end

    for i, npc in ipairs(CHOP_NPCS) do
        local ped = CreatePed(4, model, npc.coords.x, npc.coords.y, npc.coords.z - 1.0,
                              npc.coords.w, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        spawnedNpcs[i] = ped
    end
    SetModelAsNoLongerNeeded(model)
end)

-- ── Main proximity loop ──────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 500
        local ped   = PlayerPedId()
        local pos   = GetEntityCoords(ped)

        -- Check nearby NPCs
        nearNpc = nil
        for i, npc in ipairs(CHOP_NPCS) do
            if spawnedNpcs[i] and DoesEntityExist(spawnedNpcs[i]) then
                local d = #(pos - vector3(npc.coords.x, npc.coords.y, npc.coords.z))
                if d < NPC_INTERACT_DIST then
                    nearNpc = i
                    sleep   = 0
                    break
                end
            end
        end

        -- Check nearby unoccupied vehicles (driver door side)
        nearVehicle = nil
        local veh, dist = GetClosestVehicle(pos.x, pos.y, pos.z, LOCKPICK_DIST + 1.0, 0, 70)
        if veh and veh ~= 0 and dist <= LOCKPICK_DIST then
            -- Only if no one is in the driver seat
            if GetPedInVehicleSeat(veh, -1) == 0 then
                nearVehicle = veh
                sleep       = 0
            end
        end

        if sleep > 0 then
            nearVehicle = nil
            nearNpc     = nil
        end

        Wait(sleep)
    end
end)

-- ── Render prompts + handle G key ───────────────────────────
CreateThread(function()
    while true do
        local sleep = 500

        if nearNpc then
            sleep = 0
            local npc = CHOP_NPCS[nearNpc]
            drawText3D(npc.coords.x, npc.coords.y, npc.coords.z, '[G] Vinde masina — ' .. npc.label)

            if IsControlJustPressed(0, 51) and not inCooldown then -- G
                inCooldown = true
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                if veh == 0 then
                    notify('Trebuie sa fii in masina ca s-o vinzi.', 'error')
                else
                    local model  = GetEntityModel(veh)
                    local modelName = ''
                    -- Get model name string from hash
                    for _, name in ipairs(GetAllVehicleModels and GetAllVehicleModels() or {}) do
                        if GetHashKey(name) == model then modelName = name break end
                    end
                    -- Fallback: use hash as string if lookup failed
                    if modelName == '' then modelName = tostring(model) end

                    local netId = NetworkGetNetworkIdFromEntity(veh)
                    local ok, result = Sunset.AwaitCallback('sunset:carjack:sell', { model = modelName, netId = netId })
                    if ok then
                        notify(('Masina vanduta! Ai primit $%d cash.'):format(result), 'success')
                        SetEntityAsMissionEntity(veh, false, true)
                        DeleteEntity(veh)
                        stolenNetId = nil
                    else
                        notify(result or 'Nu s-a putut vinde masina.', 'error')
                    end
                end
                SetTimeout(1500, function() inCooldown = false end)
            end

        elseif nearVehicle then
            sleep = 0
            local veh = nearVehicle
            drawText3D(GetEntityCoords(veh).x, GetEntityCoords(veh).y, GetEntityCoords(veh).z,
                       '[G] Incearca sa fortezi usa')

            if IsControlJustPressed(0, 51) and not inCooldown then -- G
                -- Don't steal if player interaction menu would fire (nearby player)
                -- (sunset_interactions handles that; if no player nearby this is safe)
                inCooldown = true
                local ok, err = Sunset.AwaitCallback('sunset:carjack:tryLockpick')
                if ok then
                    notify('Usa fortata! Urca repede.', 'success')
                    -- Put player in vehicle
                    local ped = PlayerPedId()
                    SetPedIntoVehicle(ped, veh, -1)
                    stolenNetId = NetworkGetNetworkIdFromEntity(veh)
                else
                    notify(err or 'Lockpick-ul s-a rupt.', 'error')
                end
                SetTimeout(2000, function() inCooldown = false end)
            end
        end

        Wait(sleep)
    end
end)
