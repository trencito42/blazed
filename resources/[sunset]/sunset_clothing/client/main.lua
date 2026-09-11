local inShop = false
local shopType = nil
local savedSnapshot = nil
local previewAppearance = nil
local activeCategory = 'top'
local cartTotal = 0
local hasChanges = false
local lastWardrobeOpenAt = 0

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

local function closeShop()
    if not inShop then return end
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

    local now = GetGameTimer()
    if now - lastWardrobeOpenAt < 500 then return end

    if IsNuiFocused() then
        exports.sunset_ui:SetFocus(false, false)
        Wait(50)
    end

    if exports.sunset_ui:IsOpen() then
        exports.sunset_ui:Hide()
        Wait(50)
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

        exports.sunset_ui:HideHudChrome()
        exports.sunset_ui:Send('wardrobeShow', catalog)
        TriggerEvent('sunset:world:uiModalOpen')
        Wait(100)

        applyPreviewToPed()
        WardrobeShop.startCamera(ped, 'full')
        exports.sunset_ui:SetFocus(true, true)
    end)

    if not ok then
        print(('[sunset_clothing] openWardrobe failed: %s'):format(tostring(err)))
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
end

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
            notify(saveErr or 'Could not save appearance', 'error')
            restoreSnapshot()
            return
        end
        notify(('Outfit purchased ($%s)'):format(amount), 'success')
    end)
end)

AddEventHandler('sunset:nui:clothingPreview', function(data)
    if shopType ~= 'barber' then return end
    local ped = PlayerPedId()
    SetPedComponentVariation(ped, 2, tonumber(data.hair) or 0, 0, 2)
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
        restoreSnapshot()
        inShop = false
        shopType = nil
        savedSnapshot = nil
        exports.sunset_ui:SetFocus(false, false)
        exports.sunset_ui:ShowHudChrome()
        exports.sunset_ui:Send('clothingHide', {})
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
                    restoreSnapshot()
                    inShop = false
                    shopType = nil
                    savedSnapshot = nil
                    exports.sunset_ui:SetFocus(false, false)
                    exports.sunset_ui:ShowHudChrome()
                    exports.sunset_ui:Send('clothingHide', {})
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
