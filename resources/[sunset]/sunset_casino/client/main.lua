-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — The Diamond Casino (client/main.lua)
--  IPL loading, entry/exit, game tables, Lucky Wheel, Cashier, Bar.
--  All coordinates verified via /casinoprobe (interior id=275201).
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetCasino.Config
local insideCasino = false
local casinoOpen = false
local casinoBlip = nil

-- ── Coordinate-based inside detection ──
-- The boolean flag alone is NOT reliable: reconnecting inside, admin TP, or a
-- resource restart loses it and the exit marker would never show. Detect
-- "inside the casino interior" from coordinates too (casino interiors live at
-- Z ≈ -45..-53, X ≈ 1080..1160, Y ≈ 190..290), and re-sync the flag.
local function isInCasinoInterior(coords)
    if not coords then return false end
    return coords.z < -40.0 and coords.z > -60.0
        and coords.x > 1070.0 and coords.x < 1170.0
        and coords.y > 180.0 and coords.y < 300.0
end

-- Exit zones (multiple: interior exit door + main floor near the entry).
-- Verified interiorExit: 1089.63, 205.89, -49.00 (probe: ready=1, group empty).
local EXIT_ZONES = {
    vector3(1089.63, 205.89, -49.00), -- interior exit door
    vector3(1093.31, 214.61, -49.53), -- interior entry area (probe: ready=1)
}

-- ── Game UI open/close (defined before leaveCasino which references it) ──
local function openGame(gameType)
    if casinoOpen then return end
    casinoOpen = true
    local status = Sunset.AwaitCallback('sunset:casino:status')
    exports.sunset_ui:Send('casinoShow', {
        game = gameType,
        status = status,
    })
    exports.sunset_ui:SetFocus(true, true, false, 'casino')
end

local function closeCasinoUI()
    if not casinoOpen then return end
    casinoOpen = false
    exports.sunset_ui:Send('casinoHide', {})
    exports.sunset_ui:SetFocus(false, false, false, 'casino')
end

local function leaveCasino()
    local ped = PlayerPedId()
    closeCasinoUI()
    DoScreenFadeOut(400)
    Wait(500)
    insideCasino = false
    SetEntityCoords(ped, Cfg.entrance.x, Cfg.entrance.y, Cfg.entrance.z, false, false, false, false)
    SetEntityHeading(ped, 270.0)
    Wait(300)
    DoScreenFadeIn(400)
end

-- Escape hatch: /leavecasino ALWAYS works while inside the interior, even if
-- the marker/flag state got out of sync (reconnect inside, resource restart).
RegisterCommand('leavecasino', function()
    local coords = GetEntityCoords(PlayerPedId())
    if insideCasino or isInCasinoInterior(coords) then
        CreateThread(function() leaveCasino() end)
    else
        exports.sunset_ui:Notify('You are not inside the casino.', 'error')
    end
end, false)

-- ── IPL loading ──
-- bob74_ipl auto-loads vw_casino_main on build >= 2060.
-- 'casino_main' does NOT exist; we do NOT call RequestIpl on it.

-- ── Map blip ──
CreateThread(function()
    Wait(5000) -- wait for world to load
    if casinoBlip and DoesBlipExist(casinoBlip) then RemoveBlip(casinoBlip) end
    casinoBlip = AddBlipForCoord(Cfg.entrance.x, Cfg.entrance.y, Cfg.entrance.z)
    SetBlipSprite(casinoBlip, 617) -- casino chip icon
    SetBlipColour(casinoBlip, 5)   -- yellow
    SetBlipScale(casinoBlip, 0.9)
    SetBlipAsShortRange(casinoBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('The Diamond Casino')
    EndTextCommandSetBlipName(casinoBlip)
end)

-- ── Entry/Exit markers ──
-- [EXIT FIX] The old version gated the exit marker ONLY on the `insideCasino`
-- boolean set at entry. Reconnecting inside, admin TP, or a resource restart
-- left the flag false and the player permanently stuck with no exit marker.
-- Now: the inside flag is re-synced from coordinates every tick, exit markers
-- exist at BOTH interior doors, and /leavecasino is a guaranteed escape hatch.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 500

        -- Re-sync the inside flag from actual coordinates (authoritative)
        local inInterior = isInCasinoInterior(coords)
        if inInterior ~= insideCasino then
            insideCasino = inInterior
            if not inInterior then closeCasinoUI() end
        end

        -- Entry marker (outside casino)
        if not insideCasino and #(coords - Cfg.entrance) < 3.0 then
            sleep = 0
            DrawMarker(1, Cfg.entrance.x, Cfg.entrance.y, Cfg.entrance.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.5, 1.5, 1.0,
                0, 255, 204, 100,
                false, false, 2, false, nil, nil, false)

            if IsControlJustReleased(0, 38) then -- E
                insideCasino = true
                DoScreenFadeOut(500)
                Wait(600)
                SetEntityCoords(ped, EXIT_ZONES[1].x, EXIT_ZONES[1].y, EXIT_ZONES[1].z, false, false, false, false)
                SetEntityHeading(ped, 90.0)
                -- Wait for interior to load
                local interior = GetInteriorAtCoords(EXIT_ZONES[1].x, EXIT_ZONES[1].y, EXIT_ZONES[1].z)
                if interior ~= 0 then
                    local deadline = GetGameTimer() + 5000
                    while not IsInteriorReady(interior) and GetGameTimer() < deadline do
                        Wait(50)
                    end
                end
                Wait(300)
                DoScreenFadeIn(500)
            end
        end

        -- Exit markers (inside casino) — both interior doors
        if insideCasino then
            for _, zone in ipairs(EXIT_ZONES) do
                if #(coords - zone) < 3.0 then
                    sleep = 0
                    DrawMarker(1, zone.x, zone.y, zone.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        1.5, 1.5, 1.0,
                        255, 100, 100, 100,
                        false, false, 2, false, nil, nil, false)

                    if IsControlJustReleased(0, 38) then -- E
                        CreateThread(function() leaveCasino() end)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ── Interior markers (blackjack, slots, roulette, wheel, cashier, bar) ──
CreateThread(function()
    while true do
        if not insideCasino then Wait(1000) goto continue end

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 300

        -- Blackjack tables
        for _, pos in ipairs(Cfg.blackjackTables or {}) do
            if #(coords - pos) < 2.5 then
                sleep = 0
                DrawMarker(1, pos.x, pos.y, pos.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.2, 1.2, 0.8,
                    0, 255, 204, 80,
                    false, false, 2, false, nil, nil, false)
                if IsControlJustReleased(0, 38) and not casinoOpen then
                    openGame('blackjack')
                end
            end
        end

        -- Slot machines
        for _, pos in ipairs(Cfg.slotMachines or {}) do
            if #(coords - pos) < 2.0 then
                sleep = 0
                DrawMarker(1, pos.x, pos.y, pos.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.0, 1.0, 0.8,
                    255, 200, 0, 80,
                    false, false, 2, false, nil, nil, false)
                if IsControlJustReleased(0, 38) and not casinoOpen then
                    openGame('slots')
                end
            end
        end

        -- Roulette table
        if Cfg.rouletteTable and #(coords - Cfg.rouletteTable) < 2.5 then
            sleep = 0
            DrawMarker(1, Cfg.rouletteTable.x, Cfg.rouletteTable.y, Cfg.rouletteTable.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.2, 1.2, 0.8,
                255, 50, 50, 80,
                false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 38) and not casinoOpen then
                openGame('roulette')
            end
        end

        -- Lucky Wheel
        if Cfg.luckyWheel and #(coords - Cfg.luckyWheel) < 3.0 then
            sleep = 0
            DrawMarker(1, Cfg.luckyWheel.x, Cfg.luckyWheel.y, Cfg.luckyWheel.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                2.0, 2.0, 1.0,
                255, 0, 255, 100,
                false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 38) and not casinoOpen then
                openGame('luckywheel')
            end
        end

        -- Cashier
        if Cfg.cashier and #(coords - Cfg.cashier) < 2.5 then
            sleep = 0
            DrawMarker(1, Cfg.cashier.x, Cfg.cashier.y, Cfg.cashier.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.2, 1.2, 0.8,
                0, 255, 0, 80,
                false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 38) and not casinoOpen then
                openGame('cashier')
            end
        end

        -- Bar
        if Cfg.bar and #(coords - Cfg.bar) < 2.5 then
            sleep = 0
            DrawMarker(1, Cfg.bar.x, Cfg.bar.y, Cfg.bar.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.2, 1.2, 0.8,
                255, 150, 0, 80,
                false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 38) and not casinoOpen then
                openGame('bar')
            end
        end

        Wait(sleep)
        ::continue::
    end
end)

-- ── NUI callbacks ──
AddEventHandler('sunset:nui:casinoClose', function()
    closeCasinoUI()
end)

AddEventHandler('sunset:nui:casinoBlackjackStart', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:blackjackStart', tonumber(data.bet))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not start the game.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoBlackjackUpdate', res)
    end)
end)

AddEventHandler('sunset:nui:casinoBlackjackHit', function()
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:blackjackHit')
        if not res then
            exports.sunset_ui:Notify(err or 'Could not hit.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoBlackjackUpdate', res)
    end)
end)

AddEventHandler('sunset:nui:casinoBlackjackStand', function()
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:blackjackStand')
        if not res then
            exports.sunset_ui:Notify(err or 'Could not stand.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoBlackjackUpdate', res)
    end)
end)

AddEventHandler('sunset:nui:casinoSlotsSpin', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:slotsSpin', tonumber(data.bet))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not spin.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoSlotsResult', res)
    end)
end)

AddEventHandler('sunset:nui:casinoRouletteSpin', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:rouletteSpin',
            tonumber(data.bet), tostring(data.betType), tonumber(data.betValue))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not spin.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoRouletteResult', res)
    end)
end)

-- ── Lucky Wheel ──
AddEventHandler('sunset:nui:casinoWheelSpin', function()
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:wheelSpin')
        if not res then
            exports.sunset_ui:Notify(err or 'Could not spin the wheel.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoWheelResult', res)
    end)
end)

-- ── Cashier ──
AddEventHandler('sunset:nui:casinoBuyChips', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:buyChips', tonumber(data.amount))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not buy chips.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoCashierUpdate', res)
        exports.sunset_ui:Notify(('Bought %s chips for $%s.'):format(res.chips, res.cost), 'success')
    end)
end)

AddEventHandler('sunset:nui:casinoSellChips', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:sellChips', tonumber(data.amount))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not sell chips.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoCashierUpdate', res)
        exports.sunset_ui:Notify(('Sold %s chips for $%s.'):format(res.chips, res.earned), 'success')
    end)
end)

-- ── Bar ──
AddEventHandler('sunset:nui:casinoBuyDrink', function(data)
    CreateThread(function()
        local res, err = Sunset.AwaitCallback('sunset:casino:buyDrink', tostring(data.drinkId))
        if not res then
            exports.sunset_ui:Notify(err or 'Could not buy the drink.', 'error')
            return
        end
        exports.sunset_ui:Send('casinoBarUpdate', res)
        exports.sunset_ui:Notify(('Bought %s for $%s.'):format(res.label, res.price), 'success')
    end)
end)

-- ESC closes casino
CreateThread(function()
    while true do
        if casinoOpen and IsPauseMenuActive() then
            closeCasinoUI()
        end
        Wait(casinoOpen and 50 or 250)
    end
end)

exports('IsCasinoOpen', function() return casinoOpen end)
