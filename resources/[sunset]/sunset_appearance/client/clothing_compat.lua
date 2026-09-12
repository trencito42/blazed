SunsetClothing = SunsetClothing or {}

local PRICE_PER_ITEM = 50

SunsetClothing.Categories = {
    { id = 'hat', label = 'Hats', display = 'Hats / Caps', kind = 'prop', slot = 0, icon = 'ph-baseball-cap', camera = 'face' },
    { id = 'mask', label = 'Masks', display = 'Masks', kind = 'component', slot = 1, icon = 'ph-mask-happy', camera = 'face' },
    { id = 'glasses', label = 'Glasses', display = 'Glasses', kind = 'prop', slot = 1, icon = 'ph-sunglasses', camera = 'face' },
    { id = 'ears', label = 'Earrings', display = 'Ears / Earrings', kind = 'prop', slot = 2, icon = 'ph-ear', camera = 'face' },
    { id = 'accessory', label = 'Accessories', display = 'Chains / Accessories', kind = 'component', slot = 7, icon = 'ph-sketch-logo', camera = 'full' },
    { id = 'top', label = 'Tops', display = 'Shirt / Jacket', kind = 'component', slot = 11, icon = 'ph-t-shirt', camera = 'full', syncTorso = true },
    { id = 'undershirt', label = 'Undershirts', display = 'Undershirts', kind = 'component', slot = 8, icon = 'ph-shirt-folded', camera = 'full', compatFilter = true },
    { id = 'vest', label = 'Vests', display = 'Vests / Body Armor', kind = 'component', slot = 9, icon = 'ph-shield-check', camera = 'full' },
    { id = 'pants', label = 'Pants', display = 'Pants', kind = 'component', slot = 4, icon = 'ph-pants', camera = 'full' },
    { id = 'shoes', label = 'Shoes', display = 'Footwear', kind = 'component', slot = 6, icon = 'ph-sneaker', camera = 'feet' },
    { id = 'bag', label = 'Bags', display = 'Backpacks / Bags', kind = 'component', slot = 5, icon = 'ph-backpack', camera = 'full' },
    { id = 'watch', label = 'Watches', display = 'Watches', kind = 'prop', slot = 6, icon = 'ph-watch', camera = 'full' },
    { id = 'bracelet', label = 'Bracelets', display = 'Bracelets', kind = 'prop', slot = 7, icon = 'ph-circle-half', camera = 'full' },
}

local function categoryById(id)
    for _, cat in ipairs(SunsetClothing.Categories) do
        if cat.id == id then return cat end
    end
    for _, cat in ipairs(SunsetClothing.Categories) do
        if cat.id == 'top' then return cat end
    end
    return SunsetClothing.Categories[1]
end

-- [CLOTHING UX] Generic player-facing names: the wardrobe must not show raw
-- drawable numbers as the item identity ("32 / 611"). Real item naming would
-- need a curated catalog; generic labels are honest and readable.
local CATEGORY_NOUNS = {
    hat = 'Hat', mask = 'Mask', glasses = 'Glasses', ears = 'Earring',
    accessory = 'Accessory', top = 'Top', undershirt = 'Undershirt',
    vest = 'Vest', pants = 'Pants', shoes = 'Shoes', bag = 'Bag',
    watch = 'Watch', bracelet = 'Bracelet',
}

function SunsetClothing.itemName(cat, drawable)
    drawable = math.floor(tonumber(drawable) or 0)
    if cat.kind == 'prop' and drawable < 0 then return 'None' end
    local noun = CATEGORY_NOUNS[cat.id] or cat.label or 'Item'
    return ('%s %03d'):format(noun, drawable)
end

-- [CLOTHING CURATION] Disabled drawables per gender+slot (broken/clipping
-- items). Extend via SunsetClothing.Blacklist entries; kept in one place, not
-- scattered through UI code. Format: [slot] = { [gender] = { drawable=true } }
SunsetClothing.Blacklist = SunsetClothing.Blacklist or {}

function SunsetClothing.isBlacklisted(gender, slot, drawable)
    local bySlot = SunsetClothing.Blacklist[tostring(slot)]
    if not bySlot then return false end
    local byGender = bySlot[gender == 1 and 'female' or 'male'] or bySlot['all']
    return byGender ~= nil and byGender[tostring(math.floor(drawable or -1))] == true
end

local function drawableMax(ped, slot)
    local max = GetNumberOfPedDrawableVariations(ped, slot) - 1
    return math.max(0, max)
end

local function textureMax(ped, slot, drawable)
    local max = GetNumberOfPedTextureVariations(ped, slot, drawable) - 1
    return math.max(0, max)
end

local function propDrawableMax(ped, slot)
    local max = GetNumberOfPedPropDrawableVariations(ped, slot) - 1
    return math.max(-1, max)
end

local function propTextureMax(ped, slot, drawable)
    if drawable < 0 then return 0 end
    local max = GetNumberOfPedPropTextureVariations(ped, slot, drawable) - 1
    return math.max(0, max)
end

local function ensureProps(appearance)
    appearance.props = appearance.props or {}
    for _, propSlot in ipairs({ 0, 1, 2, 6, 7 }) do
        local key = tostring(propSlot)
        appearance.props[key] = appearance.props[key] or { drawable = -1, texture = 0 }
    end
    return appearance
end

local function ensureComponents(appearance)
    appearance.components = appearance.components or {}
    for _, slot in ipairs({ '1', '3', '4', '5', '6', '7', '8', '9', '11' }) do
        appearance.components[slot] = appearance.components[slot] or { drawable = 0, texture = 0 }
    end
    return appearance
end

function SunsetClothing.normalizeWardrobe(appearance, gender)
    appearance = SunsetAppearance.normalize(appearance, gender)
    return ensureProps(ensureComponents(appearance))
end

function SunsetClothing.getCategorySelection(appearance, categoryId)
    local cat = categoryById(categoryId)
    if cat.kind == 'prop' then
        local prop = appearance.props[tostring(cat.slot)] or { drawable = -1, texture = 0 }
        return prop.drawable or -1, prop.texture or 0
    end
    local comp = appearance.components[tostring(cat.slot)] or { drawable = 0, texture = 0 }
    return comp.drawable or 0, comp.texture or 0
end

function SunsetClothing.setCategorySelection(appearance, ped, gender, categoryId, drawable, texture)
    appearance = SunsetClothing.normalizeWardrobe(appearance, gender)
    local cat = categoryById(categoryId)

    if cat.kind == 'prop' then
        local key = tostring(cat.slot)
        local maxDraw = propDrawableMax(ped, cat.slot)
        drawable = math.max(-1, math.min(math.floor(drawable or -1), maxDraw))
        if drawable >= 0 and IsPedPropValid and not IsPedPropValid(ped, cat.slot, drawable, texture or 0) then
            drawable = -1
        end
        if drawable < 0 then
            appearance.props[key] = { drawable = -1, texture = 0 }
        else
            local maxTex = propTextureMax(ped, cat.slot, drawable)
            texture = math.max(0, math.min(math.floor(texture or 0), maxTex))
            appearance.props[key] = { drawable = drawable, texture = texture }
        end
        return appearance
    end

    local key = tostring(cat.slot)
    local maxDraw = drawableMax(ped, cat.slot)
    drawable = math.max(0, math.min(math.floor(drawable or 0), maxDraw))
    local maxTex = textureMax(ped, cat.slot, drawable)
    texture = math.max(0, math.min(math.floor(texture or 0), maxTex))
    appearance.components[key] = { drawable = drawable, texture = texture }

    if cat.syncTorso or cat.slot == 8 or cat.slot == 11 then
        appearance = SunsetAppearance.syncTorso(appearance, ped, gender)
    end
    return appearance
end

function SunsetClothing.applyPropSafe(ped, slot, drawable, texture)
    if drawable == nil or drawable < 0 then
        ClearPedProp(ped, slot)
        return -1, 0
    end
    local maxDraw = propDrawableMax(ped, slot)
    drawable = math.max(0, math.min(math.floor(drawable), maxDraw))
    local maxTex = propTextureMax(ped, slot, drawable)
    texture = math.max(0, math.min(math.floor(texture or 0), maxTex))
    if (not IsPedPropValid or IsPedPropValid(ped, slot, drawable, texture)) then
        SetPedPropIndex(ped, slot, drawable, texture, true)
    else
        ClearPedProp(ped, slot)
        return -1, 0
    end
    return drawable, texture
end

function SunsetClothing.applyComponentSafe(ped, slot, drawable, texture)
    return SunsetAppearance.setComponentSafe(ped, slot, drawable, texture)
end

function SunsetClothing.applyAll(ped, appearance, gender)
    appearance = SunsetClothing.normalizeWardrobe(appearance, gender)
    appearance = SunsetAppearance.applyClothes(ped, appearance, gender)

    local mask = appearance.components['1']
    if mask then
        local d, t = SunsetClothing.applyComponentSafe(ped, 1, mask.drawable, mask.texture)
        appearance.components['1'].drawable, appearance.components['1'].texture = d, t
    end

    local bag = appearance.components['5']
    if bag then
        local d, t = SunsetClothing.applyComponentSafe(ped, 5, bag.drawable, bag.texture)
        appearance.components['5'].drawable, appearance.components['5'].texture = d, t
    end

    local accessory = appearance.components['7']
    if accessory then
        local d, t = SunsetClothing.applyComponentSafe(ped, 7, accessory.drawable, accessory.texture)
        appearance.components['7'].drawable, appearance.components['7'].texture = d, t
    end

    for _, propSlot in ipairs({ 0, 1, 2 }) do
        local key = tostring(propSlot)
        local prop = appearance.props[key]
        if prop then
            local d, t = SunsetClothing.applyPropSafe(ped, propSlot, prop.drawable, prop.texture)
            appearance.props[key].drawable = d
            appearance.props[key].texture = t
        end
    end

    return appearance
end

function SunsetClothing.preview(ped, appearance, gender)
    return SunsetClothing.applyAll(ped, appearance, gender)
end

function SunsetClothing.buildCatalog(ped, appearance, gender, activeCategoryId)
    appearance = SunsetClothing.normalizeWardrobe(appearance, gender)
    activeCategoryId = activeCategoryId or 'top'
    local cat = categoryById(activeCategoryId)
    local drawable, texture = SunsetClothing.getCategorySelection(appearance, cat.id)

    local maxDrawable, maxTexture
    if cat.kind == 'prop' then
        maxDrawable = propDrawableMax(ped, cat.slot)
        maxTexture = propTextureMax(ped, cat.slot, math.max(0, drawable))
    else
        maxDrawable = drawableMax(ped, cat.slot)
        maxTexture = textureMax(ped, cat.slot, drawable)
    end

    local categories = {}
    for _, row in ipairs(SunsetClothing.Categories) do
        categories[#categories + 1] = {
            id = row.id,
            label = row.label,
            display = row.display,
            icon = row.icon,
        }
    end

    return {
        type = 'wardrobe',
        categories = categories,
        activeCategory = cat.id,
        activeDisplay = cat.display,
        activeKind = cat.kind,
        isProp = cat.kind == 'prop',
        drawable = drawable,
        texture = texture,
        maxDrawable = maxDrawable,
        maxTexture = maxTexture,
        -- [CLOTHING UX] Player-friendly names instead of raw drawable numbers:
        -- "Bomber Jacket 032" style. "None" for prop -1.
        itemName = SunsetClothing.itemName(cat, drawable),
        pricePerItem = PRICE_PER_ITEM,
        cartTotal = PRICE_PER_ITEM,
        camera = cat.camera or 'full',
    }
end

function SunsetClothing.mergeFactionOutfit(appearance, outfit, ped, gender)
    if not outfit then return appearance end
    appearance = SunsetClothing.normalizeWardrobe(appearance, gender)

    for slot, comp in pairs(outfit) do
        local componentId = tonumber(slot)
        if componentId and comp and comp.drawable ~= nil then
            appearance.components[tostring(componentId)] = {
                drawable = tonumber(comp.drawable) or 0,
                texture = tonumber(comp.texture) or 0,
            }
        end
    end

    appearance = SunsetAppearance.syncTorso(appearance, ped, gender)
    return appearance
end

function SunsetClothing.syncFromPed(appearance, ped, gender)
    appearance = SunsetClothing.normalizeWardrobe(appearance, gender)
    for slot = 0, 11 do
        local key = tostring(slot)
        if appearance.components[key] then
            appearance.components[key].drawable = GetPedDrawableVariation(ped, slot)
            appearance.components[key].texture = GetPedTextureVariation(ped, slot)
        end
    end
    for _, propSlot in ipairs({ 0, 1, 2, 6, 7 }) do
        local drawable = GetPedPropIndex(ped, propSlot)
        local key = tostring(propSlot)
        if drawable < 0 then
            appearance.props[key] = { drawable = -1, texture = 0 }
        else
            appearance.props[key] = {
                drawable = drawable,
                texture = math.max(0, GetPedPropTextureIndex(ped, propSlot)),
            }
        end
    end
    return appearance
end

function SunsetClothing.applyFactionOutfit(ped, outfit, gender, baseAppearance)
    local appearance = SunsetClothing.normalizeWardrobe(baseAppearance or SunsetAppearance.default(gender), gender)
    appearance = SunsetClothing.mergeFactionOutfit(appearance, outfit, ped, gender)
    return SunsetClothing.applyAll(ped, appearance, gender)
end

function SunsetClothing.validateOutfit(ped, appearance, gender)
    appearance = SunsetClothing.normalizeWardrobe(appearance, gender)
    local issues = {}
    local top = appearance.components['11']
    local torso = appearance.components['3']
    if top and torso then
        local expectedTorso, expectedTex = SunsetAppearance.resolveTorso(ped, gender, top.drawable, top.texture)
        if torso.drawable ~= expectedTorso then
            issues[#issues + 1] = ('Torso mismatch: have %d, expected %d for top %d'):format(
                torso.drawable, expectedTorso, top.drawable
            )
        end
    end
    return #issues == 0, issues
end

exports('ApplyFactionOutfit', function(ped, outfit, gender, baseAppearance)
    return SunsetClothing.applyFactionOutfit(ped, outfit, gender, baseAppearance)
end)

exports('ApplyAllClothing', function(ped, appearance, gender)
    return SunsetClothing.applyAll(ped, appearance, gender)
end)

RegisterCommand('validateoutfit', function()
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    if not char then return end
    local ok, issues = SunsetClothing.validateOutfit(ped, char.appearance, char.gender or 0)
    if ok then
        print('[SunsetClothing] Outfit validation passed.')
    else
        for _, issue in ipairs(issues) do
            print('[SunsetClothing] ' .. issue)
        end
    end
end, false)
