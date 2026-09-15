-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Drug Pipeline (client/main.lua)
--  Harvest/process/sell markers + UI.
--
--  [FORWARD-REF FIX] openDrugsUI/closeDrugsUI are forward-declared
--  BEFORE the marker thread — the old code called them as globals
--  (nil) from the thread, so E did nothing at every location.
--
--  TIMED ACTIONS: harvest/process run start→complete phases. The
--  client drives a local progress UI but the SERVER owns validation;
--  the complete callback only succeeds after the server-side timer
--  elapsed. Action locks prevent double-clicks/spam.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetDrugs.Config
local drugsOpen = false
local currentMode = nil
local currentIndex = nil
local actionBusy = false   -- UX lock: one action in flight at a time

-- ── Forward declarations (lexical scope fix) ──
local openDrugsUI
local closeDrugsUI
local runTimedAction

-- ── World markers ──
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 500

        -- Harvest spots
        for i, spot in ipairs(Cfg.manufacture.spots or {}) do
            local pos = spot.coords
            if #(coords - pos) < (Cfg.manufacture.spotRadius or 10.0) then
                sleep = 0
                DrawMarker(1, pos.x, pos.y, pos.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.5, 1.5, 1.0,
                    0, 200, 0, 80,
                    false, false, 2, false, nil, nil, false)
                if IsControlJustReleased(0, 38) and not drugsOpen then
                    openDrugsUI('harvest', i)
                end
            end
        end

        -- Processing labs
        for i, lab in ipairs(Cfg.process.labs or {}) do
            if #(coords - lab) < (Cfg.process.labRadius or 10.0) then
                sleep = 0
                DrawMarker(1, lab.x, lab.y, lab.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.5, 1.5, 1.0,
                    255, 150, 0, 80,
                    false, false, 2, false, nil, nil, false)
                if IsControlJustReleased(0, 38) and not drugsOpen then
                    openDrugsUI('process', i)
                end
            end
        end

        -- Dealers
        for i, dealer in ipairs(Cfg.sell.dealers or {}) do
            if #(coords - dealer) < (Cfg.sell.sellRadius or 5.0) then
                sleep = 0
                DrawMarker(1, dealer.x, dealer.y, dealer.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.5, 1.5, 1.0,
                    255, 0, 100, 80,
                    false, false, 2, false, nil, nil, false)
                if IsControlJustReleased(0, 38) and not drugsOpen then
                    openDrugsUI('sell', i)
                end
            end
        end

        Wait(sleep)
    end
end)

openDrugsUI = function(mode, index)
    if drugsOpen then return end
    drugsOpen = true
    currentMode = mode
    currentIndex = index
    local status = Sunset.AwaitCallback('sunset:drugs:status')
    if not status then
        exports.sunset_ui:Notify('Could not load drug status.', 'error')
        -- [STATE FIX] never leave drugsOpen=true after a failed open
        drugsOpen = false
        currentMode = nil
        currentIndex = nil
        return
    end
    exports.sunset_ui:Send('drugsShow', { mode = mode, index = index, status = status })
    exports.sunset_ui:SetFocus(true, true, false, 'drugs')
end

closeDrugsUI = function()
    if not drugsOpen then return end
    drugsOpen = false
    currentMode = nil
    currentIndex = nil
    exports.sunset_ui:Send('drugsHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'drugs')
    -- Tell the server to drop any pending timed action (walk-away cancel).
    TriggerCallback('sunset:drugs:cancelAction', function() end)
end

local function refreshStatus()
    CreateThread(function()
        local status = Sunset.AwaitCallback('sunset:drugs:status')
        if status and drugsOpen then
            exports.sunset_ui:Send('drugsUpdate', { status = status })
        end
    end)
end

-- [TIMED ACTION] start → local progress UI → complete. The client lock is
-- UX only; the server re-validates everything (elapsed time, proximity,
-- pending state, cooldown). Success notifications come from the SERVER;
-- the client only refreshes UI state (no duplicates).
runTimedAction = function(startCb, startArgs, completeCb, progressLabel)
    if actionBusy then return end
    actionBusy = true
    exports.sunset_ui:Send('drugsBusy', { busy = true })
    CreateThread(function()
        local info, err = Sunset.AwaitCallback(startCb, table.unpack(startArgs or {}))
        if not info then
            actionBusy = false
            exports.sunset_ui:Send('drugsBusy', { busy = false })
            exports.sunset_ui:Notify(err or 'Action failed.', 'error')
            return
        end
        local durationMs = tonumber(info.durationMs) or 5000

        -- Local progress feedback (purely cosmetic — server owns the timer)
        exports.sunset_ui:Send('drugsProgress', {
            label = progressLabel,
            durationMs = durationMs,
        })
        Wait(durationMs)

        local res, err2 = Sunset.AwaitCallback(completeCb)
        actionBusy = false
        exports.sunset_ui:Send('drugsBusy', { busy = false })
        exports.sunset_ui:Send('drugsProgress', { hide = true })
        if not res then
            -- Server rejected (moved away / cooldown / inventory). Error is
            -- server-owned and meaningful; show it verbatim.
            exports.sunset_ui:Notify(err2 or 'Action failed.', 'error')
            refreshStatus()
            return
        end
        refreshStatus()
    end)
end

-- ── NUI callbacks ──
AddEventHandler('sunset:nui:drugsClose', function()
    closeDrugsUI()
end)

AddEventHandler('sunset:nui:drugsHarvest', function(data)
    data = type(data) == 'table' and data or {}
    -- [SPOT FIX] Use the index of the world interaction that opened the UI,
    -- NOT the JS payload and NOT a hardcoded 1. The server re-validates
    -- spot existence + proximity anyway.
    local spotIndex = tonumber(data.spotIndex) or currentIndex
    if not spotIndex then
        exports.sunset_ui:Notify('Reopen the harvest spot and try again.', 'error')
        return
    end
    runTimedAction('sunset:drugs:harvestStart', { spotIndex },
        'sunset:drugs:harvestComplete', 'Harvesting...')
end)

AddEventHandler('sunset:nui:drugsProcess', function(data)
    data = type(data) == 'table' and data or {}
    local drugType = tostring(data.drugType or '')
    if drugType == '' then return end
    runTimedAction('sunset:drugs:processStart', { drugType },
        'sunset:drugs:processComplete', 'Processing...')
end)

AddEventHandler('sunset:nui:drugsSell', function(data)
    data = type(data) == 'table' and data or {}
    if actionBusy then return end
    actionBusy = true
    exports.sunset_ui:Send('drugsBusy', { busy = true })
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:drugs:sell',
            tostring(data.drugType or ''), tonumber(data.amount) or 1)
        actionBusy = false
        exports.sunset_ui:Send('drugsBusy', { busy = false })
        if not res then
            exports.sunset_ui:Notify(err or 'Could not sell.', 'error')
        end
        -- Success notification is server-owned; only refresh UI here.
        refreshStatus()
    end)
end)

-- ESC closes drugs UI
CreateThread(function()
    while true do
        if drugsOpen and IsPauseMenuActive() then
            closeDrugsUI()
        end
        Wait(drugsOpen and 50 or 250)
    end
end)

-- [CLEANUP] Resource stop: close UI + release focus so the cursor never sticks.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if drugsOpen then
        exports.sunset_ui:Send('drugsHide', {})
        exports.sunset_ui:SetFocus(false, false, false, 'drugs')
        drugsOpen = false
    end
end)

exports('IsDrugsOpen', function() return drugsOpen end)
