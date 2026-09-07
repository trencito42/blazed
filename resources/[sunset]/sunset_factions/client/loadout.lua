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

local function setComponent(ped, slot, drawable, texture)
    drawable = math.floor(tonumber(drawable) or 0)
    texture = math.floor(tonumber(texture) or 0)
    local maxDraw = GetNumberOfPedDrawableVariations(ped, slot) - 1
    if maxDraw < 0 then return end
    drawable = math.max(0, math.min(drawable, maxDraw))
    local maxTex = GetNumberOfPedTextureVariations(ped, slot, drawable) - 1
    if maxTex < 0 then maxTex = 0 end
    texture = math.max(0, math.min(texture, maxTex))
    SetPedComponentVariation(ped, slot, drawable, texture, 2)
end

local function applyDutyClothes(ped, clothes, gender)
    if not clothes then return end

    local top = clothes[11]
    local topDrawable = top and top.drawable or 0
    local topTexture = top and top.texture or 0

    if clothes[4] then setComponent(ped, 4, clothes[4].drawable, clothes[4].texture) end
    if clothes[6] then setComponent(ped, 6, clothes[6].drawable, clothes[6].texture) end
    if clothes[8] then setComponent(ped, 8, clothes[8].drawable, clothes[8].texture) end

    local torsoDrawable, torsoTexture
    if GetResourceState('sunset_appearance') == 'started' then
        torsoDrawable, torsoTexture = exports.sunset_appearance:ResolveTorso(ped, gender, topDrawable, topTexture)
    end
    if torsoDrawable == nil and clothes[3] then
        torsoDrawable = clothes[3].drawable
        torsoTexture = clothes[3].texture
    end
    if torsoDrawable ~= nil then
        setComponent(ped, 3, torsoDrawable, torsoTexture or 0)
    end

    if top then setComponent(ped, 11, topDrawable, topTexture) end
    -- Keep player face/hair — only clear mask/bag slots that break uniforms.
    setComponent(ped, 1, 0, 0)
    setComponent(ped, 5, 0, 0)
    setComponent(ped, 9, 0, 0)
    setComponent(ped, 10, 0, 0)
    ClearPedProp(ped, 0)
    ClearPedProp(ped, 1)
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
    local clothes = Sunset.ResolveFactionOutfit(loadout, grade, gender)
    applyDutyClothes(ped, clothes, gender)

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
        local fid = getFactionId(char) or factionId
        local grade = (char and char.metadata and tonumber(char.metadata.faction_grade)) or 0
        ApplyFactionLoadout(fid, grade)
    else
        ClearFactionLoadout()
    end
end)

exports('ApplyFactionLoadout', ApplyFactionLoadout)
exports('ClearFactionLoadout', ClearFactionLoadout)
