-- ============================================================
--  sunset_admintools client — Real-time resmon & lag profiler.
--  Responds to the server 'sampler' request by measuring this
--  client for N seconds and reporting aggregate metrics.
--  Only runs when asked (no permanent loop -> zero idle cost).
-- ============================================================

local measuring = false

local function resourceMs()
    -- GetGameTimer-based approximation of script time is not exposed to Lua;
    -- use GetResourceState count + entity pool sizes as the observable proxy
    -- and the real per-frame cost via a Wait(0) delta measurement.
    local t0 = GetGameTimer()
    local frameDeltas = {}
    local samples = 0
    return function()
        local t1 = GetGameTimer()
        frameDeltas[#frameDeltas + 1] = (t1 - t0)
        t0 = t1
        samples = samples + 1
        local total = 0
        for _, d in ipairs(frameDeltas) do total = total + d end
        local avgFrame = samples > 0 and (total / samples) or 16.7
        local fps = avgFrame > 0 and math.floor(1000 / avgFrame + 0.5) or 0
        return fps, avgFrame
    end
end

RegisterNetEvent('sunset:admintools:sampler', function(seconds)
    if measuring then return end
    measuring = true
    seconds = math.min(30, math.max(3, tonumber(seconds) or 5))
    CreateThread(function()
        local fpsFn = resourceMs()
        local deadline = GetGameTimer() + (seconds * 1000)
        local fps = 0
        while GetGameTimer() < deadline do
            fps = fpsFn()
            Wait(0)
        end
        local vehs, peds, objs = 0, 0, 0
        for _ in ipairs(GetGamePool('CVehicle')) do vehs = vehs + 1 end
        for _ in ipairs(GetGamePool('CPed')) do peds = peds + 1 end
        for _ in ipairs(GetGamePool('CObject')) do objs = objs + 1 end
        local ents = vehs + peds + objs

        -- resmon proxy: sum of per-frame Wait(0) budget used is not available;
        -- report entity load + fps which are the observable lag drivers.
        TriggerServerEvent('sunset:admintools:report', {
            resmon = ents,       -- entity count as the "load" metric
            entities = ents,
            vehicles = vehs,
            peds = peds,
            objects = objs,
            fps = fps,
        })
        measuring = false
    end)
end)
