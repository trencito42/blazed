local inShop = false
local shopType = nil
local savedSnapshot = nil

local function getCharacter()
    return exports.sunset_core:GetCharacter()
end

local function normalizeAppearance(appearance, gender)
    if SunsetAppearance and SunsetAppearance.normalize then
        return SunsetAppearance.normalize(appearance, gender)
    end
    return appearance
end

local function captureSnapshot()
    local char = getCharacter()
    if not char or not char.appearance then return nil end
    return {
        appearance = normalizeAppearance(char.appearance, char.gender or 0),
        gender = char.gender or 0,
        purchased = false,
    }
end

local function restoreSnapshot()
    if not savedSnapshot then return end
    local ped = PlayerPedId()
    if SunsetAppearance and SunsetAppearance.apply then
        SunsetAppearance.apply(ped, savedSnapshot.appearance, savedSnapshot.gender)
        return
    end
    local hair = savedSnapshot.appearance and savedSnapshot.appearance.hair
    if hair then
        SetPedComponentVariation(ped, 2, hair.drawable or 0, hair.texture or 0, 2)
    end
end

local function currentHairDrawable()
    local char = getCharacter()
    if char and char.appearance and char.appearance.hair then
        return tonumber(char.appearance.hair.drawable) or 0
    end
    return GetPedDrawableVariation(PlayerPedId(), 2)
end

local function currentTorsoDrawable()
    local char = getCharacter()
    if char and char.appearance and char.appearance.components then
        local top = char.appearance.components['11']
        if top then return tonumber(top.drawable) or 0 end
    end
    return GetPedDrawableVariation(PlayerPedId(), 11)
end

local function applyPreview(data)
    local ped = PlayerPedId()
    if data.type == 'clothing' then
        SetPedComponentVariation(ped, data.component or 11, data.drawable or 0, data.texture or 0, 0)
    elseif data.type == 'barber' then
        SetPedComponentVariation(ped, 2, data.hair or 0, 0, 0)
    end
end

local function persistAppearance(data)
    local char = getCharacter()
    if not char then return false, 'No character loaded' end

    local appearance = normalizeAppearance(char.appearance or savedSnapshot.appearance, char.gender or 0)
    if data.type == 'barber' then
        appearance.hair = appearance.hair or {}
        appearance.hair.drawable = tonumber(data.hair) or 0
        appearance.hair.texture = 0
    elseif data.type == 'clothing' then
        local slot = tostring(data.component or 11)
        appearance.components = appearance.components or {}
        appearance.components[slot] = appearance.components[slot] or { drawable = 0, texture = 0 }
        appearance.components[slot].drawable = tonumber(data.drawable) or 0
        appearance.components[slot].texture = tonumber(data.texture) or 0
        if SunsetAppearance and SunsetAppearance.syncTorso then
            appearance = SunsetAppearance.syncTorso(appearance, PlayerPedId(), char.gender or 0)
        end
    end

    local ok, err = Sunset.AwaitCallback('sunset:saveAppearance', appearance, char.gender, char.id)
    if not ok then return false, err end

    if savedSnapshot then
        savedSnapshot.purchased = true
        savedSnapshot.appearance = appearance
    end
    if SunsetAppearance and SunsetAppearance.apply then
        SunsetAppearance.apply(PlayerPedId(), appearance, char.gender or 0)
    end
    return true
end

local function openClothing()
    savedSnapshot = captureSnapshot()
    inShop = true
    shopType = 'clothing'
    exports.sunset_ui:Send('clothingShow', {
        type = 'clothing',
        drawable = currentTorsoDrawable(),
    })
    exports.sunset_ui:SetFocus(true, true)
end

local function openBarber()
    savedSnapshot = captureSnapshot()
    inShop = true
    shopType = 'barber'
    exports.sunset_ui:Send('clothingShow', {
        type = 'barber',
        hair = currentHairDrawable(),
    })
    exports.sunset_ui:SetFocus(true, true)
end

AddEventHandler('sunset:world:openClothing', function()
    if IsNuiFocused() then return end
    openClothing()
end)

AddEventHandler('sunset:world:openBarber', function()
    if IsNuiFocused() then return end
    openBarber()
end)

AddEventHandler('sunset:nui:clothingPreview', function(data)
    applyPreview(data)
end)

AddEventHandler('sunset:nui:clothingApply', function(data)
    CreateThread(function()
        if data.pay then
            local ok, err = Sunset.AwaitCallback('sunset:payAppearance', 50)
            if not ok then
                exports.sunset_ui:Notify(err or 'Not enough money', 'error')
                return
            end
        end
        applyPreview(data)
        local saved, saveErr = persistAppearance(data)
        if not saved then
            exports.sunset_ui:Notify(saveErr or 'Could not save appearance', 'error')
            restoreSnapshot()
            return
        end
        exports.sunset_ui:Notify('Appearance updated ($50)', 'success')
    end)
end)

AddEventHandler('sunset:nui:clothingClose', function()
    restoreSnapshot()
    inShop = false
    shopType = nil
    savedSnapshot = nil
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('clothingHide', {})
end)
