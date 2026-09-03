SunsetAppearance = SunsetAppearance or {}

local OVERLAY_OFF = 255

local function deepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = deepCopy(v) end
    return out
end

function SunsetAppearance.default(_gender)
    return {
        version = 2,
        headBlend = {
            shapeFirst = 0, shapeSecond = 0, shapeThird = 0,
            skinFirst = 0, skinSecond = 0, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
        },
        hair = { drawable = 0, texture = 0, color = 0, highlight = 0 },
        overlays = {
            ['1'] = { index = 0, opacity = 1.0, color = 0 },
            ['2'] = { index = 0, opacity = 1.0, color = 0 },
        },
        components = {
            ['3'] = { drawable = 0, texture = 0 },
            ['4'] = { drawable = 0, texture = 0 },
            ['6'] = { drawable = 0, texture = 0 },
            ['8'] = { drawable = 0, texture = 0 },
            ['11'] = { drawable = 0, texture = 0 },
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
                out.components[k] = out.components[k] or { drawable = 0, texture = 0 }
                if type(v) == 'table' then
                    out.components[k].drawable = v.drawable or 0
                    out.components[k].texture = v.texture or 0
                end
            end
        end
        return out
    end

    -- v1 migration: only numeric component keys
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

    for id, comp in pairs(appearance.components) do
        local slot = tonumber(id)
        if slot and comp then
            SetPedComponentVariation(ped, slot, comp.drawable or 0, comp.texture or 0, 0)
        end
    end

    local hair = appearance.hair
    SetPedComponentVariation(ped, 2, hair.drawable or 0, hair.texture or 0, 0)
    SetPedHairColor(ped, hair.color or 0, hair.highlight or 0)

    for id, ov in pairs(appearance.overlays or {}) do
        local overlayId = tonumber(id)
        if not overlayId then goto continue end
        local index = ov.index
        if index == nil or index == OVERLAY_OFF then
            SetPedHeadOverlay(ped, overlayId, 255, 0.0)
        else
            SetPedHeadOverlay(ped, overlayId, index, ov.opacity or 1.0)
            SetPedHeadOverlayColor(ped, overlayId, 1, ov.color or 0, ov.color or 0)
        end
        ::continue::
    end

    return appearance
end

function SunsetAppearance.extractFromPed(ped, gender)
    local data = SunsetAppearance.default(gender)
    data.headBlend.shapeFirst, data.headBlend.shapeSecond, data.headBlend.shapeThird,
        data.headBlend.skinFirst, data.headBlend.skinSecond, data.headBlend.skinThird,
        data.headBlend.shapeMix, data.headBlend.skinMix, data.headBlend.thirdMix
        = GetPedHeadBlendData(ped)

    data.hair.drawable = GetPedDrawableVariation(ped, 2)
    data.hair.texture = GetPedTextureVariation(ped, 2)
  local color, highlight = GetPedHairColor(ped)
    data.hair.color = color or 0
    data.hair.highlight = highlight or 0

    for _, slot in ipairs({ 3, 4, 6, 8, 11 }) do
        data.components[tostring(slot)] = {
            drawable = GetPedDrawableVariation(ped, slot),
            texture = GetPedTextureVariation(ped, slot),
        }
    end

    for overlayId = 1, 2 do
        local idx = GetPedHeadOverlayValue(ped, overlayId)
        local _, opacity = GetPedHeadOverlay(ped, overlayId)
        data.overlays[tostring(overlayId)] = {
            index = idx,
            opacity = opacity or 1.0,
            color = 0,
        }
    end

    return data
end

function SunsetAppearance.buildEditor(ped, appearance, gender)
    appearance = SunsetAppearance.normalize(appearance, gender)
    local fields = {}

    local function add(field) fields[#fields + 1] = field end

    add({
        type = 'skinTone', label = 'Skin Tone', min = 0, max = 45,
        value = appearance.headBlend.skinFirst or 0, camera = 'face',
    })
    add({
        type = 'shapeFirst', label = 'Face Shape A', min = 0, max = 45,
        value = appearance.headBlend.shapeFirst or 0, camera = 'face',
    })
    add({
        type = 'shapeSecond', label = 'Face Shape B', min = 0, max = 45,
        value = appearance.headBlend.shapeSecond or 0, camera = 'face',
    })
    add({
        type = 'shapeMix', label = 'Face Mix', min = 0, max = 100,
        value = math.floor((appearance.headBlend.shapeMix or 0.5) * 100), camera = 'face',
    })

    add({
        type = 'hairStyle', label = 'Hair Style', min = 0,
        max = math.max(0, GetNumberOfPedDrawableVariations(ped, 2) - 1),
        value = appearance.hair.drawable or 0, camera = 'face',
    })
    add({
        type = 'hairColor', label = 'Hair Color', min = 0, max = 63,
        value = appearance.hair.color or 0, camera = 'face',
    })

    if gender ~= 1 then
        local beardMax = math.max(0, GetNumHeadOverlayValues(ped, 1) - 1)
        add({
            type = 'beard', label = 'Beard', min = 0, max = beardMax,
            value = appearance.overlays['1'].index or 0, camera = 'face',
        })
        add({
            type = 'beardColor', label = 'Beard Color', min = 0, max = 63,
            value = appearance.overlays['1'].color or 0, camera = 'face',
        })
    end

    local clothes = {
        { 3, 'Arms / Torso', 'full' },
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
            min = 0, max = math.max(0, GetNumberOfPedDrawableVariations(ped, slot) - 1),
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
