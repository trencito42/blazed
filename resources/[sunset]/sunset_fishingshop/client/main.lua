-- ============================================================
--  sunset_fishingshop  ·  client/main.lua
-- ============================================================

local NPC_COORDS       = vector4(-1593.23, 5207.74, 3.31, 25.49)
local NPC_PROMPT_DIST  = 4.5
local NPC_MENU_DIST    = 2.15
local BAIT_SHOP_COORDS = vector3(-1602.11, 5203.87, 4.31)
local BAIT_SHOP_DIST   = 2.5
local SELL_DIST        = 2.5
local shopOpen         = false   -- fishing shop UI (buy/sell) open

local function getSellZones()
    local zones = {}
    for _, store in ipairs(Sunset.TwentyFourSevenStores or {}) do
        if store.coords then zones[#zones + 1] = store.coords end
    end
    return zones
end

local function nearestFishBuyer()
    local pos = GetEntityCoords(PlayerPedId())
    local best = {
        label = 'Billy Ray',
        coords = vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z),
    }
    local bestDistance = #(pos - best.coords)
    for _, store in ipairs(Sunset.TwentyFourSevenStores or {}) do
        local coords = store.cashier
            and vector3(store.cashier.x, store.cashier.y, store.cashier.z)
            or store.coords
        if coords then
            local distance = #(pos - coords)
            if distance < bestDistance then
                best = { label = store.label or '24/7 Store', coords = coords }
                bestDistance = distance
            end
        end
    end
    return best, bestDistance
end

local function openFishSellMenu()
    if shopOpen or IsNuiFocused() then return end
    CreateThread(function()
        local invData, err = Sunset.AwaitCallback('sunset:fishingshop:getFishInventory')
        if not invData then
            exports.sunset_ui:Notify(err or 'Could not read your fish inventory.', 'error')
            return
        end
        if not invData.items or #invData.items == 0 then
            exports.sunset_ui:Notify('You have no fish to sell. Caught fish appear in your inventory.', 'info', 6500)
            return
        end

        local buyer, distance = nearestFishBuyer()
        if not buyer or distance > 6.0 then
            SetNewWaypoint(buyer.coords.x, buyer.coords.y)
            exports.sunset_ui:Notify(('GPS set to %s. Talk to the cashier and choose Sell Fish.'):format(buyer.label), 'info', 8000)
            return
        end

        exports.sunset_ui:Send('fishingShopShow', {
            mode = 'sell',
            title = 'SELL FISH',
            cash = invData.cash,
            items = invData.items,
        })
        exports.sunset_ui:SetFocus(true, true)
        shopOpen = true
    end)
end

local hillbillyPed   = nil
local nearNpc        = false
local nearBaitShop   = false
local storeContext   = nil
local menuOpen       = false   -- playerInteraction menu open
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
    open_shop_247 = true,
    buy_business = true,
    manage_business = true,
}

local function isAllowedMenuAction(action)
    return action and FISHING_ACTIONS[action] == true
end

local function formatMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return '$' .. formatted
end

local function buildStoreActions(ctx)
    local actions = {}
    local shopLabel = (ctx and ctx.shopLabel) or '24/7 Store'
    actions[#actions + 1] = {
        id = 'open_shop_247',
        label = ('Open %s'):format(shopLabel),
        group = 'STORE',
    }
    actions[#actions + 1] = {
        id = 'sell_fish_247',
        label = 'Sell Fish',
        group = 'STORE',
    }

    local biz = ctx and ctx.business
    if biz and not biz.owned and biz.forSale then
        actions[#actions + 1] = {
            id = 'buy_business',
            label = ('Buy Business (%s)'):format(formatMoney(biz.price)),
            group = 'BUSINESS',
        }
    elseif biz and biz.mine then
        actions[#actions + 1] = {
            id = 'manage_business',
            label = 'Manage Business',
            group = 'BUSINESS',
        }
    end

    return actions
end

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
    if GetResourceState('sunset_world') == 'started' and SunsetWorld and SunsetWorld.Npc then
        SunsetWorld.Npc.hideTooltip('fisherman_billy')
    end
end

sendBillyHoldState = function(_active)
    -- Hold feedback handled in-game; world tooltip stays visible.
end

local function sendBillyRayPrompt()
    local ped = hillbillyPed
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        hideBillyRayPrompt()
        return
    end
    if GetResourceState('sunset_world') ~= 'started' or not SunsetWorld or not SunsetWorld.Npc then
        return
    end
    billyPromptVisible = true
    SunsetWorld.Npc.showTooltip('fisherman_billy', ped, {
        badge = 'JOB PESCAR',
        badgeClass = 'fishing',
        bodyClass = 'fishing',
        icon = 'ph-fish',
        title = 'Billy Ray',
        desc = 'Interaction / Fishing Job',
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
    storeContext = nil
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
    local errMsg = err or 'Hiring failed (no details from server).'
    debugHire(('FAIL: %s'):format(errMsg))
    if errMsg:find('already work', 1, true)
        or errMsg:find('already', 1, true) then
        exports.sunset_ui:Notify('You are already a Fisherman! Press Start Shift to begin.', 'info', 7000)
        return
    end
    exports.sunset_ui:Notify(errMsg, 'error', 8000)
end

local function syncLocalJob(job, grade)
    if not job then return end
    if Sunset.Character then
        Sunset.Character.job = job
        Sunset.Character.job_grade = grade or Sunset.Character.job_grade or 0
    end
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

local function buildBillyRayActions(job)
    local actions = {}
    job = job or getCharacterJob()

    if job ~= 'fisherman' then
        actions[#actions + 1] = { id = 'get_fisherman_job', label = 'Become a Fisherman', group = 'CIVILIAN' }
    end

    if job == 'fisherman' then
        if isOnFishermanShift() then
            actions[#actions + 1] = { id = 'end_fishing_shift', label = 'End Shift', group = 'FISHING' }
        else
            actions[#actions + 1] = { id = 'start_fishing_shift', label = 'Start Shift', group = 'FISHING' }
        end
        actions[#actions + 1] = { id = 'upgrade_fishing_rod', label = 'Upgrade Fishing Rod', group = 'FISHING' }
    end

    return actions
end

local function openBillyRayMenu()
    if menuOpen or not billyInteractionsReady() then return end
    CreateThread(function()
        local data, err = Sunset.AwaitCallback('sunset:fishingshop:getBillyRayMenu')
        if not data then
            if err then exports.sunset_ui:Notify(err, 'error', 5000) end
            return
        end
        if menuOpen or not billyInteractionsReady() then return end
        syncLocalJob(data.job, data.job_grade)
        local actions = buildBillyRayActions(data.job)
        if #actions == 0 then return end
        billyHoldStart = nil
        menuCloseArmed = false
        hideBillyRayPrompt()
        exports.sunset_ui:Send('playerInteractionShow', {
            menuTitle = 'Fishing Actions',
            target = { name = 'Billy Ray', id = '' },
            actions = actions,
        })
        exports.sunset_ui:SetFocus(true, true)
        menuOpen = true
    end)
end

exports('IsNearBillyRay', function()
    return isNearNpcMenu(GetEntityCoords(PlayerPedId()))
end)
exports('IsMenuOpen', function() return menuOpen or shopOpen end)
exports('IsNearStore', function() return nearStore end)

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

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local wasNpc       = nearNpc
        local wasBaitShop  = nearBaitShop

        nearNpc      = isNearNpcMenu(pos)
        nearBaitShop = #(pos - BAIT_SHOP_COORDS) < BAIT_SHOP_DIST

        if wasNpc and not nearNpc and menuOpen then
            closeFishingMenu()
        end

        if wasBaitShop and not nearBaitShop and shopOpen then
            exports.sunset_ui:Send('fishingShopHide', {})
            exports.sunset_ui:SetFocus(false, false)
            shopOpen = false
        end

        Wait((nearNpc or nearBaitShop) and 0 or 350)
    end
end)

-- ── E key handler ─────────────────────────────────────────────
CreateThread(function()
    while true do
        if nearNpc or nearBaitShop then
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
            if nearBaitShop and not nearNpc and not inCooldown and not menuOpen and not shopOpen and not IsNuiFocused() then
                pressed = IsDisabledControlJustPressed(0, INTERACT_KEY)
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
                            exports.sunset_ui:Notify(err or 'Could not open the shop.', 'error')
                        end
                        SetTimeout(1500, function() inCooldown = false end)
                    end)
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
    if not isAllowedMenuAction(data.action) then return end
    if not menuOpen then return end

    local action = data.action
    local ctx = storeContext
    closeFishingMenu()
    storeContext = nil

    if action == 'open_shop_247' then
        local shopId = (ctx and ctx.shopId) or 'twentyfour7'
        local shop = Sunset.Shops and Sunset.Shops[shopId]
        if not shop then
            exports.sunset_ui:Notify('Shop unavailable.', 'error')
            return
        end
        TriggerEvent('sunset:world:openShop', shopId, shop)

    elseif action == 'buy_business' then
        local biz = ctx and ctx.business
        if not biz or not biz.id then
            exports.sunset_ui:Notify('This business is not for sale.', 'error')
            return
        end
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:buyBusiness', biz.id)
            if ok then
                exports.sunset_ui:Notify(err or 'Business purchased.', 'success')
            else
                exports.sunset_ui:Notify(err or 'Could not buy business.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif action == 'manage_business' then
        TriggerEvent('sunset:businesses:openOwner')

    elseif action == 'get_fisherman_job' then
        inCooldown = true
        debugHire('request hire fisherman')
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:fishingshop:hireFisherman')
            debugHire(('callback ok=%s err=%s'):format(tostring(ok), tostring(err)))
            if ok then
                syncLocalJob('fisherman', 0)
                if err == 'already' then
                    exports.sunset_ui:Notify('You are already a Fisherman! Press Start Shift to begin.', 'info', 8000)
                else
                    exports.sunset_ui:Notify('You are now a Fisherman! Press Start Shift to begin.', 'success', 8000)
                end
            else
                notifyHireError(err)
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif action == 'start_fishing_shift' then
        inCooldown = true
        TriggerEvent('sunset:client:startFishermanShift')
        SetTimeout(2000, function() inCooldown = false end)

    elseif action == 'end_fishing_shift' then
        inCooldown = true
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:jobs:fisherman:endShift')
            if ok then
                exports.sunset_ui:Notify('Fishing shift ended.', 'success', 5000)
            else
                exports.sunset_ui:Notify(err or 'You have no active shift.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif action == 'upgrade_fishing_rod' then
        inCooldown = true
        CreateThread(function()
            local ok, msg = Sunset.AwaitCallback('sunset:fishingshop:upgradeRod')
            if ok then
                exports.sunset_ui:Notify(msg or 'Rod upgraded!', 'success', 6000)
            else
                exports.sunset_ui:Notify(msg or 'Could not upgrade rod.', 'error')
            end
            SetTimeout(2000, function() inCooldown = false end)
        end)

    elseif action == 'sell_fish_247' then
        inCooldown = true
        CreateThread(function()
            local invData, err = Sunset.AwaitCallback('sunset:fishingshop:getFishInventory')
            if invData then
                if not invData.items or #invData.items == 0 then
                    exports.sunset_ui:Notify('You have no fish in your inventory.', 'info')
                else
                    exports.sunset_ui:Send('fishingShopShow', {
                        mode  = 'sell',
                        title = '24/7 — SELL FISH',
                        cash  = invData.cash,
                        items = invData.items,
                    })
                    exports.sunset_ui:SetFocus(true, true)
                    shopOpen = true
                end
            else
                exports.sunset_ui:Notify(err or 'Failed to load inventory.', 'error')
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
        exports.sunset_ui:Notify(('Purchase successful! -$%d'):format(ok.total or 0), 'success', 5000)
    else
        exports.sunset_ui:Notify(tostring(err or 'Purchase failed.'), 'error')
    end
end)

AddEventHandler('sunset:nui:fishingShopSell', function(data)
    local cart = data and data.cart
    if not cart or #cart == 0 then return end
    local ok, err = Sunset.AwaitCallback('sunset:fishingshop:sellCart', cart)
    if ok then
        exports.sunset_ui:Notify(tostring(ok), 'success', 5000)
    else
        exports.sunset_ui:Notify(tostring(err or 'Sale failed.'), 'error')
    end
end)

RegisterCommand('sellfish', function()
    openFishSellMenu()
end, false)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/sellfish', 'Sell fish nearby or mark the nearest fish buyer on GPS')
end)
