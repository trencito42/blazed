-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (client/sampler.lua)
--  1 Hz telemetry batch — ONE TriggerServerEvent per tick (spec §10).
--  Client data is ADVISORY only; the server corroborates with its own
--  state (spec §1.5). Keep this file tiny and allocation-light.
--  Also carries the rotating heartbeat nonce (§4.14): server sends a
--  nonce in every tickAck; we echo it back on the next tick.
-- ═══════════════════════════════════════════════════════════════

local lastNonce = 0
local lastZ = nil
local frameTimeSum = 0.0
local frameTimeCount = 0

RegisterNetEvent('sunset:anticheat:tickAck', function(nonce)
    lastNonce = tonumber(nonce) or 0
end)

CreateThread(function()
    while true do
        Wait(1000)

        -- FPS estimate via GetFrameTime rolling average (cheap, no hooks).
        local ft = GetFrameTime()
        if ft and ft > 0.0 then
            frameTimeSum = frameTimeSum + ft
            frameTimeCount = frameTimeCount + 1
        end
        local fps = 0
        if frameTimeCount >= 10 then
            local avg = frameTimeSum / frameTimeCount
            if avg > 0.0 then fps = math.floor(1.0 / avg + 0.5) end
            frameTimeSum = 0.0
            frameTimeCount = 0
        end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local target = (veh ~= 0) and veh or ped
        local speed = GetEntitySpeed(target) or 0.0
        local coords = GetEntityCoords(ped)

        -- Z velocity: delta against previous sample position.
        local zVel = 0.0
        if lastZ then zVel = coords.z - lastZ end
        lastZ = coords.z

        local parachuteState = 0
        local okParachute, state = pcall(GetPedParachuteState, ped)
        if okParachute and type(state) == 'number' then parachuteState = state end

        local nonce = lastNonce
        lastNonce = 0
        TriggerServerEvent('sunset:anticheat:clientTick', {
            nonce = nonce,
            speed = speed,
            zVel = zVel,
            falling = IsPedFalling(ped),
            inVehicle = IsPedInAnyVehicle(ped, false),
            swimming = IsPedSwimming(ped),
            ragdoll = IsPedRagdoll(ped),
            parachute = parachuteState,
            health = GetEntityHealth(ped),
            armour = GetPedArmour(ped),
            weapon = GetSelectedPedWeapon(ped),
            fps = fps,
        })
    end
end)
