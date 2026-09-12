local inShop = false
local shopType = nil
local savedSnapshot = nil
local previewAppearance = nil
local activeCategory = 'top'
local cartTotal = 0
local hasChanges = false
local lastWardrobeOpenAt = 0
local wardrobePendingFocus = false

local function notify(msg, kind)
    exports.sunset_ui:Notify(msg, kind or 'info')
end

local function getCharacter()
    return exports.sunset_core:GetCharacter()
end

local function captureSnapshot()
    local char = getCharacter()
    if not char then return nil end
    local appearance = char.appearance
    if not appearance and SunsetAppearance and SunsetAppearance.default then
        appearance = SunsetAppearance.default(char.gender or 0)
    end
    if not appearance then return nil end
    return {
        appearance = SunsetClothing.normalizeWardrobe(appearance, char.gender or 0),
        gender = char.gender or 0,
        purchased = false,
    }
end

local function restoreSnapshot()
    if not savedSnapshot then return end
    local ped = PlayerPedId()
    SunsetAppearance.apply(ped, savedSnapshot.appearance, savedSnapshot.gender)
    previewAppearance = nil
end

local function sendWardrobeState()
    local char = getCharacter()
    if not char or not previewAppearance then return end
    local ped = PlayerPedId()
    local catalog = SunsetClothing.buildCatalog(ped, previewAppearance, char.gender or 0, activeCategory)
    catalog.cartTotal = cartTotal
    catalog.hasChanges = hasChanges
    exports.sunset_ui:Send('wardrobeUpdate', catalog)
end

local function applyPreviewToPed()
    local char = getCharacter()
    if not char or not previewAppearance then return end
    local ped = PlayerPedId()
    previewAppearance = SunsetClothing.preview(ped, previewAppearance, char.gender or 0)
end

local function abortWardrobeOpen(err)
    wardrobePendingFocus = false
    print(('[sunset_clothing] openWardrobe failed: %s'):format(tostring(err or 'unknown')))
    notify('Could not open clothing store.', 'error')
    inShop = false
    shopType = nil
    savedSnapshot = nil
    previewAppearance = nil
    WardrobeShop.stopCamera()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:ShowHudChrome()
    exports.sunset_ui:Send('wardrobeHide', {})
    TriggerEvent('sunset:world:uiModalClose')
end

local function finishWardrobeOpen()
    if not wardrobePendingFocus or not inShop or shopType ~= 'clothing' then return end
    wardrobePendingFocus = false
    local ped = PlayerPedId()
    applyPreviewToPed()
    WardrobeShop.startCamera(ped, 'full')
    exports.sunset_ui:SetFocus(true, true)
end

local function closeShop()
    if not inShop then return end
    wardrobePendingFocus = false
    restoreSnapshot()
    WardrobeShop.stopCamera()
    inShop = false
    shopType = nil
    savedSnapshot = nil
    previewAppearance = nil
    cartTotal = 0
    hasChanges = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:ShowHudChrome()
    exports.sunset_ui:Send('wardrobeHide', {})
    TriggerEvent('sunset:world:uiModalClose')
end

local function openWardrobe()
    if inShop then return end

    -- [CLOTHING FIX B2] Shopping while in a faction uniform made the uniform
    -- the preview baseline (syncFromPed) and purchasing persisted it as the
    -- civilian appearance. Refuse to open on duty.
    local okDuty, onDuty = pcall(function() return exports.sunset_factions:IsOnDuty() end)
    if okDuty and onDuty then
        notify('Nu poti cumpara haine in uniforma. Iesi din tura mai intai.', 'error')
        return
    end

    local now = GetGameTimer()
    if now - lastWardrobeOpenAt < 500 then return end

    if IsNuiFocused() then
        exports.sunset_ui:SetFocus(false, false)
        Wait(50)
    end

    if exports.sunset_ui:IsOpen() then
        exports.sunset_ui:MarkGameplayEntered()
    end

    savedSnapshot = captureSnapshot()
    if not savedSnapshot then
        notify('Character not loaded.', 'error')
        return
    end

    local ok, err = pcall(function()
        previewAppearance = SunsetClothing.syncFromPed(savedSnapshot.appearance, PlayerPedId(), savedSnapshot.gender)
        activeCategory = 'top'
        local ped = PlayerPedId()
        local catalog = SunsetClothing.buildCatalog(ped, previewAppearance, savedSnapshot.gender, activeCategory)
        cartTotal = catalog.pricePerItem or 50
        hasChanges = false

        inShop = true
        shopType = 'clothing'
        lastWardrobeOpenAt = now
        wardrobePendingFocus = true

        exports.sunset_ui:HideHudChrome()
        exports.sunset_ui:Send('wardrobeShow', catalog)
        TriggerEvent('sunset:world:uiModalOpen')
    end)

    if not ok then
        abortWardrobeOpen(err)
        return
    end

    CreateThread(function()
        Wait(2500)
        if wardrobePendingFocus and inShop then
            finishWardrobeOpen()
        end
    end)
end

AddEventHandler('sunset:nui:wardrobeReady', function()
    finishWardrobeOpen()
end)

local function openBarber()
    if inShop then return end
    savedSnapshot = captureSnapshot()
    if not savedSnapshot then
        notify('Character not loaded.', 'error')
        return
    end
    inShop = true
    shopType = 'barber'
    local hair = savedSnapshot.appearance.hair and savedSnapshot.appearance.hair.drawable or 0
    exports.sunset_ui:HideHudChrome()
    exports.sunset_ui:Send('clothingShow', { type = 'barber', hair = hair })
    exports.sunset_ui:SetFocus(true, true)
end

-- Shared barber close (snapshot restore + focus/UI release).
local function closeBarberInternal()
    restoreSnapshot()
    inShop = false
    shopType = nil
    savedSnapshot = nil
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:ShowHudChrome()
    exports.sunset_ui:Send('clothingHide', {})
end

local function persistWardrobe()
    local char = getCharacter()
    if not char or not previewAppearance then return false, 'No preview state.' end

    local saved, err = Sunset.AwaitCallback('sunset:saveAppearance', previewAppearance, char.gender, char.id)
    if not saved then return false, err end

    if savedSnapshot then
        savedSnapshot.purchased = true
        savedSnapshot.appearance = previewAppearance
    end
    applyPreviewToPed()
    hasChanges = false
    cartTotal = SunsetClothing.buildCatalog(PlayerPedId(), previewAppearance, char.gender or 0, activeCategory).pricePerItem or 50
    sendWardrobeState()
    return true
end

AddEventHandler('sunset:world:openClothing', function()
    openWardrobe()
end)

AddEventHandler('sunset:world:openBarber', function()
    openBarber()
end)

AddEventHandler('sunset:nui:wardrobeClose', function()
    closeShop()
end)

AddEventHandler('sunset:nui:wardrobeCategory', function(data)
    if not inShop or shopType ~= 'clothing' or not previewAppearance then return end
    activeCategory = data and data.categoryId or activeCategory
    local char = getCharacter()
    if not char then return end
    local catalog = SunsetClothing.buildCatalog(PlayerPedId(), previewAppearance, char.gender or 0, activeCategory)
    WardrobeShop.setCameraMode(PlayerPedId(), catalog.camera or 'full')
    catalog.cartTotal = cartTotal
    catalog.hasChanges = hasChanges
    exports.sunset_ui:Send('wardrobeUpdate', catalog)
end)

AddEventHandler('sunset:nui:wardrobePreview', function(data)
    if not inShop or shopType ~= 'clothing' or not previewAppearance then return end
    local char = getCharacter()
    if not char then return end

    local categoryId = data.categoryId or activeCategory
    activeCategory = categoryId
    previewAppearance = SunsetClothing.setCategorySelection(
        previewAppearance,
        PlayerPedId(),
        char.gender or 0,
        categoryId,
        tonumber(data.drawable),
        tonumber(data.texture)
    )
    hasChanges = true
    cartTotal = (SunsetClothing.buildCatalog(PlayerPedId(), previewAppearance, char.gender or 0, categoryId).pricePerItem or 50)
    applyPreviewToPed()
    sendWardrobeState()
end)

AddEventHandler('sunset:nui:wardrobePurchase', function()
    if not inShop or shopType ~= 'clothing' then return end
    CreateThread(function()
        if not hasChanges then
            notify('No changes to purchase.', 'info')
            return
        end
        local amount = cartTotal
        local paid, payErr = Sunset.AwaitCallback('sunset:payAppearance', amount)
        if not paid then
            notify(payErr or 'Not enough money', 'error')
            return
        end
        local saved, saveErr = persistWardrobe()
        if not saved then
            -- [CLOTHING FIX B4] Money was taken but the save failed: refund via
            -- the server so the player never loses cash silently.
            Sunset.AwaitCallback('sunset:refundAppearance', amount)
            notify(saveErr or 'Could not save appearance. You were refunded.', 'error')
            restoreSnapshot()
            return
        end
        notify(('Outfit purchased ($%s)'):format(amount), 'success')
    end)
end)

AddEventHandler('sunset:nui:clothingPreview', function(data)
    if shopType ~= 'barber' then return end
    local ped = PlayerPedId()
    -- [CLOTHING FIX B8] clamp raw NUI value to the actual hair range
    local hair = math.floor(tonumber(data.hair) or 0)
    local maxHair = math.max(0, GetNumberOfPedDrawableVariations(ped, 2) - 1)
    hair = math.max(0, math.min(hair, maxHair))
    SetPedComponentVariation(ped, 2, hair, 0, 2)
end)

AddEventHandler('sunset:nui:clothingApply', function(data)
    if shopType ~= 'barber' then return end
    CreateThread(function()
        if data.pay then
            local ok, err = Sunset.AwaitCallback('sunset:payAppearance', 50)
            if not ok then
                notify(err or 'Not enough money', 'error')
                return
            end
        end
        local char = getCharacter()
        if not char then return end
        local appearance = SunsetClothing.normalizeWardrobe(char.appearance, char.gender or 0)
        appearance.hair = appearance.hair or {}
        appearance.hair.drawable = tonumber(data.hair) or 0
        appearance.hair.texture = 0
        local saved, saveErr = Sunset.AwaitCallback('sunset:saveAppearance', appearance, char.gender, char.id)
        if not saved then
            notify(saveErr or 'Could not save appearance', 'error')
            restoreSnapshot()
            return
        end
        SunsetAppearance.apply(PlayerPedId(), appearance, char.gender or 0)
        notify('Appearance updated ($50)', 'success')
    end)
end)

AddEventHandler('sunset:nui:clothingClose', function()
    if shopType == 'barber' then
        closeBarberInternal()
        return
    end
    closeShop()
end)

CreateThread(function()
    while true do
        if inShop then
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustReleased(0, 200) then
                if shopType == 'barber' then
                    closeBarberInternal()
                else
                    closeShop()
                end
            end
            -- [CLOTHING FIX B3] Walk-away: leaving the shop zone while previewing
            -- restores the snapshot and closes (previously the preview stayed and
            -- the shop remained open far from any store).
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local nearAny = false
            local list = (shopType == 'barber') and Sunset.BarberShops or Sunset.ClothingShops
            for _, shop in ipairs(list or {}) do
                if #(coords - shop) <= 15.0 then nearAny = true break end
            end
            if not nearAny then
                if shopType == 'barber' then
                    closeBarberInternal()
                else
                    closeShop()
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

RegisterCommand('closewardrobe', function()
    if inShop then closeShop() end
end, false)

-- [CLOTHING C8] Saved outfits: /outfits list/save/equip/delete via chat (a
-- dedicated NUI panel can replace this later without server changes).
RegisterNetEvent('sunset:clothing:applyAppearance', function(appearance)
    local char = getCharacter()
    if not char then return end
    SunsetAppearance.apply(PlayerPedId(), appearance, char.gender or 0)
end)

RegisterCommand('outfits', function(_, args)
    local sub = args[1] and string.lower(args[1]) or 'list'

    if sub == 'list' or sub == 'lista' then
        local res = Sunset.AwaitCallback('sunset:outfits:list')
        if not res then notify('Nu s-a putut incarca lista de outfit-uri.', 'error') return end
        TriggerEvent('chat:addMessage', { color = { 0, 255, 204 }, args = { 'OUTFITS', ('Salvate: %d/%d. Foloseste /outfits save <nume>, /outfits wear <numar>, /outfits delete <numar>.'):format(#res.outfits, res.max) } })
        for i, row in ipairs(res.outfits) do
            TriggerEvent('chat:addMessage', { color = { 220, 220, 220 }, args = { ('%d. %s'):format(i, row.name), '' } })
        end
        return
    end

    if sub == 'save' then
        -- Block saving the faction uniform as a civilian outfit (same class of
        -- bug as shopping while on duty).
        local okDuty, onDuty = pcall(function() return exports.sunset_factions:IsOnDuty() end)
        if okDuty and onDuty then
            notify('Nu poti salva uniforma de serviciu ca outfit. Iesi din tura.', 'error')
            return
        end
        local name = table.concat(args, ' ', 2)
        if name == '' then notify('Utilizare: /outfits save <nume>', 'info') return end
        local snapshot = SunsetAppearance.GetClothingSnapshot(PlayerPedId())
        local ok, kind = Sunset.AwaitCallback('sunset:outfits:save', name, snapshot)
        if ok then
            notify(kind == 'existing' and 'Outfit actualizat.' or 'Outfit salvat.', 'success')
        else
            notify(kind or 'Nu s-a putut salva outfit-ul.', 'error')
        end
        return
    end

    if sub == 'wear' or sub == 'equip' then
        local res = Sunset.AwaitCallback('sunset:outfits:list')
        local idx = tonumber(args[2])
        if not res or not idx or not res.outfits[idx] then notify('Numar invalid. Foloseste /outfits list.', 'error') return end
        local ok, err = Sunset.AwaitCallback('sunset:outfits:equip', res.outfits[idx].id)
        if ok then notify(('Outfit "%s" echipat.'):format(res.outfits[idx].name), 'success')
        else notify(err or 'Echipare esuata.', 'error') end
        return
    end

    if sub == 'delete' then
        local res = Sunset.AwaitCallback('sunset:outfits:list')
        local idx = tonumber(args[2])
        if not res or not idx or not res.outfits[idx] then notify('Numar invalid.', 'error') return end
        local ok = Sunset.AwaitCallback('sunset:outfits:delete', res.outfits[idx].id)
        notify(ok and 'Outfit sters.' or 'Stergere esuata.', ok and 'success' or 'error')
        return
    end

    notify('Utilizare: /outfits [list|save <nume>|wear <nr>|delete <nr>]', 'info')
end, false)
TriggerEvent('chat:addSuggestion', '/outfits', 'Gestioneaza outfit-urile salvate', {
    { name = 'actiune', help = 'list / save / wear / delete' },
    { name = 'nume/nr', help = 'nume pentru save, numar pentru wear/delete' },
})

-- [CLOTHING FIX B3] Guaranteed cleanup: death, jail and resource stop used to
-- leave the scripted camera, inShop flag and NUI focus dangling with the
-- preview clothes still on the ped.
local function forceCloseAll(reason)
    if not inShop then return end
    restoreSnapshot()
    WardrobeShop.stopCamera()
    inShop = false
    shopType = nil
    savedSnapshot = nil
    previewAppearance = nil
    cartTotal = 0
    hasChanges = false
    wardrobePendingFocus = false
    exports.sunset_ui:SetFocus(false, false, false, 'force')
    exports.sunset_ui:ShowHudChrome()
    exports.sunset_ui:Send('wardrobeHide', {})
    exports.sunset_ui:Send('clothingHide', {})
    TriggerEvent('sunset:world:uiModalClose')
    if reason then notify(reason, 'info') end
end

AddEventHandler('sunset:death:playerDownedLocal', function() forceCloseAll() end)

CreateThread(function()
    while true do
        Wait(500)
        -- Local death watchdog: sunset_death has no client downed event, so
        -- watch the ped directly while the shop is open.
        if inShop then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
                forceCloseAll()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Cannot restore appearance reliably if sunset_appearance also stopped;
    -- but release camera/focus so nothing is stuck.
    pcall(function()
        restoreSnapshot()
        WardrobeShop.stopCamera()
        exports.sunset_ui:SetFocus(false, false, false, 'force')
        exports.sunset_ui:ShowHudChrome()
    end)
end)
