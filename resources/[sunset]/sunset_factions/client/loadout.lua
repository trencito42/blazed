local dutyWeapons = {}

local WEAPON_LABELS = {
    WEAPON_NIGHTSTICK = 'Nightstick',
    WEAPON_FLASHLIGHT = 'Flashlight',
    WEAPON_STUNGUN = 'Stun Gun',
    WEAPON_COMBATPISTOL = 'Combat Pistol',
    WEAPON_CARBINERIFLE = 'Carbine Rifle',
    WEAPON_PUMPSHOTGUN = 'Pump Shotgun',
    WEAPON_SMG = 'SMG',
    WEAPON_PISTOL = 'Pistol',
    WEAPON_MICROSMG = 'Micro SMG',
    WEAPON_ASSAULTRIFLE = 'Assault Rifle',
}

local FREEMODE_MALE = `mp_m_freemode_01`
local FREEMODE_FEMALE = `mp_f_freemode_01`

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

local function preloadPedModel(modelInput)
    if not modelInput then return end
    local hash = type(modelInput) == 'number' and modelInput or joaat(modelInput)
    if IsModelInCdimage(hash) and IsModelValid(hash) and not HasModelLoaded(hash) then
        RequestModel(hash)
    end
end

local function freemodeModelFor(gender)
    return (gender == 1) and FREEMODE_FEMALE or FREEMODE_MALE
end

local function restoreScreenIfFaded()
    if IsScreenFadedOut() then
        DoScreenFadeIn(0)
    end
end

local function applyOutfitComponents(ped, outfit)
    if not outfit or not ped then return end
    for slot, comp in pairs(outfit) do
        local componentId = tonumber(slot)
        if componentId and comp and comp.drawable ~= nil then
            local drawable = comp.drawable
            local texture = comp.texture or 0
            local maxDraw = GetNumberOfPedDrawableVariations(ped, componentId) - 1
            if maxDraw >= 0 then
                drawable = math.max(0, math.min(drawable, maxDraw))
                local maxTex = GetNumberOfPedTextureVariations(ped, componentId, drawable) - 1
                if maxTex < 0 then maxTex = 0 end
                texture = math.max(0, math.min(texture, maxTex))
                SetPedComponentVariation(ped, componentId, drawable, texture, 2)
            end
        end
    end
end

local function applySavedAppearance(ped, char, gender)
    if char and char.appearance and GetResourceState('sunset_appearance') == 'started' then
        exports.sunset_appearance:ApplyAppearance(ped, char.appearance, gender)
    end
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

    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(hash) do
            if GetGameTimer() > timeout then
                print(('[SunsetFactions] Ped model loading timed out: %s'):format(tostring(modelInput)))
                return false
            end
            Wait(0)
        end
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

    restoreScreenIfFaded()
    return true
end

function ApplyFactionLoadout(factionId, grade, customSkin)
    local char = getChar()
    if not char then return end
    local faction = Sunset.Factions[factionId]
    local loadout = faction and faction.loadout
    if not loadout then return end

    local gender = char.gender or 0
    local ped = PlayerPedId()

    if customSkin then
        switchPedModel(customSkin)
        ped = PlayerPedId()
    else
        local outfit = Sunset.ResolveFactionOutfit and Sunset.ResolveFactionOutfit(loadout, grade, gender)
        if outfit then
            local freemodeModel = freemodeModelFor(gender)
            if GetEntityModel(ped) ~= freemodeModel then
                switchPedModel(freemodeModel)
                ped = PlayerPedId()
                applySavedAppearance(ped, char, gender)
            end
            if exports.sunset_appearance and exports.sunset_appearance.ApplyFactionOutfit then
                exports.sunset_appearance:ApplyFactionOutfit(ped, outfit, gender, char.appearance)
            else
                applyOutfitComponents(ped, outfit)
            end
        elseif Sunset.ResolveFactionSkin then
            local targetSkin = Sunset.ResolveFactionSkin(factionId, grade, gender)
            if targetSkin then
                switchPedModel(targetSkin)
                ped = PlayerPedId()
            end
        end
    end

    ped = PlayerPedId()
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

CreateThread(function()
    Wait(2000)
    preloadPedModel(FREEMODE_MALE)
    preloadPedModel(FREEMODE_FEMALE)
    if Sunset.FactionSkins then
        for _, def in pairs(Sunset.FactionSkins) do
            preloadPedModel(def.defaultMale)
            preloadPedModel(def.defaultFemale)
            if def.options then
                for _, opt in ipairs(def.options) do
                    preloadPedModel(opt.male)
                    preloadPedModel(opt.female)
                end
            end
        end
    end
end)

function ClearFactionLoadout()
    local char = getChar()
    local ped = PlayerPedId()
    removeDutyWeapons(ped)
    SetPedArmour(ped, 0)

    local gender = (char and char.gender) or 0
    local freemodeModel = freemodeModelFor(gender)

    if GetEntityModel(ped) ~= freemodeModel then
        switchPedModel(freemodeModel)
        ped = PlayerPedId()
    end

    applySavedAppearance(ped, char, gender)
    restoreScreenIfFaded()
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

local function getDutyWeaponsForUi()
    local list = {}
    local ped = PlayerPedId()
    for weapon in pairs(dutyWeapons) do
        local hash = joaat(weapon)
        local ammo = 0
        if HasPedGotWeapon(ped, hash, false) then
            ammo = GetAmmoInPedWeapon(ped, hash)
        end
        list[#list + 1] = {
            kind = 'duty_weapon',
            weapon = weapon,
            label = WEAPON_LABELS[weapon] or weapon:gsub('^WEAPON_', ''):gsub('_', ' '),
            ammo = ammo,
            icon = 'weapon_trigger',
            id = 'duty:' .. weapon,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

exports('ApplyFactionLoadout', ApplyFactionLoadout)
exports('ClearFactionLoadout', ClearFactionLoadout)
exports('GetDutyWeaponsForUi', getDutyWeaponsForUi)
exports('GetFactionSkinOptions', function(factionId, grade, gender)
    return Sunset.GetFactionSkinOptions(factionId, grade, gender)
end)
