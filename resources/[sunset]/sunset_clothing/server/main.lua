local APPEARANCE_PRICE = 50
local MAX_DISTANCE = 15.0

local function isNearAnyShop(playerCoords)
    if Sunset and Sunset.ClothingShops then
        for _, coords in ipairs(Sunset.ClothingShops) do
            if #(playerCoords - coords) <= MAX_DISTANCE then
                return true
            end
        end
    end
    if Sunset and Sunset.BarberShops then
        for _, coords in ipairs(Sunset.BarberShops) do
            if #(playerCoords - coords) <= MAX_DISTANCE then
                return true
            end
        end
    end
    return false
end

exports.sunset_core:RegisterCallback('sunset:payAppearance', function(source, amount)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return false, 'Invalid player entity'
    end

    local coords = GetEntityCoords(ped)
    if not isNearAnyShop(coords) then
        return false, 'You are not near any clothing or barber shop'
    end

    local price = APPEARANCE_PRICE
    if exports.sunset_core:RemoveMoney(source, 'cash', price, 'appearance') then
        return true
    end
    if exports.sunset_core:RemoveMoney(source, 'bank', price, 'appearance') then
        return true
    end

    return false, ('Not enough money ($%s)'):format(price)
end)
