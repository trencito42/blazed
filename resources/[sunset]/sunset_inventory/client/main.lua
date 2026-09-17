local inventoryOpen = false
local tradeActive = false
local tradeInviteActive = false
local TRADE_HOLD_MS = 750
local tradeHoldAcceptStart = nil
local tradeHoldDeclineStart = nil

local function hideTradeInviteUi()
    tradeInviteActive = false
    tradeHoldAcceptStart = nil
    tradeHoldDeclineStart = nil
    exports.sunset_ui:Send('inventoryTradeInviteHide', {})
end

local function sendTradeHold(key, progress, release)
    exports.sunset_ui:Send('inventoryTradeInviteHold', {
        key = key,
        progress = progress or 0,
        release = release == true,
    })
end

local function openInventory()
    local data, err = Sunset.AwaitCallback('sunset:getInventory')
    if not data then
        return exports.sunset_ui:Notify(err or 'Inventory could not be loaded. Your character may still be loading; try again in a moment.', 'error')
    end
    inventoryOpen = true
    -- [BUGFIX] EnrichInventoryPayload was deleted with the quickbar but these
    -- call sites remained. In FiveM, exports.res.X returns a truthy proxy even
    -- for UNDEFINED exports, so the guard passed and the call errored ->
    -- openInventory died before inventoryShow (inventory would not open).
    exports.sunset_ui:SetFocus(true, true)
    exports.sunset_ui:Send('inventoryShow', data)
end

local function closeInventory()
    if tradeActive then
        tradeActive = false
        CreateThread(function()
            Sunset.AwaitCallback('sunset:inventory:tradeCancel', {})
        end)
    end
    inventoryOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('inventoryHide', {})
end

RegisterNetEvent('sunset:client:inventoryUpdate', function(items, weight, cash, maxWeight)
    if inventoryOpen then
        local currentCash = cash
        if not currentCash then
            local char = exports.sunset_core:GetCharacter()
            currentCash = (char and tonumber(char.cash)) or 0
        end
        -- [DUFFEL BAG FIX] Use the server-sent effective capacity (base + bag bonus).
        local payload = { items = items, weight = weight, maxWeight = tonumber(maxWeight) or Sunset.Config.MaxWeight, cash = currentCash }
        -- [BUGFIX] EnrichInventoryPayload removed (see openInventory note).
        exports.sunset_ui:Send('inventoryUpdate', payload)
    end
end)

AddEventHandler('sunset:client:playerSpawned', function()
    TriggerServerEvent('sunset:server:inventoryLoaded')
end)

AddEventHandler('sunset:nui:inventoryClose', function()
    closeInventory()
end)

RegisterNetEvent('sunset:client:inventoryForceClose', function()
    closeInventory()
end)

local activeItemProp = nil

local function cleanupItemProp()
    if activeItemProp and DoesEntityExist(activeItemProp) then
        DeleteEntity(activeItemProp)
    end
    activeItemProp = nil
end

RegisterNetEvent('sunset:inventory:client:usedItem', function(item, category, extra1, extra2)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    cleanupItemProp()

    if category == 'ammo' then
        local weaponName = extra1
        local rounds = extra2 or 24
        if IsPedArmed(ped, 4) then
            MakePedReload(ped)
        else
            local animDict = 'anim@weapons@first_person@aim_rng@generic@pistol@combatpistol@'
            local animName = 'reload_str'
            RequestAnimDict(animDict)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(10) end
            if HasAnimDictLoaded(animDict) then
                TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, 1200, 49, 0, false, false, false)
            end
        end
        local cleanName = tostring(weaponName or 'weapon'):gsub('^WEAPON_', '')
        exports.sunset_ui:Notify(('Loaded %d rounds into %s.'):format(rounds, cleanName), 'success')
        return
    end

    if category == 'drinks' then
        local propModel = `prop_ld_can_01`
        if item == 'beer' then
            propModel = `prop_cs_beer_bot`
        elseif item == 'coffee' then
            propModel = `prop_fib_coffee`
        elseif item == 'wine' or item == 'champagne' then
            propModel = `prop_wine_bot_01`
        elseif item == 'whiskey' or item == 'cocktail' then
            propModel = `prop_drink_whisky`
        elseif item == 'water' then
            propModel = `prop_ld_flow_bottle`
        end

        local animDict = 'mp_player_intdrink'
        local animName = 'loop_bottle'
        RequestAnimDict(animDict)
        RequestModel(propModel)
        local timeout = GetGameTimer() + 2000
        while (not HasAnimDictLoaded(animDict) or not HasModelLoaded(propModel)) and GetGameTimer() < timeout do Wait(10) end

        local bone = GetPedBoneIndex(ped, 18905)
        local coords = GetEntityCoords(ped)
        local prop = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(prop, ped, bone, 0.12, 0.008, 0.03, -100.0, 0.0, -10.0, true, true, false, true, 1, true)
        activeItemProp = prop

        TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, 3200, 49, 0, false, false, false)

        CreateThread(function()
            Wait(3200)
            cleanupItemProp()
            StopAnimTask(ped, animDict, animName, 1.0)
            SetModelAsNoLongerNeeded(propModel)
            RemoveAnimDict(animDict)
        end)
        return
    end

    if category == 'food' then
        local propModel = `prop_cs_burger_01`
        if item == 'sandwich' then
            propModel = `prop_sandwich_01`
        elseif item == 'hotdog' then
            propModel = `prop_cs_hotdog_01`
        elseif item == 'apple' then
            propModel = `ng_proc_food_ap1`
        elseif item == 'banana' then
            propModel = `ng_proc_food_nana1a`
        end

        local animDict = 'mp_player_inteat@burger'
        local animName = 'mp_player_int_eat_burger'
        RequestAnimDict(animDict)
        RequestModel(propModel)
        local timeout = GetGameTimer() + 2000
        while (not HasAnimDictLoaded(animDict) or not HasModelLoaded(propModel)) and GetGameTimer() < timeout do Wait(10) end

        local bone = GetPedBoneIndex(ped, 18905)
        local coords = GetEntityCoords(ped)
        local prop = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(prop, ped, bone, 0.13, 0.05, 0.02, -50.0, 16.0, 60.0, true, true, false, true, 1, true)
        activeItemProp = prop

        TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, 3500, 49, 0, false, false, false)

        CreateThread(function()
            Wait(3500)
            cleanupItemProp()
            StopAnimTask(ped, animDict, animName, 1.0)
            SetModelAsNoLongerNeeded(propModel)
            RemoveAnimDict(animDict)
        end)
        return
    end

    if category == 'medical' or item == 'bandage' or item == 'painkillers' then
        if item == 'painkillers' then
            local animDict = 'mp_suicide'
            local animName = 'pill'
            RequestAnimDict(animDict)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(10) end
            TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, 2000, 49, 0, false, false, false)
            CreateThread(function()
                Wait(2000)
                StopAnimTask(ped, animDict, animName, 1.0)
                RemoveAnimDict(animDict)
            end)
        else
            local animDict = 'missheistdockssetup1clipboard@idle_a'
            local animName = 'idle_a'
            RequestAnimDict(animDict)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(10) end
            TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, 2500, 49, 0, false, false, false)
            CreateThread(function()
                Wait(2500)
                StopAnimTask(ped, animDict, animName, 1.0)
                RemoveAnimDict(animDict)
            end)
        end
        return
    end

    if item == 'cigarette' or category == 'supplies' then
        local propModel = `prop_cs_ciggy_01`
        local animDict = 'amb@world_human_smoking@male@male_a@enter'
        local animName = 'enter'
        RequestAnimDict(animDict)
        RequestModel(propModel)
        local timeout = GetGameTimer() + 2000
        while (not HasAnimDictLoaded(animDict) or not HasModelLoaded(propModel)) and GetGameTimer() < timeout do Wait(10) end

        local bone = GetPedBoneIndex(ped, 57005)
        local coords = GetEntityCoords(ped)
        local prop = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(prop, ped, bone, 0.015, -0.009, 0.003, 55.0, 0.0, 110.0, true, true, false, true, 1, true)
        activeItemProp = prop

        TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, 4000, 49, 0, false, false, false)

        CreateThread(function()
            Wait(4000)
            cleanupItemProp()
            StopAnimTask(ped, animDict, animName, 1.0)
            SetModelAsNoLongerNeeded(propModel)
            RemoveAnimDict(animDict)
        end)
        return
    end
end)

AddEventHandler('sunset:nui:inventoryUse', function(data)
    local ok, err = Sunset.AwaitCallback('sunset:useItem', data.item)
    if not ok then exports.sunset_ui:Notify(err or 'Cannot use item', 'error') end
end)

local function inventoryAction(callbackName, data)
    CreateThread(function()
        local result, err = Sunset.AwaitCallback(callbackName, data or {})
        if not result then
            exports.sunset_ui:Notify(err or 'Inventory action failed. Reopen the inventory and try again.', 'error')
        elseif type(result) == 'table' and result.message then
            -- [FIX] Several server callbacks return plain `true` (e.g. trade
            -- confirm/accept); indexing a boolean crashed this handler.
            exports.sunset_ui:Notify(result.message, result.kind or 'success')
        end
    end)
end

AddEventHandler('sunset:nui:inventoryTradeRequest', function(data)
    inventoryAction('sunset:inventory:tradeRequest', data)
end)

AddEventHandler('sunset:nui:inventoryTradeAccept', function()
    hideTradeInviteUi()
    inventoryAction('sunset:inventory:tradeAccept', {})
end)

AddEventHandler('sunset:nui:inventoryTradeDecline', function()
    hideTradeInviteUi()
    inventoryAction('sunset:inventory:tradeDecline', {})
end)

AddEventHandler('sunset:nui:inventoryTradeOffer', function(data)
    inventoryAction('sunset:inventory:tradeOffer', data)
end)

AddEventHandler('sunset:nui:inventoryTradeRemove', function(data)
    inventoryAction('sunset:inventory:tradeRemove', data)
end)

AddEventHandler('sunset:nui:inventoryTradeOfferCash', function(data)
    inventoryAction('sunset:inventory:tradeOfferCash', data)
end)

AddEventHandler('sunset:nui:inventoryTradeRemoveCash', function()
    inventoryAction('sunset:inventory:tradeRemoveCash', {})
end)

AddEventHandler('sunset:nui:inventoryTradeCatalog', function()
    CreateThread(function()
        local catalog, err = Sunset.AwaitCallback('sunset:inventory:tradeCatalog', {})
        if catalog then
            exports.sunset_ui:Send('inventoryTradeCatalog', catalog)
        else
            exports.sunset_ui:Notify(err or 'Could not load trade assets.', 'error')
        end
    end)
end)

AddEventHandler('sunset:nui:inventoryTradeOfferAsset', function(data)
    inventoryAction('sunset:inventory:tradeOfferAsset', data)
end)

AddEventHandler('sunset:nui:inventoryTradeRemoveAsset', function(data)
    inventoryAction('sunset:inventory:tradeRemoveAsset', data)
end)

AddEventHandler('sunset:nui:inventoryTradeConfirm', function(data)
    inventoryAction('sunset:inventory:tradeConfirm', data)
end)

AddEventHandler('sunset:nui:inventoryTradeCancel', function(data)
    inventoryAction('sunset:inventory:tradeCancel', data)
end)

AddEventHandler('sunset:nui:inventoryDrop', function(data)
    inventoryAction('sunset:inventory:drop', data)
end)

AddEventHandler('sunset:nui:inventoryMoveSlot', function(data)
    inventoryAction('sunset:inventory:moveSlot', data)
end)

RegisterNetEvent('sunset:inventory:tradeState', function(data)
    tradeActive = data and data.active == true
    if tradeActive then
        -- Trade owns its own inventory catalogue. Never stack the standalone
        -- inventory above it; that produced two competing modals and focus traps.
        if inventoryOpen then
            inventoryOpen = false
            exports.sunset_ui:Send('inventoryHide', {})
        end
        -- [FOCUS FIX] Use owner='trade' so ReleaseFocusUnlessModal('legacy')
        -- called by playerInteraction menus closing cannot accidentally steal
        -- focus away from the trade window (which leaves it visible but dead:
        -- hover works but no buttons respond and the player must /reconnect).
        exports.sunset_ui:SetFocus(true, true, false, 'trade')
    end
    exports.sunset_ui:Send('inventoryTradeState', data or {})
end)

RegisterNetEvent('sunset:inventory:tradeEnded', function(message, kind)
    tradeActive = false
    exports.sunset_ui:Send('inventoryTradeEnded', {})
    -- [FOCUS FIX] Match the 'trade' owner used on open so the release is not
    -- blocked by the focus-owner guard (if it were 'legacy' here but 'trade'
    -- set it, the guard would refuse the release and the cursor would stay stuck).
    exports.sunset_ui:SetFocus(false, false, false, 'trade')
    if message then exports.sunset_ui:Notify(message, kind or 'info') end
end)

RegisterNetEvent('sunset:inventory:tradeInvite', function(requesterId, requesterName)
    tradeInviteActive = true
    tradeHoldAcceptStart = nil
    tradeHoldDeclineStart = nil
    exports.sunset_ui:Send('inventoryTradeInvite', {
        requesterId = tonumber(requesterId) or 0,
        requesterName = requesterName or 'A nearby player',
        timeout = 30,
        holdMs = TRADE_HOLD_MS,
    })
end)

RegisterCommand('accepttrade', function()
    if not tradeInviteActive then return end
    hideTradeInviteUi()
    inventoryAction('sunset:inventory:tradeAccept', {})
end, false)

RegisterCommand('declinetrade', function()
    if not tradeInviteActive then return end
    hideTradeInviteUi()
    inventoryAction('sunset:inventory:tradeDecline', {})
end, false)

local function tradeHoldPress(kind)
    if not tradeInviteActive then return end
    if kind == 'accept' then
        tradeHoldDeclineStart = nil
        sendTradeHold('decline', 0, true)
        if not tradeHoldAcceptStart then
            tradeHoldAcceptStart = GetGameTimer()
            sendTradeHold('accept', 0)
        end
    else
        tradeHoldAcceptStart = nil
        sendTradeHold('accept', 0, true)
        if not tradeHoldDeclineStart then
            tradeHoldDeclineStart = GetGameTimer()
            sendTradeHold('decline', 0)
        end
    end
end

local function tradeHoldRelease(kind)
    if kind == 'accept' then
        tradeHoldAcceptStart = nil
        sendTradeHold('accept', 0, true)
    else
        tradeHoldDeclineStart = nil
        sendTradeHold('decline', 0, true)
    end
end

RegisterCommand('+sunset_trade_accept', function() tradeHoldPress('accept') end, false)
RegisterCommand('-sunset_trade_accept', function() tradeHoldRelease('accept') end, false)
RegisterKeyMapping('+sunset_trade_accept', 'Hold Y to accept trade invite', 'keyboard', 'Y')

RegisterCommand('+sunset_trade_decline', function() tradeHoldPress('decline') end, false)
RegisterCommand('-sunset_trade_decline', function() tradeHoldRelease('decline') end, false)
RegisterKeyMapping('+sunset_trade_decline', 'Hold N to decline trade invite', 'keyboard', 'N')

CreateThread(function()
    while true do
        if tradeInviteActive then
            local now = GetGameTimer()
            if tradeHoldAcceptStart then
                local elapsed = now - tradeHoldAcceptStart
                local progress = math.min(100, (elapsed / TRADE_HOLD_MS) * 100)
                sendTradeHold('accept', progress)
                if elapsed >= TRADE_HOLD_MS then
                    hideTradeInviteUi()
                    inventoryAction('sunset:inventory:tradeAccept', {})
                end
            elseif tradeHoldDeclineStart then
                local elapsed = now - tradeHoldDeclineStart
                local progress = math.min(100, (elapsed / TRADE_HOLD_MS) * 100)
                sendTradeHold('decline', progress)
                if elapsed >= TRADE_HOLD_MS then
                    hideTradeInviteUi()
                    inventoryAction('sunset:inventory:tradeDecline', {})
                end
            end
            Wait(16)
        else
            Wait(250)
        end
    end
end)

RegisterCommand('inventory', function()
    if inventoryOpen then
        closeInventory()
        return
    end
    if IsNuiFocused() then return end
    if IsPauseMenuActive() then return end
    local ok, chatOpen = pcall(function() return exports.sunset_chat:IsChatOpen() end)
    if ok and chatOpen then return end
    openInventory()
end, false)
RegisterKeyMapping('inventory', 'Toggle inventory', 'keyboard', 'I')

CreateThread(function()
    while true do
        if inventoryOpen and IsPauseMenuActive() then
            closeInventory()
        end
        Wait(inventoryOpen and 50 or 250)
    end
end)

exports('Open', openInventory)
exports('Close', closeInventory)

local worldDrops = {}
local dropObjects = {}
local DROP_MODEL = `prop_cs_heist_bag_02`

local function removeDropObject(dropId)
    local object = dropObjects[dropId]
    if object and DoesEntityExist(object) then DeleteEntity(object) end
    dropObjects[dropId] = nil
end

local function configureDropObject(object)
    if not object or object == 0 or not DoesEntityExist(object) then return end
    SetEntityDynamic(object, false)
    SetEntityInvincible(object, true)
    SetEntityCanBeDamaged(object, false)
    SetEntityRecordsCollisions(object, false)
    FreezeEntityPosition(object, true)
    SetEntityCollision(object, false, false)
    SetEntityCompletelyDisableCollision(object, true, true)
    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        SetEntityNoCollisionEntity(object, ped, true)
    end
end

local function createDropObject(drop)
    CreateThread(function()
        RequestModel(DROP_MODEL)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(DROP_MODEL) and GetGameTimer() < timeout do Wait(20) end
        if not HasModelLoaded(DROP_MODEL) or not worldDrops[drop.id] then return end
        local c = drop.coords
        local object = CreateObjectNoOffset(DROP_MODEL, c.x, c.y, c.z - 0.02, false, false, false)
        PlaceObjectOnGroundProperly(object)
        configureDropObject(object)
        dropObjects[drop.id] = object
        SetModelAsNoLongerNeeded(DROP_MODEL)
        for _ = 1, 8 do
            Wait(75)
            if not DoesEntityExist(object) or not worldDrops[drop.id] then return end
            configureDropObject(object)
        end
    end)
end

RegisterNetEvent('sunset:inventory:dropSync', function(action, drop)
    if type(drop) ~= 'table' or not tonumber(drop.id) then return end
    drop.id = tonumber(drop.id)
    if action == 'remove' then
        worldDrops[drop.id] = nil
        removeDropObject(drop.id)
        return
    end
    worldDrops[drop.id] = drop
    removeDropObject(drop.id)
    createDropObject(drop)
end)

local function drawDropText(coords, text)
    local visible, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 0.45)
    if not visible then return end
    SetTextFont(4)
    SetTextScale(0.0, 0.29)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 245)
    SetTextDropshadow(2, 0, 0, 0, 220)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('sunset:server:inventoryRequestDrops')
    while true do
        local wait = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local closestId, closestDistance
        for dropId, drop in pairs(worldDrops) do
            local c = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
            local distance = #(coords - c)
            if distance < 18.0 then
                wait = 0
                local object = dropObjects[dropId]
                if object and DoesEntityExist(object) then configureDropObject(object) end
                drawDropText(c, ('~b~[E]~s~ %s x%d'):format(drop.label or drop.item or 'Dropped item', tonumber(drop.count) or 1))
                if distance < 2.2 and (not closestDistance or distance < closestDistance) then
                    closestId, closestDistance = dropId, distance
                end
            end
        end
        if closestId and IsControlJustReleased(0, 38) then
            local result, err = Sunset.AwaitCallback('sunset:inventory:pickupDrop', closestId)
            if not result then
                exports.sunset_ui:Notify(err or 'Could not pick up this item.', 'error')
            elseif result.message then
                exports.sunset_ui:Notify(result.message, 'success')
            end
            Wait(350)
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupItemProp()
    for dropId in pairs(dropObjects) do removeDropObject(dropId) end
end)
