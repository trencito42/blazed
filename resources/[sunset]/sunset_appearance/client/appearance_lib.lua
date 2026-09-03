SunsetAppearance = SunsetAppearance or {}

local function applyHeadBlend(ped, hb)
    local shapeMix = hb.shapeMix or 0.5
    local skinMix = hb.skinMix or 0.0
    local thirdMix = hb.thirdMix or 0.0

    SetPedHeadBlendData(
        ped,
        hb.shapeFirst or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
        hb.skinFirst or 0, hb.skinSecond or 0, hb.skinThird or 0,
        shapeMix, skinMix, thirdMix,
        false
    )

    -- Force blend refresh (hands/face sync)
    if UpdatePedHeadBlendData then
        UpdatePedHeadBlendData(ped, shapeMix, skinMix, thirdMix)
    end

    local timeout = GetGameTimer() + 1500
    while not HasPedHeadBlendFinished(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
end

local function applyHair(ped, hair)
    hair = hair or {}
    local drawable = hair.drawable or 0
    local texture = hair.texture or 0
    local color = math.max(0, math.min(63, math.floor(hair.color or 0)))
    local highlight = math.max(0, math.min(63, math.floor(hair.highlight or color)))

    SetPedComponentVariation(ped, 2, drawable, texture, 2)
    SetPedHairColor(ped, color, highlight)
end

local function applyOverlay(ped, overlayId, ov)
    ov = ov or {}
    local index = math.floor(ov.index or 0)
    local color = math.max(0, math.min(63, math.floor(ov.color or 0)))

    if index <= 0 then
        SetPedHeadOverlay(ped, overlayId, 255, 0.0)
        return
    end

    SetPedHeadOverlay(ped, overlayId, index, ov.opacity or 0.99)
    SetPedHeadOverlayColor(ped, overlayId, 1, color, color)
end

local function syncSkinTone(hb, tone)
    tone = math.max(0, math.min(45, math.floor(tone or 0)))
    hb.skinFirst = tone
    hb.skinSecond = tone
    hb.skinThird = tone
    hb.skinMix = 0.0
    hb.thirdMix = 0.0
    -- Match face structure parents to skin for consistent ethnicity
    hb.shapeFirst = tone
    hb.shapeSecond = tone
    hb.shapeThird = tone
    return tone
end

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

local function setComponentSafe(ped, slot, drawable, texture)
    drawable = nearestUsableDrawable(ped, slot, drawable)
    texture = texture or 0
    local maxTex = GetNumberOfPedTextureVariations(ped, slot, drawable) - 1
    if maxTex < 0 then maxTex = 0 end
    texture = math.max(0, math.min(math.floor(texture), maxTex))
    SetPedComponentVariation(ped, slot, drawable, texture, 2)
    return drawable, texture
end

local function overlayMax(overlayId)
    local count = GetNumHeadOverlayValues(overlayId)
    if not count or count < 1 then return 0 end
    return count - 1
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

function SunsetAppearance.resolveTorso(ped, gender, top, topTexture)
    local torso, tex = TorsoData.getBestTorso(gender, top, topTexture or 0)
    if torso then return torso, tex or 0 end
    return gender == 1 and 14 or 15, 0
end

function SunsetAppearance.syncTorso(appearance, ped, gender)
    local top = appearance.components['11'] or { drawable = 0, texture = 0 }
    local torso, tex = SunsetAppearance.resolveTorso(ped, gender, top.drawable, top.texture)
    appearance.components['3'] = { drawable = torso, texture = tex }
    return appearance
end

function SunsetAppearance.applyClothes(ped, appearance, gender)
    local c = appearance.components

    local d, t = setComponentSafe(ped, 4, math.max(1, c['4'].drawable or 1))
    c['4'].drawable, c['4'].texture = d, t

    d, t = setComponentSafe(ped, 6, c['6'].drawable or 1)
    c['6'].drawable, c['6'].texture = d, t

    d, t = setComponentSafe(ped, 8, c['8'].drawable or 15)
    c['8'].drawable, c['8'].texture = d, t

    appearance = SunsetAppearance.syncTorso(appearance, ped, gender)

    d, t = setComponentSafe(ped, 3, c['3'].drawable, c['3'].texture)
    c['3'].drawable, c['3'].texture = d, t

    d, t = setComponentSafe(ped, 11, c['11'].drawable, c['11'].texture)
    c['11'].drawable, c['11'].texture = d, t

    return appearance
end

function SunsetAppearance.apply(ped, appearance, gender)
    appearance = SunsetAppearance.normalize(appearance, gender)
    local hb = appearance.headBlend

    appearance = SunsetAppearance.applyClothes(ped, appearance, gender)

    local hd, ht = setComponentSafe(ped, 2, appearance.hair.drawable or 0, appearance.hair.texture or 0)
    appearance.hair.drawable, appearance.hair.texture = hd, ht
    applyHair(ped, appearance.hair)

    if gender == 1 then
        applyOverlay(ped, 1, { index = 0 })
        applyOverlay(ped, 2, appearance.overlays['2'])
    else
        applyOverlay(ped, 1, appearance.overlays['1'])
        applyOverlay(ped, 2, appearance.overlays['2'])
    end

    -- Head blend LAST so skin applies to face + hands after clothing
    applyHeadBlend(ped, hb)

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
    add({ type = 'hairHighlight', label = 'Hair Highlight', min = 0, max = 63, value = appearance.hair.highlight or appearance.hair.color or 0, camera = 'face' })

    if gender ~= 1 then
        local beardMax = overlayMax(1)
        add({ type = 'beard', label = 'Beard Style', min = 0, max = beardMax, value = appearance.overlays['1'].index or 0, camera = 'face' })
        add({ type = 'beardColor', label = 'Beard Color', min = 0, max = 63, value = appearance.overlays['1'].color or 0, camera = 'face' })
        add({ type = 'eyebrows', label = 'Eyebrows', min = 0, max = overlayMax(2), value = appearance.overlays['2'].index or 0, camera = 'face' })
        add({ type = 'eyebrowColor', label = 'Eyebrow Color', min = 0, max = 63, value = appearance.overlays['2'].color or 0, camera = 'face' })
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
        syncSkinTone(appearance.headBlend, value)
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
        if (appearance.hair.highlight or 0) == 0 then
            appearance.hair.highlight = value
        end
    elseif t == 'hairHighlight' then
        appearance.hair.highlight = value
    elseif t == 'beard' then
        appearance.overlays['1'].index = value
        appearance.overlays['1'].opacity = value == 0 and 0.0 or 0.99
    elseif t == 'beardColor' then
        appearance.overlays['1'].color = value
        if (appearance.overlays['1'].index or 0) == 0 then
            appearance.overlays['1'].index = 1
            appearance.overlays['1'].opacity = 0.99
        end
    elseif t == 'eyebrows' then
        appearance.overlays['2'].index = value
        appearance.overlays['2'].opacity = value == 0 and 0.0 or 0.99
    elseif t == 'eyebrowColor' then
        appearance.overlays['2'].color = value
        if (appearance.overlays['2'].index or 0) == 0 then
            appearance.overlays['2'].index = 1
            appearance.overlays['2'].opacity = 0.99
        end
    elseif t == 'component' then
        local slot = tonumber(change.component)
        if slot then
            appearance.components[tostring(slot)] = appearance.components[tostring(slot)] or { drawable = 0, texture = 0 }
            appearance.components[tostring(slot)].drawable = value
            appearance.components[tostring(slot)].texture = 0
            if slot == 8 or slot == 11 then
                appearance = SunsetAppearance.syncTorso(appearance, ped, gender)
            end
        end
    end

    SunsetAppearance.apply(ped, appearance, gender)
    return appearance
end

function SunsetAppearance.maxDrawable(ped, slot, appearance, gender)
    appearance = SunsetAppearance.normalize(appearance, gender)
    return drawableMax(ped, slot)
end
