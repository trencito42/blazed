-- ============================================================
--  sunset_fishingshop  ·  client/main.lua
-- ============================================================

local NPC_COORDS       = vector4(-1593.23, 5207.74, 3.31, 25.49)
local NPC_PROMPT_DIST  = 4.5
local NPC_MENU_DIST    = 2.15
local BAIT_SHOP_COORDS = vector3(-1602.11, 5203.87, 4.31)
local BAIT_SHOP_DIST   = 2.5
local SELL_DIST        = 2.5

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
local billyPromptVisible = false
local billyHoldStart = nil
local billyHoldVisual = false
local menuCloseArmed = false
local BILLY_HOLD_MS  = 800
local INTERACT_KEY   = 38
local billyInteractUnlockAt = GetGameTimer() + 60000

-- Forward declarations
local hideBillyRayPrompt
local closeFishingMenu
local sendBillyHoldState
local safeUiCall

local FISHING_ACTIONS = {
    get_fisherman_job = true,
    start_fishing_shift = true,
    end_fishing_shift = true,
    upgrade_fishing_rod = true,
    sell_fish_247 = true,
}

local function debugHire(message)
    print(('[sunset_fishingshop] %s'):format(message))
    TriggerServerEvent('sunset:server:flowTrace', 'fishingshop.hire', message)
end

local function npcCenter()
    return vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
end

local function distanceToNpc(pos)
    return #(pos - npcCenter())
end

local function isNearNpcMenu(pos)
    return hillbillyPed and DoesEntityExist(hillbillyPed) and distanceToNpc(pos) < NPC_MENU_DIST
end

local function isNearNpcPrompt(pos)
    return hillbillyPed and DoesEntityExist(hillbillyPed) and distanceToNpc(pos) < NPC_PROMPT_DIST
end

local function armBillyInteractGrace(ms)
    billyInteractUnlockAt = GetGameTimer() + (ms or 3000)
    billyHoldStart = nil
    sendBillyHoldState(false)
end

local function billyInteractionsReady()
    if GetGameTimer() < billyInteractUnlockAt then return false end
    if not NetworkIsPlayerActive(PlayerId()) then return false end
    if IsNuiFocused() or IsPauseMenuActive() then return false end
    return true
end

safeUiCall = function(fn)
    if GetResourceState('sunset_ui') ~= 'started' then return false end
    return pcall(fn)
end

local function anotherPlayerBlocksNpcPrompt(pos)
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            if targetPed ~= 0 and DoesEntityExist(targetPed) then
                if #(pos - GetEntityCoords(targetPed)) < 3.0 then
                    return true
                end
            end
        end
    end
    return false
end

hideBillyRayPrompt = function()
    if not billyPromptVisible then return end
    billyPromptVisible = false
    billyHoldStart = nil
    billyHoldVisual = false
    exports.sunset_ui:Send('playerInteractionPrompt', { visible = false, holding = false })
end

sendBillyHoldState = function(active)
    active = active == true
    if billyHoldVisual == active then return end
    billyHoldVisual = active
    if not billyPromptVisible then return end
    exports.sunset_ui:Send('playerInteractionPrompt', { holding = active })
end

local function sendBillyRayPrompt()
    local ped = hillbillyPed
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        hideBillyRayPrompt()
        return
    end

    local headCoords = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    if headCoords.x == 0.0 and headCoords.y == 0.0 and headCoords.z == 0.0 then
        headCoords = GetEntityCoords(ped) + vector3(0.0, 0.0, 0.85)
    else
        headCoords = headCoords + vector3(0.0, 0.0, 0.40)
    end

    local visible, screenX, screenY = World3dToScreen2d(headCoords.x, headCoords.y, headCoords.z)
    if not visible then
        hideBillyRayPrompt()
        return
    end

    billyPromptVisible = true
    exports.sunset_ui:Send('playerInteractionPrompt', {
        visible = true,
        x = screenX * 100.0,
        y = screenY * 100.0,
        name = 'Billy Ray',
        key = 'E',
    })
end

local function shouldShowBillyRayPrompt()
    if not billyInteractionsReady() then return false end
    if menuOpen or shopOpen then return false end
    local pos = GetEntityCoords(PlayerPedId())
    if not isNearNpcPrompt(pos) then return false end
    if anotherPlayerBlocksNpcPrompt(pos) then return false end
    return true
end

closeFishingMenu = function()
    if not menuOpen then return end
    menuOpen = false
    menuCloseArmed = false
    billyHoldStart = nil
    sendBillyHoldState(false)
    hideBillyRayPrompt()
    safeUiCall(function()
        exports.sunset_ui:Send('playerInteractionHide', {})
        exports.sunset_ui:SetFocus(false, false)
    end)
end

local function notifyHireError(err)
    local errMsg = err or 'Nu a functionat angajarea (fara detalii de la server).'
    debugHire(('FAIL: %s'):format(errMsg))
    if errMsg:find('already work') or errMsg:find('You already work') then
        exports.sunset_ui:Notify('Esti deja Pescar! Apasa Incepe Tura ca sa incepi.', 'info', 7000)
        return
    end
    exports.sunset_ui:Notify(errMsg, 'error', 8000)
end

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
    if menuOpen or not billyInteractionsReady() then return end
    local actions = buildBillyRayActions()
    if #actions == 0 then return end
    billyHoldStart = nil
    menuCloseArmed = false
    hideBillyRayPrompt()
    exports.sunset_ui:Send('playerInteractionShow', {
        menuTitle = 'Acțiuni Pescuit',
        target = { name = 'Billy Ray', id = '' },
        actions = actions,
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = true
end

exports('IsNearBillyRay', function()
    return isNearNpcMenu(GetEntityCoords(PlayerPedId()))
end)
exports('IsMenuOpen', function() return menuOpen or shopOpen end)

local function resetBillyUiOnEntry()
    armBillyInteractGrace(3500)
    billyHoldStart = nil
    menuCloseArmed = false
    menuOpen = false
    shopOpen = false
    hideBillyRayPrompt()
    safeUiCall(function()
        exports.sunset_ui:Send('playerInteractionHide', {})
        exports.sunset_ui:SetFocus(false, false)
    end)
end

AddEventHandler('sunset:client:playerSpawned', resetBillyUiOnEntry)
AddEventHandler('sunset:client:characterFlowComplete', function()
    armBillyInteractGrace(3500)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print('[sunset_fishingshop] client billy-hold-v5')
end)

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

-- ── World tooltip deasupra capului (Hold E To Interact) ───────
CreateThread(function()
    while true do
        if shouldShowBillyRayPrompt() then
            sendBillyRayPrompt()
            Wait(0)
        else
            hideBillyRayPrompt()
            Wait(200)
        end
    end
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

        nearNpc      = isNearNpcMenu(pos)
        nearBaitShop = #(pos - BAIT_SHOP_COORDS) < BAIT_SHOP_DIST
        nearSell     = nearAnySellZone(pos)

        -- Auto-close playerInteraction menu when walking away
        if (wasNpc or wasSell) and not nearNpc and not nearSell and menuOpen then
            closeFishingMenu()
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
            local pos = GetEntityCoords(PlayerPedId())
            local canPromptBilly = isNearNpcPrompt(pos) and not anotherPlayerBlocksNpcPrompt(pos)

            if nearNpc or nearBaitShop then
                DisableControlAction(0, INTERACT_KEY, true)
            end

            if canPromptBilly then
                if menuOpen then
                    if IsDisabledControlJustPressed(0, INTERACT_KEY) and menuCloseArmed then
                        closeFishingMenu()
                    end
                    if IsDisabledControlJustReleased(0, INTERACT_KEY) then
                        menuCloseArmed = true
                    end
                elseif billyInteractionsReady() and not inCooldown and not shopOpen then
                    if IsDisabledControlJustPressed(0, INTERACT_KEY) then
                        billyHoldStart = GetGameTimer()
                        sendBillyHoldState(true)
                    end

                    if billyHoldStart and IsDisabledControlPressed(0, INTERACT_KEY) then
                        if (GetGameTimer() - billyHoldStart) >= BILLY_HOLD_MS and isNearNpcMenu(pos) then
                            billyHoldStart = nil
                            sendBillyHoldState(false)
                            openBillyRayMenu()
                        end
                    end

                    if IsDisabledControlJustReleased(0, INTERACT_KEY) then
                        billyHoldStart = nil
                        sendBillyHoldState(false)
                    end
                end
            elseif menuOpen and nearNpc then
                if IsDisabledControlJustPressed(0, INTERACT_KEY) and menuCloseArmed then
                    closeFishingMenu()
                end
                if IsDisabledControlJustReleased(0, INTERACT_KEY) then
                    menuCloseArmed = true
                end
            end

            local pressed = false
            if (nearBaitShop or nearSell) and not nearNpc and not inCooldown and not menuOpen and not shopOpen and not IsNuiFocused() then
                if nearBaitShop then
                    pressed = IsDisabledControlJustPressed(0, INTERACT_KEY)
                elseif nearSell then
                    pressed = IsControlJustPressed(0, INTERACT_KEY)
                end
            end

            if pressed then
                if nearBaitShop then
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
                        instant = true,
                        menuTitle = 'Acțiuni Magazin',
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
            billyHoldStart = nil
            sendBillyHoldState(false)
            menuCloseArmed = false
            Wait(200)
        end
    end
end)

-- ── playerInteraction NUI events ──────────────────────────────
AddEventHandler('sunset:nui:playerInteractionClose', function()
    if not menuOpen then return end
    closeFishingMenu()
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not data or not data.action then return end
    if not FISHING_ACTIONS[data.action] then return end
    if not menuOpen then return end

    closeFishingMenu()

    if data.action == 'get_fisherman_job' then
        inCooldown = true
        debugHire('request hire fisherman')
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:fishingshop:hireFisherman')
            debugHire(('callback ok=%s err=%s'):format(tostring(ok), tostring(err)))
            if ok then
                exports.sunset_ui:Notify('Esti acum Pescar! Apasa Incepe Tura ca sa incepi.', 'success', 8000)
            else
                notifyHireError(err)
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
