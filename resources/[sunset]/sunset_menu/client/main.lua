local menuOpen = false

local function formatPlaytime(minutes)
    minutes = tonumber(minutes) or 0
    local h = math.floor(minutes / 60)
    local m = minutes % 60
    return ('%dH %dM'):format(h, m)
end

local function formatLastLogin(ts)
    if not ts or ts == '' then return '—' end
    if type(ts) == 'number' then
        return os.date('%d.%m.%Y %H:%M', ts)
    end
    local y, mo, d, h, mi = ts:match('(%d+)-(%d+)-(%d+)[ T](%d+):(%d+)')
    if y then
        return ('%s.%s.%s %s:%s'):format(d, mo, y, h, mi)
    end
    return tostring(ts)
end

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

    local playtimeMin = char.playtime or 0
    local level = math.max(1, math.floor(playtimeMin / 180) + 1)
    local xp = playtimeMin * 10
    local xpMax = level * 5000
    local stamina = math.max(0, math.min(100, 100 - (char.stress or 0)))

    local fuel = nil
    pcall(function()
        local veh = exports.sunset_vehicles:GetVehicleState()
        if veh then fuel = veh.fuel end
    end)

    return {
        id = GetPlayerServerId(PlayerId()),
        name = char.firstname .. ' ' .. char.lastname,
        rank = playtimeMin >= 3000 and 'LOYAL PLAYER' or 'PLAYER',
        level = level,
        xp = xp % xpMax,
        xpMax = xpMax,
        cash = char.cash,
        bank = char.bank,
        premium = 0,
        job = job and job.label or 'Șomer',
        faction = 'Civilian',
        health = math.max(0, math.min(100, health)),
        armor = math.max(0, math.min(100, GetPedArmour(ped))),
        hunger = 100,
        thirst = 100,
        stamina = stamina,
        fuel = fuel,
        playtime = formatPlaytime(playtimeMin),
        lastLogin = formatLastLogin(char.last_played),
        payday = payday,
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

AddEventHandler('sunset:nui:menuAction', function(data)
    local labels = {
        inventory = 'Inventar',
        animations = 'Animații',
        phone = 'Telefon',
        documents = 'Documente',
        licenses = 'Licențe',
        statistics = 'Statistici',
    }
    local label = labels[data and data.action] or 'Secțiune'
    exports.sunset_ui:Notify(label .. ' — în curând', 'info')
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
