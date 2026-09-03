exports.sunset_core:RegisterCallback('sunset:payAppearance', function(source, amount)
    amount = math.floor(tonumber(amount) or 50)
    if amount < 1 then return true end
    if exports.sunset_core:RemoveMoney(source, 'cash', amount, 'appearance') then return true end
    if exports.sunset_core:RemoveMoney(source, 'bank', amount, 'appearance') then return true end
    return nil, ('Not enough money ($%s)'):format(amount)
end)
