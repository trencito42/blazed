local dutyWeapons = {}

local function getChar()
    return exports.sunset_core:GetCharacter()
end

local function getFactionId(char)
    char = char or getChar()
    if not char then return nil end
    local md = char.metadata or {}
    if md.faction then return md.faction end
    if char.job then return char.job end
    return nil
end

local function removeDutyWeapons(ped)
    for weapon, _ in pairs(dutyWeapons) do
        RemoveWeaponFromPed(ped, joaat(weapon))
    end
    dutyWeapons = {}
end

local function giveWeapon(ped, weapon, ammo)
    local hash = joaat(weapon)
    GiveWeaponToPed(ped, hash, ammo or 0, false, false)
    dutyWeapons[weapon] = true
end

local function switchPedModel(modelInput)
    if not modelInput then return false end
    local hash = type(modelInput) == 'number' and modelInput or joaat(modelInput)
    local currentPed = PlayerPedId()
    if GetEntityModel(currentPed) == hash then
        return true
    end

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        print(('[SunsetFactions] Invalid ped model: %s'):format(tostring(modelInput)))
        return false
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 6000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            print(('[SunsetFactions] Ped model loading timed out: %s'):format(tostring(modelInput)))
            return false
        end
        Wait(10)
    end

    local oldPed = PlayerPedId()
    local health = GetEntityHealth(oldPed)
    local armour = GetPedArmour(oldPed)
    local vehicle = GetVehiclePedIsIn(oldPed, false)
    local seat = -1
    if vehicle ~= 0 then
        for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
            if GetPedInVehicleSeat(vehicle, i) == oldPed then
                seat = i
                break
            end
        end
    end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    local newPed = PlayerPedId()
    SetPedDefaultComponentVariation(newPed)
    SetEntityHealth(newPed, math.max(100, health))
    SetPedArmour(newPed, armour)

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetPedIntoVehicle(newPed, vehicle, seat)
    end

    return true
end

function ApplyFactionLoadout(factionId, grade, customSkin)
    local char = getChar()
    if not char then return end
    local faction = Sunset.Factions[factionId]
    local loadout = faction and faction.loadout
    if not loadout then return end

    local gender = char.gender or 0
    local targetSkin = customSkin or Sunset.ResolveFactionSkin(factionId, grade, gender)

    if targetSkin then
        switchPedModel(targetSkin)
    end

    local ped = PlayerPedId()
    removeDutyWeapons(ped)

    if loadout.armor and loadout.armor > 0 then
        SetPedArmour(ped, math.min(100, loadout.armor))
    end

    for _, w in ipairs(loadout.weapons or {}) do
        giveWeapon(ped, w.weapon, w.ammo)
    end

    local gradeWeapons = loadout.gradeWeapons and loadout.gradeWeapons[grade or 0]
    if gradeWeapons then
        for _, w in ipairs(gradeWeapons) do
            giveWeapon(ped, w.weapon, w.ammo)
        end
    end
end

function ClearFactionLoadout()
    local char = getChar()
    local ped = PlayerPedId()
    removeDutyWeapons(ped)
    SetPedArmour(ped, 0)

    local gender = (char and char.gender) or 0
    local freemodeModel = (gender == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`

    if GetEntityModel(ped) ~= freemodeModel then
        switchPedModel(freemodeModel)
        ped = PlayerPedId()
    end

    if char and char.appearance and GetResourceState('sunset_appearance') == 'started' then
        exports.sunset_appearance:ApplyAppearance(ped, char.appearance, gender)
    end
end

RegisterNetEvent('sunset:client:dutyState', function(state, factionId)
    if state then
        local char = getChar()
        local fid = getFactionId(char) or factionId
        local grade = (char and char.metadata and tonumber(char.metadata.faction_grade)) or 0
        ApplyFactionLoadout(fid, grade)
    else
        ClearFactionLoadout()
    end
end)

RegisterCommand('fskins', function()
    local char = getChar()
    if not char then return end
    local fid = getFactionId(char)
    if not fid or not exports.sunset_factions:IsOnDuty() then
        return exports.sunset_ui:Notify('Trebuie să fii ON DUTY într-o facțiune pentru a schimba uniforma / skinul.', 'error')
    end

    local grade = (char.metadata and tonumber(char.metadata.faction_grade)) or 0
    local gender = char.gender or 0
    local options = Sunset.GetFactionSkinOptions(fid, grade, gender)

    if not options or #options == 0 then
        return exports.sunset_ui:Notify('Nu există skinuri alternative pentru gradul tău.', 'info')
    end

    TriggerEvent('chat:addMessage', {
        color = { 59, 130, 246 },
        multiline = true,
        args = { 'Facțiune', ('^2Skinuri disponibile pentru %s (folosește ^3/fskin <număr>^2):'):format(Sunset.Factions[fid] and Sunset.Factions[fid].label or fid) }
    })

    for _, opt in ipairs(options) do
        TriggerEvent('chat:addMessage', {
            color = { 200, 200, 200 },
            args = { 'Skin ' .. opt.index, ('%s ^7— ^3/fskin %d^7 (sau ^3/fskin %s^7)'):format(opt.label, opt.index, opt.key) }
        })
    end
end, false)

RegisterCommand('fskin', function(_, args)
    local char = getChar()
    if not char then return end
    local fid = getFactionId(char)
    if not fid or not exports.sunset_factions:IsOnDuty() then
        return exports.sunset_ui:Notify('Trebuie să fii ON DUTY într-o facțiune pentru a schimba uniforma / skinul.', 'error')
    end

    local arg = args[1] and tostring(args[1]):lower()
    if not arg then
        ExecuteCommand('fskins')
        return
    end

    local grade = (char.metadata and tonumber(char.metadata.faction_grade)) or 0
    local gender = char.gender or 0
    local options = Sunset.GetFactionSkinOptions(fid, grade, gender)

    local chosen = nil
    local num = tonumber(arg)
    if num and options[num] then
        chosen = options[num]
    else
        for _, opt in ipairs(options) do
            if opt.key:lower() == arg or opt.label:lower():find(arg, 1, true) then
                chosen = opt
                break
            end
        end
    end

    if not chosen then
        exports.sunset_ui:Notify('Skin negăsit. Tastează /fskins pentru lista completă.', 'error')
        return
    end

    ApplyFactionLoadout(fid, grade, chosen.model)
    exports.sunset_ui:Notify(('Uniformă / Skin echipat: %s'):format(chosen.label), 'success')
end, false)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/fskins', 'Afișează skinurile și uniformele disponibile pentru facțiunea ta')
    TriggerEvent('chat:addSuggestion', '/fskin', 'Echipează o uniformă sau un skin de facțiune', {
        { name = 'număr sau nume', help = 'ex: 1, 2, swat, hway, doctor' }
    })
end)

exports('ApplyFactionLoadout', ApplyFactionLoadout)
exports('ClearFactionLoadout', ClearFactionLoadout)
exports('GetFactionSkinOptions', function(factionId, grade, gender)
    return Sunset.GetFactionSkinOptions(factionId, grade, gender)
end)
