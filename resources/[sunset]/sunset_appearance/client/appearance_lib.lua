SunsetAppearance = SunsetAppearance or {}

local OVERLAY_OFF = 255

local function clampDrawable(ped, slot, drawable)
    local maxDraw = GetNumberOfPedDrawableVariations(ped, slot) - 1
    if maxDraw < 0 then return 0 end
    return math.max(0, math.min(math.floor(drawable or 0), maxDraw))
end

local function isDrawableUsable(ped, slot, drawable)
    if drawable < 0 then return false end
    if drawable > GetNumberOfPedDrawableVariations(ped, slot) - 1 then return false end
    return GetNumberOfPedTextureVariations(ped, slot, drawable) > 0
end

local function nearestUsableDrawable(ped, slot, drawable)
    local maxDraw = GetNumberOfPedDrawableVariations(ped, slot) - 1
    if maxDraw < 0 then return 0 end
    drawable = clampDrawable(ped, slot, drawable)
    if isDrawableUsable(ped, slot, drawable) then return drawable end
    for d = drawable, maxDraw do
        if isDrawableUsable(ped, slot, d) then return d end
    end
    for d = drawable, 0, -1 do
        if isDrawableUsable(ped, slot, d) then return d end
    end
    return 0
end

local function setComponentSafe(ped, slot, drawable)
    drawable = nearestUsableDrawable(ped, slot, drawable)
    SetPedComponentVariation(ped, slot, drawable, 0, 2)
    return drawable
end

function SunsetAppearance.default(gender)
    local isFemale = gender == 1
    return {
        version = 2,
        headBlend = {
            shapeFirst = 0, shapeSecond = 0, shapeThird = 0,
            skinFirst = 0, skinSecond = 0, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
        },
        hair = { drawable = 0, texture = 0, color = 0, highlight = 0 },
        overlays = {
            ['1'] = { index = 0, opacity = 0.0, color = 0 },
            ['2'] = { index = 0, opacity = 0.0, color = 0 },
        },
        components = {
            ['3'] = { drawable = isFemale and 14 or 15, texture = 0 },
            ['4'] = { drawable = isFemale and 0 or 0, texture = 0 },
            ['6'] = { drawable = 1, texture = 0 },
            ['8'] = { drawable = 15, texture = 0 },
            ['11'] = { drawable = 15, texture = 0 },
        },
    }
end

function SunsetAppearance.normalize(raw, gender)
    local out = SunsetAppearance.default(gender)
    if not raw or type(raw) ~= 'table' then return out end

    if raw.version == 2 then
        if raw.headBlend then
            for k, v in pairs(raw.headBlend) do out.headBlend[k] = v end
        end
        if raw.hair then
            for k, v in pairs(raw.hair) do out.hair[k] = v end
        end
        if raw.overlays then
            for k, v in pairs(raw.overlays) do
                out.overlays[k] = out.overlays[k] or {}
                for kk, vv in pairs(v) do out.overlays[k][kk] = vv end
            end
        end
        if raw.components then
            for k, v in pairs(raw.components) do
                if out.components[k] and type(v) == 'table' then
                    out.components[k].drawable = v.drawable or out.components[k].drawable
                    out.components[k].texture = v.texture or 0
                end
            end
        end
        return out
    end

    for i = 0, 11 do
        local comp = raw[tostring(i)] or raw[i]
        if comp and out.components[tostring(i)] then
            out.components[tostring(i)].drawable = comp.drawable or 0
            out.components[tostring(i)].texture = comp.texture or 0
        end
    end
    if raw.hair then
        out.hair.drawable = raw.hair.drawable or out.hair.drawable
        out.hair.texture = raw.hair.texture or out.hair.texture
    end
    return out
end

function SunsetAppearance.resolveTorso(ped, gender, top, undershirt)
    local isFemale = gender == 1
    local candidates

    if top == 0 and (undershirt or 0) == 0 then
        candidates = isFemale and { 15, 14, 3, 0 } or { 15, 0, 1, 4 }
    elseif top == 0 then
        candidates = isFemale and { 3, 14, 15, 0 } or { 15, 3, 4, 0 }
    else
        candidates = isFemale and { 14, 3, 6, 11, 2, 0 } or { 15, 4, 1, 6, 11, 3, 0 }
    end

    for _, torso in ipairs(candidates) do
        if isDrawableUsable(ped, 3, torso) then
            return torso
        end
    end
    return isFemale and 14 or 15
end

function SunsetAppearance.syncTorso(appearance, ped, gender)
    local top = appearance.components['11'].drawable or 0
    local undershirt = appearance.components['8'].drawable or 0
    appearance.components['3'].drawable = SunsetAppearance.resolveTorso(ped, gender, top, undershirt)
    return appearance
end

function SunsetAppearance.applyClothes(ped, appearance, gender)
    appearance = SunsetAppearance.syncTorso(appearance, ped, gender)

    local order = { 4, 6, 8, 11, 3 }
    for _, slot in ipairs(order) do
        local comp = appearance.components[tostring(slot)]
        if comp then
            comp.drawable = setComponentSafe(ped, slot, comp.drawable or 0)
            comp.texture = 0
        end
    end

  -- Re-apply top after torso so jacket layer stays visible
    local top = appearance.components['11']
    if top then
        top.drawable = setComponentSafe(ped, 11, top.drawable)
    end

    return appearance
end

function SunsetAppearance.apply(ped, appearance, gender)
    appearance = SunsetAppearance.normalize(appearance, gender)
    local hb = appearance.headBlend

    SetPedHeadBlendData(
        ped,
        hb.shapeFirst or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
        hb.skinFirst or 0, hb.skinSecond or 0, hb.skinThird or 0,
        hb.shapeMix or 0.5, hb.skinMix or 0.5, hb.thirdMix or 0.0,
        false
    )

    appearance = SunsetAppearance.applyClothes(ped, appearance, gender)

    local hair = appearance.hair
    hair.drawable = setComponentSafe(ped, 2, hair.drawable or 0)
    SetPedHairColor(ped, hair.color or 0, hair.highlight or 0)

    for id, ov in pairs(appearance.overlays or {}) do
        local overlayId = tonumber(id)
        if not overlayId then goto continue end
        local index = ov.index or 0
        if index <= 0 then
            SetPedHeadOverlay(ped, overlayId, 255, 0.0)
        else
            SetPedHeadOverlay(ped, overlayId, index, ov.opacity or 1.0)
            SetPedHeadOverlayColor(ped, overlayId, 1, ov.color or 0, ov.color or 0)
        end
        ::continue::
    end

    return appearance
end

local function drawableMax(ped, slot)
    local max = GetNumberOfPedDrawableVariations(ped, slot) - 1
    return math.max(0, max)
end

function SunsetAppearance.buildEditor(ped, appearance, gender)
    appearance = SunsetAppearance.normalize(appearance, gender)
    appearance = SunsetAppearance.syncTorso(appearance, ped, gender)
    local fields = {}

    local function add(field) fields[#fields + 1] = field end

    add({ type = 'skinTone', label = 'Skin Tone', min = 0, max = 45, value = appearance.headBlend.skinFirst or 0, camera = 'face' })
    add({ type = 'shapeFirst', label = 'Face Shape A', min = 0, max = 45, value = appearance.headBlend.shapeFirst or 0, camera = 'face' })
    add({ type = 'shapeSecond', label = 'Face Shape B', min = 0, max = 45, value = appearance.headBlend.shapeSecond or 0, camera = 'face' })
    add({ type = 'shapeMix', label = 'Face Mix', min = 0, max = 100, value = math.floor((appearance.headBlend.shapeMix or 0.5) * 100), camera = 'face' })
    add({ type = 'hairStyle', label = 'Hair Style', min = 0, max = drawableMax(ped, 2), value = appearance.hair.drawable or 0, camera = 'face' })
    add({ type = 'hairColor', label = 'Hair Color', min = 0, max = 63, value = appearance.hair.color or 0, camera = 'face' })

    if gender ~= 1 then
        add({ type = 'beard', label = 'Beard', min = 0, max = math.max(0, GetNumHeadOverlayValues(ped, 1) - 1), value = appearance.overlays['1'].index or 0, camera = 'face' })
        add({ type = 'beardColor', label = 'Beard Color', min = 0, max = 63, value = appearance.overlays['1'].color or 0, camera = 'face' })
    end

    local clothes = {
        { 8, 'Undershirt', 'full' },
        { 11, 'Top / Jacket', 'full' },
        { 4, 'Pants', 'full' },
        { 6, 'Shoes', 'feet' },
    }

    for _, row in ipairs(clothes) do
        local slot, label, cam = row[1], row[2], row[3]
        local comp = appearance.components[tostring(slot)] or { drawable = 0 }
        add({
            type = 'component', component = slot, label = label,
            min = 0, max = drawableMax(ped, slot),
            value = comp.drawable or 0, camera = cam,
        })
    end

    return fields, appearance
end

function SunsetAppearance.applyField(ped, appearance, gender, change)
    appearance = SunsetAppearance.normalize(appearance, gender)
    local t = change.type
    local value = tonumber(change.value) or 0

    if t == 'skinTone' then
        appearance.headBlend.skinFirst = value
        appearance.headBlend.skinSecond = value
        appearance.headBlend.skinMix = 0.0
    elseif t == 'shapeFirst' then
        appearance.headBlend.shapeFirst = value
    elseif t == 'shapeSecond' then
        appearance.headBlend.shapeSecond = value
    elseif t == 'shapeMix' then
        appearance.headBlend.shapeMix = value / 100.0
    elseif t == 'hairStyle' then
        appearance.hair.drawable = value
    elseif t == 'hairColor' then
        appearance.hair.color = value
    elseif t == 'beard' then
        appearance.overlays['1'].index = value
        appearance.overlays['1'].opacity = value == 0 and 0.0 or 1.0
    elseif t == 'beardColor' then
        appearance.overlays['1'].color = value
    elseif t == 'component' then
        local slot = tonumber(change.component)
        if slot then
            appearance.components[tostring(slot)] = appearance.components[tostring(slot)] or { drawable = 0, texture = 0 }
            appearance.components[tostring(slot)].drawable = value
            appearance.components[tostring(slot)].texture = 0
        end
    end

    SunsetAppearance.apply(ped, appearance, gender)
    return appearance
end

function SunsetAppearance.maxDrawable(ped, slot, appearance, gender)
    appearance = SunsetAppearance.normalize(appearance, gender)
    return drawableMax(ped, slot)
end
