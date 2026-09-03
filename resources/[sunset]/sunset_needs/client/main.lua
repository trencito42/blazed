local active = false

AddEventHandler('sunset:client:playerSpawned', function()
    active = true
end)

CreateThread(function()
    while true do
        if active then
            local char = exports.sunset_core:GetCharacter()
            if char then
                TriggerServerEvent('sunset:server:needsTick')
            end
            Wait(60000)
        else
            Wait(2000)
        end
    end
end)

CreateThread(function()
    while true do
        if active then
            local char = exports.sunset_core:GetCharacter()
            if char then
                if (char.hunger or 100) <= 0 or (char.thirst or 100) <= 0 then
                    local ped = PlayerPedId()
                    local hp = GetEntityHealth(ped)
                    SetEntityHealth(ped, math.max(101, hp - Sunset.Config.StarvationDamage))
                end
                if (char.stress or 0) >= 90 then
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.03)
                end
            end
            Wait(5000)
        else
            Wait(2000)
        end
    end
end)
