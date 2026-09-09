-- ============================================================
--  sunset_fishingshop  ·  client/main.lua
--  Billy Ray (hillbilly NPC) la pontoon Paleto Bay
--  Opreste G la NPC si la zona 24/7 pentru a vinde peste
-- ============================================================

local NPC_COORDS  = vector4(-1593.23, 5207.74, 3.31, 25.49)
local NPC_DIST    = 3.5
local SELL_DIST   = 3.5

-- Toate magazinele 24/7 unde se poate vinde pestele
local SELL_ZONES  = {
    vector3(25.74,    -1347.32,  29.50),   -- Legion Square
    vector3(-46.06,   -1757.88,  29.42),   -- Strawberry
    vector3(-707.12,   -913.43,  19.22),   -- Little Seoul
    vector3(1164.44,   -322.49,  69.21),   -- Mirror Park
    vector3(548.46,   2671.72,   42.16),   -- Vinewood Hills
    vector3(-3038.24,   584.19,   7.91),   -- Rockford Hills
    vector3(2678.55,  3279.25,   55.24),   -- Sandy Shores
    vector3(-54.37,   6244.70,   31.09),   -- Paleto Bay (langa Billy Ray)
}

local hillbillyPed   = nil
local nearNpc        = false
local nearSell       = false
local menuOpen       = false
local inCooldown     = false

-- Export so other resources (fisherman.lua) can check if shop is blocking input
exports('IsMenuOpen', function() return menuOpen end)

-- ── Spawn NPC ────────────────────────────────────────────────
CreateThread(function()
    local hash = GetHashKey('a_m_m_hillbilly_01')
    RequestModel(hash)
    local t = GetGameTimer() + 20000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(200) end
    if not HasModelLoaded(hash) then
        print('[sunset_fishingshop] ERR: model a_m_m_hillbilly_01 nu s-a incarcat')
        return
    end

    Wait(500)  -- delay mic ca world-ul sa fie gata

    hillbillyPed = CreatePed(4, hash,
        NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z, NPC_COORDS.w,
        false, true)

    if not hillbillyPed or hillbillyPed == 0 or not DoesEntityExist(hillbillyPed) then
        print('[sunset_fishingshop] ERR: CreatePed a returnat entitate invalida')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(hillbillyPed, true, true)
    FreezeEntityPosition(hillbillyPed, true)
    SetEntityInvincible(hillbillyPed, true)
    SetBlockingOfNonTemporaryEvents(hillbillyPed, true)
    SetEntityCanBeDamaged(hillbillyPed, false)
    TaskStartScenarioInPlace(hillbillyPed, 'WORLD_HUMAN_SMOKING', 0, true)
    SetModelAsNoLongerNeeded(hash)
    print('[sunset_fishingshop] Billy Ray spawnat la', NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)

    -- Blip pe harta
    local blip = AddBlipForCoord(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
    SetBlipSprite(blip, 68)  -- radar_tow_truck
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Billy Ray — Fishing')
    EndTextCommandSetBlipName(blip)
end)

-- ── Proximitate checker ───────────────────────────────────────
local function nearAnySellZone(pos)
    for _, coords in ipairs(SELL_ZONES) do
        if #(pos - coords) < SELL_DIST then return true end
    end
    return false
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local wasNpc  = nearNpc
        local wasSell = nearSell

        nearNpc  = hillbillyPed and DoesEntityExist(hillbillyPed)
                   and #(pos - vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)) < NPC_DIST
        nearSell = nearAnySellZone(pos)

        if (wasNpc or wasSell) and not nearNpc and not nearSell and menuOpen then
            exports.sunset_ui:Send('playerInteractionHide', {})
            exports.sunset_ui:SetFocus(false, false)
            menuOpen = false
        end

        Wait((nearNpc or nearSell) and 0 or 350)
    end
end)

-- ── G key handler ─────────────────────────────────────────────
CreateThread(function()
    while true do
        if nearNpc or nearSell then
            DisableControlAction(0, 51, true)  -- bloca G de la sunset_interactions

            if IsDisabledControlJustPressed(0, 51) and not inCooldown and not menuOpen then
                if nearNpc then
                    -- Meniu Billy Ray
                    exports.sunset_ui:Send('playerInteractionShow', {
                        target  = { name = 'Billy Ray', id = '' },
                        actions = {
                            { id = 'get_fisherman_job',   label = 'Devino Pescar',   group = 'CIVILIAN' },
                            { id = 'start_fishing_shift', label = 'Incepe Tura',     group = 'FISHING'  },
                            { id = 'upgrade_fishing_rod', label = 'Upgrade Undita',  group = 'FISHING'  },
                            { id = 'buy_bait',            label = 'Cumpara Momeala', group = 'FISHING'  },
                        },
                    })
                elseif nearSell then
                    -- Meniu 24/7 sell fish
                    exports.sunset_ui:Send('playerInteractionShow', {
                        target  = { name = '24/7 Store', id = '' },
                        actions = {
                            { id = 'sell_fish_247', label = 'Vinde Pestele (cash)', group = 'STORE' },
                        },
                    })
                end
                exports.sunset_ui:SetFocus(true, true)
                menuOpen = true
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

-- ── NUI events ────────────────────────────────────────────────
AddEventHandler('sunset:nui:playerInteractionClose', function()
    menuOpen = false
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not data or not data.action then return end
    menuOpen = false
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)

    if data.action == 'get_fisherman_job' then
        inCooldown = true
        local ok, err = Sunset.AwaitCallback('sunset:hireJob', 'fisherman')
        if ok then
            exports.sunset_ui:Notify('Esti acum Pescar! Apasa Incepe Tura ca sa incepi.', 'success', 8000)
        else
            exports.sunset_ui:Notify(err or 'Nu a functionat angajarea.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'start_fishing_shift' then
        inCooldown = true
        -- Triggeruieste event-ul din sunset_jobs/client/fisherman.lua
        TriggerEvent('sunset:client:startFishermanShift')
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'upgrade_fishing_rod' then
        inCooldown = true
        local ok, msg = Sunset.AwaitCallback('sunset:fishingshop:upgradeRod')
        if ok then
            exports.sunset_ui:Notify(msg or 'Undita upgradata!', 'success', 6000)
        else
            exports.sunset_ui:Notify(msg or 'Nu s-a putut face upgrade.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'sell_fish_247' then
        inCooldown = true
        local invData, err = Sunset.AwaitCallback('sunset:fishingshop:getFishInventory')
        if invData then
            if not invData.items or #invData.items == 0 then
                exports.sunset_ui:Notify('Nu ai niciun peste in inventar.', 'info')
            else
                exports.sunset_ui:Send('fishingShopShow', {
                    mode  = 'sell',
                    title = '24/7 — VINDE PESTE',
                    cash  = invData.cash,
                    items = invData.items,
                })
                exports.sunset_ui:SetFocus(true, true)
            end
        else
            exports.sunset_ui:Notify(err or 'Eroare la incarcare inventar.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'buy_bait' then
        inCooldown = true
        local shopData, err = Sunset.AwaitCallback('sunset:fishingshop:getBaitShop')
        if shopData then
            exports.sunset_ui:Send('fishingShopShow', {
                mode  = 'buy',
                title = 'FISHING SUPPLY',
                cash  = shopData.cash,
                items = shopData.items,
            })
            exports.sunset_ui:SetFocus(true, true)
        else
            exports.sunset_ui:Notify(err or 'Nu s-a putut deschide magazinul.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)
    end
end)

-- ── NUI callbacks (buy / sell via fishing shop UI) ────────────
RegisterNUICallback('fishingShopClose', function(data, cb)
    exports.sunset_ui:SetFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('fishingShopBuy', function(data, cb)
    local cart = data and data.cart
    if not cart or #cart == 0 then cb('ok') return end
    local ok, result = Sunset.AwaitCallback('sunset:fishingshop:buyCart', cart)
    if ok then
        exports.sunset_ui:Notify(('Achizitie reusita! -$%d'):format(result and result.total or 0), 'success', 5000)
    else
        exports.sunset_ui:Notify(result or 'Cumparare esecuata.', 'error')
    end
    cb('ok')
end)

RegisterNUICallback('fishingShopSell', function(data, cb)
    local cart = data and data.cart
    if not cart or #cart == 0 then cb('ok') return end
    local ok, result = Sunset.AwaitCallback('sunset:fishingshop:sellCart', cart)
    if ok then
        exports.sunset_ui:Notify(result or 'Peste vandut!', 'success', 5000)
    else
        exports.sunset_ui:Notify(result or 'Vanzare esecuata.', 'error')
    end
    cb('ok')
end)
