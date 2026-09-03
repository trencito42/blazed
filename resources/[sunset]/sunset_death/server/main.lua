RegisterNetEvent('sunset:server:playerDied', function()
    local source = source
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return end

    char.is_dead = true
    local bill = Sunset.Config.HospitalBill or 0
    if bill > 0 then
        exports.sunset_core:RemoveMoney(source, 'bank', bill, 'hospital') or
        exports.sunset_core:RemoveMoney(source, 'cash', bill, 'hospital')
    end

    local pos = exports.sunset_core:GetSpawnPosition(char)
    char.is_dead = false
    exports.sunset_core:SaveCharacter(source)
    TriggerClientEvent('sunset:client:respawn', source, pos, bill)
    TriggerClientEvent('sunset:client:updateCharacter', source, char)
end)
