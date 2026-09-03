local inShop = false
local shopType = nil

local function applyPreview(data)
    local ped = PlayerPedId()
    if data.type == 'clothing' then
        SetPedComponentVariation(ped, data.component or 11, data.drawable or 0, data.texture or 0, 0)
    elseif data.type == 'barber' then
        SetPedComponentVariation(ped, 2, data.hair or 0, 0, 0)
    end
end

local function openClothing()
    inShop = true
    shopType = 'clothing'
    exports.sunset_ui:Send('clothingShow', { type = 'clothing' })
    exports.sunset_ui:SetFocus(true, true)
end

local function openBarber()
    inShop = true
    shopType = 'barber'
    exports.sunset_ui:Send('clothingShow', { type = 'barber' })
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
        exports.sunset_ui:Notify('Appearance updated ($50)', 'success')
    end)
end)

AddEventHandler('sunset:nui:clothingClose', function()
    inShop = false
    shopType = nil
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('clothingHide', {})
end)
