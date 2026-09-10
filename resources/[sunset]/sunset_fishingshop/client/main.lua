-- ============================================================
--  sunset_fishingshop  ·  client/main.lua
-- ============================================================

local NPC_COORDS       = vector4(-1593.23, 5207.74, 3.31, 25.49)
local NPC_DIST         = 3.5
local BAIT_SHOP_COORDS = vector3(-1602.11, 5203.87, 4.31)
local BAIT_SHOP_DIST   = 3.5
local SELL_DIST        = 3.5

-- Toate magazinele 24/7 unde se poate vinde pestele
local SELL_ZONES = {
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
local nearBaitShop   = false
local nearSell       = false
local menuOpen       = false   -- playerInteraction menu open
local shopOpen       = false   -- fishing shop UI (buy/sell) open
local inCooldown     = false
local INTERACT_KEY   = 38

local function getCharacterJob()
    local char = Sunset.Character or {}
    return select(1, Sunset.GetCharacterJob(char))
end

local function isOnFishermanShift()
    if GetResourceState('sunset_jobs') ~= 'started' then return false end
    local ok, active = pcall(function()
        return exports.sunset_jobs:IsFishermanShiftActive()
    end)
    return ok and active == true
end

local function buildBillyRayActions()
    local actions = {}
    local job = getCharacterJob()

    if job ~= 'fisherman' then
        actions[#actions + 1] = { id = 'get_fisherman_job', label = 'Devino Pescar', group = 'CIVILIAN' }
    end

    if job == 'fisherman' then
        if isOnFishermanShift() then
            actions[#actions + 1] = { id = 'end_fishing_shift', label = 'Opreste Tura', group = 'FISHING' }
        else
            actions[#actions + 1] = { id = 'start_fishing_shift', label = 'Incepe Tura', group = 'FISHING' }
        end
        actions[#actions + 1] = { id = 'upgrade_fishing_rod', label = 'Upgrade Undita', group = 'FISHING' }
    end

    return actions
end

local function openBillyRayMenu()
    local actions = buildBillyRayActions()
    if #actions == 0 then return end
    exports.sunset_ui:Send('playerInteractionShow', {
        target = { name = 'Billy Ray', id = '' },
        actions = actions,
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = true
end

exports('IsNearBillyRay', function() return nearNpc == true end)
exports('IsMenuOpen', function() return menuOpen or shopOpen end)

-- ── Spawn NPC ────────────────────────────────────────────────
CreateThread(function()
    local hash = GetHashKey('a_m_m_hillbilly_01')
    RequestModel(hash)
    local t = GetGameTimer() + 20000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(200) end
    if not HasModelLoaded(hash) then
        print('[sunset_fishingshop] ERR: model nu s-a incarcat')
        return
    end
    Wait(500)
    hillbillyPed = CreatePed(4, hash,
        NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z, NPC_COORDS.w,
        false, true)
    if not hillbillyPed or hillbillyPed == 0 or not DoesEntityExist(hillbillyPed) then
        print('[sunset_fishingshop] ERR: CreatePed invalid')
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

    -- Blip Billy Ray
    local blip = AddBlipForCoord(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
    SetBlipSprite(blip, 68)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Billy Ray — Fishing')
    EndTextCommandSetBlipName(blip)

    -- Blip Fishing Supply shop
    local shopBlip = AddBlipForCoord(BAIT_SHOP_COORDS.x, BAIT_SHOP_COORDS.y, BAIT_SHOP_COORDS.z)
    SetBlipSprite(shopBlip, 52)   -- store / shop icon
    SetBlipColour(shopBlip, 3)
    SetBlipScale(shopBlip, 0.75)
    SetBlipAsShortRange(shopBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Fishing Supply')
    EndTextCommandSetBlipName(shopBlip)
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
        local wasNpc       = nearNpc
        local wasBaitShop  = nearBaitShop
        local wasSell      = nearSell

        nearNpc      = hillbillyPed and DoesEntityExist(hillbillyPed)
                       and #(pos - vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)) < NPC_DIST
        nearBaitShop = #(pos - BAIT_SHOP_COORDS) < BAIT_SHOP_DIST
        nearSell     = nearAnySellZone(pos)

        -- Auto-close playerInteraction menu when walking away
        if (wasNpc or wasSell) and not nearNpc and not nearSell and menuOpen then
            exports.sunset_ui:Send('playerInteractionHide', {})
            exports.sunset_ui:SetFocus(false, false)
            menuOpen = false
        end

        -- Auto-close fishing shop UI when walking away from bait shop or 24/7
        if (wasBaitShop or wasSell) and not nearBaitShop and not nearSell and shopOpen then
            exports.sunset_ui:Send('fishingShopHide', {})
            exports.sunset_ui:SetFocus(false, false)
            shopOpen = false
        end

        Wait((nearNpc or nearBaitShop or nearSell) and 0 or 350)
    end
end)

-- ── E key handler ─────────────────────────────────────────────
CreateThread(function()
    while true do
        if nearNpc or nearBaitShop or nearSell then
            DisableControlAction(0, INTERACT_KEY, true)

            if IsDisabledControlJustPressed(0, INTERACT_KEY) and not inCooldown and not menuOpen and not shopOpen and not IsNuiFocused() then
                if nearNpc then
                    openBillyRayMenu()

                elseif nearBaitShop then
                    -- Deschide direct magazinul de momeala
                    inCooldown = true
                    CreateThread(function()
                        local shopData, err = Sunset.AwaitCallback('sunset:fishingshop:getBaitShop')
                        if shopData then
                            exports.sunset_ui:Send('fishingShopShow', {
                                mode  = 'buy',
                                title = 'FISHING SUPPLY',
                                cash  = shopData.cash,
                                items = shopData.items,
                            })
                            exports.sunset_ui:SetFocus(true, true)
                            shopOpen = true
                        else
                            exports.sunset_ui:Notify(err or 'Nu s-a putut deschide magazinul.', 'error')
                        end
                        SetTimeout(1500, function() inCooldown = false end)
                    end)

                elseif nearSell then
                    -- Meniu 24/7 sell fish
                    exports.sunset_ui:Send('playerInteractionShow', {
                        target  = { name = '24/7 Store', id = '' },
                        actions = {
                            { id = 'sell_fish_247', label = 'Vinde Pestele (cash)', group = 'STORE' },
                        },
                    })
                    exports.sunset_ui:SetFocus(true, true)
                    menuOpen = true
                end
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

-- ── playerInteraction NUI events ──────────────────────────────
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
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:hireJob', 'fisherman')
            if ok then
                exports.sunset_ui:Notify('Esti acum Pescar! Apasa Incepe Tura ca sa incepi.', 'success', 8000)
            else
                local errMsg = err or 'Nu a functionat angajarea.'
                -- User already has fisherman job — show info instead of error
                if errMsg:find('already work') or errMsg:find('You already work') then
                    exports.sunset_ui:Notify('Esti deja Pescar! Apasa Incepe Tura ca sa incepi.', 'info', 7000)
                else
                    exports.sunset_ui:Notify(errMsg, 'error')
                end
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif data.action == 'start_fishing_shift' then
        inCooldown = true
        TriggerEvent('sunset:client:startFishermanShift')
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'end_fishing_shift' then
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:jobs:fisherman:endShift')
            if ok then
                exports.sunset_ui:Notify('Tura de pescuit oprită.', 'success', 5000)
            else
                exports.sunset_ui:Notify(err or 'Nu ai o tură activă.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif data.action == 'upgrade_fishing_rod' then
        inCooldown = true
        CreateThread(function()
            local ok, msg = Sunset.AwaitCallback('sunset:fishingshop:upgradeRod')
            if ok then
                exports.sunset_ui:Notify(msg or 'Undita upgradata!', 'success', 6000)
            else
                exports.sunset_ui:Notify(msg or 'Nu s-a putut face upgrade.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif data.action == 'sell_fish_247' then
        inCooldown = true
        CreateThread(function()
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
                    shopOpen = true
                end
            else
                exports.sunset_ui:Notify(err or 'Eroare la incarcare inventar.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)
    end
end)

-- ── Fishing shop UI NUI events (via nui_bridge forward) ───────
AddEventHandler('sunset:nui:fishingShopClose', function()
    shopOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('fishingShopHide', {})
end)

AddEventHandler('sunset:nui:fishingShopBuy', function(data)
    local cart = data and data.cart
    if not cart or #cart == 0 then return end
    local ok, err = Sunset.AwaitCallback('sunset:fishingshop:buyCart', cart)
    if ok then
        exports.sunset_ui:Notify(('Achizitie reusita! -$%d'):format(ok.total or 0), 'success', 5000)
    else
        exports.sunset_ui:Notify(tostring(err or 'Cumparare esecuata.'), 'error')
    end
end)

AddEventHandler('sunset:nui:fishingShopSell', function(data)
    local cart = data and data.cart
    if not cart or #cart == 0 then return end
    local ok, err = Sunset.AwaitCallback('sunset:fishingshop:sellCart', cart)
    if ok then
        exports.sunset_ui:Notify(tostring(ok), 'success', 5000)
    else
        exports.sunset_ui:Notify(tostring(err or 'Vanzare esecuata.'), 'error')
    end
end)
