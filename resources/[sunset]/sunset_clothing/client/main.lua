local inShop = false

local function openClothing()
    inShop = true
    exports.sunset_ui:Send('clothingShow', { type = 'clothing' })
    exports.sunset_ui:SetFocus(true, true)
end

local function openBarber()
    inShop = true
    exports.sunset_ui:Send('clothingShow', { type = 'barber' })
    exports.sunset_ui:SetFocus(true, true)
end

AddEventHandler('sunset:nui:clothingApply', function(data)
    local ped = PlayerPedId()
    if data.type == 'clothing' then
        SetPedComponentVariation(ped, data.component or 11, data.drawable or 0, data.texture or 0, 0)
    elseif data.type == 'barber' then
        SetPedComponentVariation(ped, 2, data.hair or 0, 0, 0)
    end
    exports.sunset_ui:Notify('Appearance updated ($50)', 'success')
end)

AddEventHandler('sunset:nui:clothingClose', function()
    inShop = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('clothingHide', {})
end)

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local near = false
        for _, shop in ipairs(Sunset.ClothingShops) do
            if #(coords - shop) < 2.5 then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ — Clothing Store')
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustReleased(0, 38) then openClothing() end
                near = true
                Wait(0)
                break
            end
        end
        if not near then
            for _, shop in ipairs(Sunset.BarberShops) do
                if #(coords - shop) < 2.5 then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ — Barber')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then openBarber() end
                    near = true
                    Wait(0)
                    break
                end
            end
        end
        if not near then Wait(500) end
    end
end)
