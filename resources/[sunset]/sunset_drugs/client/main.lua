-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Drug Pipeline (client/main.lua)
--  Harvest/process/sell markers + UI.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetDrugs.Config
local drugsOpen = false

-- ── World markers ──
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 500

        -- Harvest spots
        for i, spot in ipairs(Cfg.manufacture.spots or {}) do
            if #(coords - spot) < 10.0 then
                sleep = 0
                DrawMarker(1, spot.x, spot.y, spot.z - 1.0,
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
            if #(coords - lab) < 10.0 then
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

local function openDrugsUI(mode, index)
    if drugsOpen then return end
    drugsOpen = true
    local status = Sunset.AwaitCallback('sunset:drugs:status')
    if not status then
        exports.sunset_ui:Notify('Could not load drug status.', 'error')
        drugsOpen = false
        return
    end
    exports.sunset_ui:Send('drugsShow', { mode = mode, index = index, status = status })
    exports.sunset_ui:SetFocus(true, true, false, 'drugs')
end

local function closeDrugsUI()
    if not drugsOpen then return end
    drugsOpen = false
    exports.sunset_ui:Send('drugsHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'drugs')
end

-- ── NUI callbacks ──
AddEventHandler('sunset:nui:drugsClose', function()
    closeDrugsUI()
end)

AddEventHandler('sunset:nui:drugsHarvest', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:drugs:harvest', tonumber(data.spotIndex))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not harvest.', 'error')
            return
        end
        exports.sunset_ui:Notify(('Harvested %dx %s!'):format(res.amount, res.raw), 'success')
        local status = Sunset.AwaitCallback('sunset:drugs:status')
        if status then exports.sunset_ui:Send('drugsUpdate', { status = status }) end
    end)
end)

AddEventHandler('sunset:nui:drugsProcess', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:drugs:process', tostring(data.drugType))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not process.', 'error')
            return
        end
        exports.sunset_ui:Notify(('Processed → 1x %s!'):format(res.product), 'success')
        local status = Sunset.AwaitCallback('sunset:drugs:status')
        if status then exports.sunset_ui:Send('drugsUpdate', { status = status }) end
    end)
end)

AddEventHandler('sunset:nui:drugsSell', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:drugs:sell', tostring(data.drugType), tonumber(data.amount))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not sell.', 'error')
            return
        end
        exports.sunset_ui:Notify(('Sold for $%s!'):format(res.price), 'success')
        local status = Sunset.AwaitCallback('sunset:drugs:status')
        if status then exports.sunset_ui:Send('drugsUpdate', { status = status }) end
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

exports('IsDrugsOpen', function() return drugsOpen end)
