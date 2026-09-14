-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — The Diamond Casino (client/main.lua)
--  IPL loading, entry/exit markers, game table interactions.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetCasino.Config
local insideCasino = false
local casinoOpen = false

-- ── IPL loading ──
CreateThread(function()
    if not IsIplActive(Cfg.ipl) then
        RequestIpl(Cfg.ipl)
    end
end)

-- ── Entry/Exit markers ──
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local sleep = 500

        -- Entry marker
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
                SetEntityCoords(ped, Cfg.exit.x, Cfg.exit.y, Cfg.exit.z, false, false, false, false)
                SetEntityHeading(ped, 90.0)
                Wait(300)
                DoScreenFadeIn(500)
            end
        end

        -- Exit marker
        if insideCasino and #(coords - Cfg.exit) < 3.0 then
            sleep = 0
            DrawMarker(1, Cfg.exit.x, Cfg.exit.y, Cfg.exit.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.5, 1.5, 1.0,
                255, 100, 100, 100,
                false, false, 2, false, nil, nil, false)

            if IsControlJustReleased(0, 38) then -- E
                insideCasino = false
                closeCasinoUI()
                DoScreenFadeOut(500)
                Wait(600)
                SetEntityCoords(ped, Cfg.entrance.x, Cfg.entrance.y, Cfg.entrance.z, false, false, false, false)
                SetEntityHeading(ped, 270.0)
                Wait(300)
                DoScreenFadeIn(500)
            end
        end

        Wait(sleep)
    end
end)

-- ── Game table interactions ──
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
