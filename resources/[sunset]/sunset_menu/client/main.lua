local menuOpen = false

local function buildMenuData()
    local char = exports.sunset_core:GetCharacter()
    if not char then return nil end

    local ped = PlayerPedId()
    local maxHp = GetEntityMaxHealth(ped) - 100
    local hp = GetEntityHealth(ped) - 100
    local health = maxHp > 0 and math.floor((hp / maxHp) * 100) or 0
    local job = Sunset.Jobs[char.job]

    local paydaySec = 0
    pcall(function()
        paydaySec = exports.sunset_hud:GetPaydaySeconds() or 0
    end)
    local payday = ('%02d:%02d'):format(math.floor(paydaySec / 60), paydaySec % 60)

    return {
        id = GetPlayerServerId(PlayerId()),
        name = char.firstname .. ' ' .. char.lastname,
        level = 1,
        xp = 0,
        xpMax = 1000,
        cash = char.cash,
        bank = char.bank,
        job = job and job.label or 'Șomer',
        faction = 'Civilian',
        health = math.max(0, math.min(100, health)),
        armor = math.max(0, math.min(100, GetPedArmour(ped))),
        hunger = 100,
        thirst = 100,
        stress = 0,
        playtime = '0h',
        payday = payday,
        phone = '555-0100',
        licenses = { 'B' },
    }
end

local function toggleMenu(show)
    menuOpen = show
    exports.sunset_ui:SetFocus(show, show)
    if show then
        exports.sunset_ui:Send('menuShow', buildMenuData())
    else
        exports.sunset_ui:Send('menuHide', {})
    end
end

RegisterCommand('sunset_menu', function()
    toggleMenu(not menuOpen)
end, false)
RegisterKeyMapping('sunset_menu', 'Meniu jucător', 'keyboard', 'M')

AddEventHandler('sunset:nui:menuClose', function()
    toggleMenu(false)
end)

CreateThread(function()
    while true do
        if menuOpen then
            local data = buildMenuData()
            if data then exports.sunset_ui:Send('menuUpdate', data) end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)
