local dutyWeapons = {}

local function getChar()
    return exports.sunset_core:GetCharacter()
end

local function getFactionId(char)
    return Sunset.GetCharacterFaction(char or getChar())
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

function ApplyFactionLoadout(factionId, grade)
    local char = getChar()
    if not char then return end
    local faction = Sunset.Factions[factionId]
    local loadout = faction and faction.loadout
    if not loadout then return end

    local ped = PlayerPedId()
    removeDutyWeapons(ped)

    local gender = char.gender or 0
    local clothes = (gender == 1 and loadout.female) or loadout.male
    if clothes then
        for slot, row in pairs(clothes) do
            SetPedComponentVariation(ped, tonumber(slot), row.drawable or 0, row.texture or 0, 0)
        end
    end

    if loadout.armor then
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
    if char and char.appearance and GetResourceState('sunset_appearance') == 'started' then
        exports.sunset_appearance:ApplyAppearance(ped, char.appearance, char.gender or 0)
    end
end

RegisterNetEvent('sunset:client:dutyState', function(state, factionId)
    if state then
        local char = getChar()
        local fid, grade = Sunset.GetCharacterFaction(char)
        ApplyFactionLoadout(fid or factionId, grade)
    else
        ClearFactionLoadout()
    end
end)

exports('ApplyFactionLoadout', ApplyFactionLoadout)
exports('ClearFactionLoadout', ClearFactionLoadout)
