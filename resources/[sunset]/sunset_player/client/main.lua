RegisterNetEvent('sunset:client:updateCharacter', function(char)
    if Sunset.Character then
        for k, v in pairs(char) do Sunset.Character[k] = v end
    else
        Sunset.Character = char
    end
end)

RegisterNetEvent('sunset:client:heal', function(amount)
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)
    SetEntityHealth(ped, math.min(200, hp + (amount or 25)))
end)
