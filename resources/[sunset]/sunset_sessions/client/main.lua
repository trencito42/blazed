-- ============================================================
--  sunset_sessions — client: universal emergency cleanup
--  GAMEPLAY_SESSIONS.md §5. Every activity calls this on ANY
--  exit path so no anim/prop/focus/checkpoint/blip survives.
-- ============================================================

local trackedEntities = {}   -- session-owned props/peds/objects created by activities
local trackedBlips = {}
local trackedCheckpoints = {}
local activeSessionId = nil

-- ------------------------------------------------------------
-- Tracking API (activities register what they spawn)
-- ------------------------------------------------------------
exports('TrackEntity', function(sessionId, entity)
    trackedEntities[entity] = sessionId
end)

exports('TrackBlip', function(sessionId, blip)
    trackedBlips[blip] = sessionId
end)

exports('TrackCheckpoint', function(sessionId, cp)
    trackedCheckpoints[cp] = sessionId
end)

exports('SetActiveSession', function(sessionId)
    activeSessionId = sessionId
end)

local function clearTracked(sessionId)
    for ent, sid in pairs(trackedEntities) do
        if not sessionId or sid == sessionId then
            if DoesEntityExist(ent) then
                SetEntityAsMissionEntity(ent, true, true)
                DeleteEntity(ent)
            end
            trackedEntities[ent] = nil
        end
    end
    for blip, sid in pairs(trackedBlips) do
        if not sessionId or sid == sessionId then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            trackedBlips[blip] = nil
        end
    end
    for cp, sid in pairs(trackedCheckpoints) do
        if not sessionId or sid == sessionId then
            DeleteCheckpoint(cp)
            trackedCheckpoints[cp] = nil
        end
    end
end

-- ------------------------------------------------------------
-- The universal cleanup
-- ------------------------------------------------------------
function EmergencyCleanup(reason)
    local ped = PlayerPedId()

    -- animation / scenario
    ClearPedTasksImmediately(ped)
    ClearPedSecondaryTask(ped)

    -- frozen / invincible / collision
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    SetEntityCollision(ped, true, true)

    -- attached entities (escort, props)
    if IsEntityAttachedToAnyPed(ped) or IsEntityAttached(ped) then
        DetachEntity(ped, true, true)
    end

    -- tracked session entities / blips / checkpoints
    clearTracked(nil)

    -- cameras
    DestroyAllCams(true)
    RenderScriptCams(false, false, 0, true, false)

    -- routing bucket: SetPlayerRoutingBucket is a SERVER-only native — on the
    -- client it is nil ("attempt to call a nil value"). Ask the owning
    -- resources to reset it instead (properties/interiors route via server).
    pcall(function() TriggerServerEvent('sunset:sessions:resetRoutingBucket') end)

    -- NUI: close session modals + force-release focus
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function()
            exports.sunset_ui:Send('sessionForceClose', { reason = reason or 'cleanup' })
            exports.sunset_ui:SetFocus(false, false, false, 'force')
        end)
    end
    -- Clear stale Lua panel flags (menu/properties/factions) so a later
    -- ReleaseFocusUnlessModal is not blocked by panels we just force-hid.
    for _, panel in ipairs({ 'menu', 'properties', 'factionPanel' }) do
        TriggerEvent('sunset:nui:modalSuperseded', panel)
    end
    pcall(function() TriggerEvent('sunset:client:inventoryForceClose') end)
    pcall(function() TriggerEvent('sunset:phone:forceClose') end)

    -- screen effects
    ClearTimecycleModifier()
    AnimpostfxStopAll()
    if IsScreenFadedOut() then DoScreenFadeIn(400) end

    -- controls
    SetPlayerControl(PlayerId(), true, 0)

    activeSessionId = nil
end
exports('EmergencyCleanup', EmergencyCleanup)

-- ------------------------------------------------------------
-- Session lifecycle events from the server
-- ------------------------------------------------------------
RegisterNetEvent('sunset:sessions:started', function(payload)
    activeSessionId = payload and payload.id or nil
end)

RegisterNetEvent('sunset:sessions:stateChanged', function(payload)
    if payload and payload.id then activeSessionId = payload.id end
end)

RegisterNetEvent('sunset:sessions:ended', function(payload)
    -- Server ended our session: guarantee a clean client regardless of
    -- whether the activity's own handler ran (INVARIANT S7).
    EmergencyCleanup(payload and payload.reason or 'session ended')
    activeSessionId = nil
end)

-- Safety nets: death / jail / resource stop / local player exit.
AddEventHandler('sunset:death:playerDowned', function()
    EmergencyCleanup('downed')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    EmergencyCleanup('resource stop')
end)

CreateThread(function()
    while true do
        Wait(1000)
        -- If the player died/wasted without the death resource firing a local
        -- event (e.g. vehicle explosion), still clean up tracked session state.
        local ped = PlayerPedId()
        if activeSessionId and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then
            clearTracked(activeSessionId)
        end
    end
end)
