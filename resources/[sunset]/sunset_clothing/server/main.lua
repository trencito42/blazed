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
        PendingRefunds[source] = true
        return true
    end
    if exports.sunset_core:RemoveMoney(source, 'bank', price, 'appearance') then
        PendingRefunds[source] = true
        return true
    end

    return false, ('Not enough money ($%s)'):format(price)
end)

-- [CLOTHING FIX B4] Refund for the pay-then-save-failed path. Capped to the
-- flat appearance price and rate-limited; cannot be used as a money source
-- because it only ever returns what payAppearance took moments earlier
-- (guarded by the per-source pending flag set on payment).
local PendingRefunds = {}

exports.sunset_core:RegisterCallback('sunset:refundAppearance', function(source, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > APPEARANCE_PRICE then return false end
    if not PendingRefunds[source] then return false, 'Nothing to refund.' end
    PendingRefunds[source] = nil
    return exports.sunset_core:AddMoney(source, 'cash', amount, 'appearance_refund')
end)

AddEventHandler('playerDropped', function()
    PendingRefunds[source] = nil
end)

-- [CLOTHING C11] Dev/admin compatibility tool gate. Never enabled for players:
-- requires admin level 4 (Owner/deputy tier) via sunset_admin.
exports.sunset_core:RegisterCallback('sunset:clothing:debug', function(source)
    if GetResourceState('sunset_admin') ~= 'started' then return false end
    local ok, isAdmin = pcall(function() return exports.sunset_admin:IsAdmin(source, 4) end)
    return ok and isAdmin == true
end)
