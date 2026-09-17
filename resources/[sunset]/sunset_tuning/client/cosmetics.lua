local STC = SunsetTuningClient

local MOD_SLOTS = {
    spoiler = 0,
    frontBumper = 1,
    rearBumper = 2,
    sideSkirt = 3,
    exhaust = 4,
    rollCage = 5,
    grille = 6,
    hood = 7,
    leftFender = 8,
    rightFender = 9,
    roof = 10,
    wheels = 23,
    livery = 48,
}

function ReadCosmeticsFromVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return SunsetTuning.DefaultCosmetics() end
    SetVehicleModKit(veh, 0)
    local pr, pg, pb = GetVehicleCustomPrimaryColour(veh)
    local sr, sg, sb = GetVehicleCustomSecondaryColour(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)

    local neonEnabled = IsVehicleNeonLightEnabled(veh, 0) or IsVehicleNeonLightEnabled(veh, 1) or IsVehicleNeonLightEnabled(veh, 2) or IsVehicleNeonLightEnabled(veh, 3)
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)

    local mods = {}
    for key, slot in pairs(MOD_SLOTS) do
        mods[key] = GetVehicleMod(veh, slot)
    end
    if mods.livery == -1 then
        mods.livery = GetVehicleLivery(veh)
    end

    local paintType = math.max(0, math.min(5, math.floor(tonumber(GetVehicleModColor_1(veh)) or 0)))
    local tyreSmoke = IsToggleModOn(veh, 20)
    local tr, tg, tb = GetVehicleTyreSmokeColor(veh)

    return SunsetTuning.SanitizeCosmetics({
        primary = { r = pr, g = pg, b = pb },
        secondary = { r = sr, g = sg, b = sb },
        paintType = paintType,
        pearl = pearl,
        wheel = wheel,
        plateText = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''):upper(),
        windowTint = GetVehicleWindowTint(veh),
        xenon = IsToggleModOn(veh, 22),
        xenonColor = GetVehicleXenonLightsColor(veh),
        wheelType = GetVehicleWheelType(veh),
        tyreSmoke = tyreSmoke,
        tyreSmokeColor = { r = tr, g = tg, b = tb },
        neon = {
            enabled = neonEnabled,
            left = IsVehicleNeonLightEnabled(veh, 0),
            right = IsVehicleNeonLightEnabled(veh, 1),
            front = IsVehicleNeonLightEnabled(veh, 2),
            back = IsVehicleNeonLightEnabled(veh, 3),
            color = { r = nr, g = ng, b = nb },
        },
        mods = mods,
    })
end

function ApplyCosmetics(veh, cosmetics, applyPlate)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    SetVehicleModKit(veh, 0)
    cosmetics = SunsetTuning.SanitizeCosmetics(cosmetics)
    local p = cosmetics.primary
    local s = cosmetics.secondary

    local paintType = tonumber(cosmetics.paintType) or 0
    local pearl = tonumber(cosmetics.pearl) or 0
    local wheel = tonumber(cosmetics.wheel) or 0

    SetVehicleModColor_1(veh, paintType, 0, pearl)
    SetVehicleModColor_2(veh, paintType, 0)
    SetVehicleCustomPrimaryColour(veh, p.r, p.g, p.b)
    SetVehicleCustomSecondaryColour(veh, s.r, s.g, s.b)
    SetVehicleExtraColours(veh, pearl, wheel)
    SetVehicleModColor_1(veh, paintType, 0, pearl)
    SetVehicleModColor_2(veh, paintType, 0)

    -- Tyre smoke
    if cosmetics.tyreSmoke ~= nil then
        ToggleVehicleMod(veh, 20, cosmetics.tyreSmoke == true)
        if cosmetics.tyreSmoke and cosmetics.tyreSmokeColor then
            SetVehicleTyreSmokeColor(veh, cosmetics.tyreSmokeColor.r or 255, cosmetics.tyreSmokeColor.g or 255, cosmetics.tyreSmokeColor.b or 255)
        end
    end

    -- Window tint
    if cosmetics.windowTint ~= nil then
        SetVehicleWindowTint(veh, cosmetics.windowTint)
    end

    -- Headlights / Xenon
    if cosmetics.xenon ~= nil then
        ToggleVehicleMod(veh, 22, cosmetics.xenon == true)
        if cosmetics.xenon and cosmetics.xenonColor ~= nil then
            SetVehicleXenonLightsColor(veh, cosmetics.xenonColor)
        end
    end

    -- Neons underglow
    if cosmetics.neon then
        local n = cosmetics.neon
        if n.enabled then
            SetVehicleNeonLightEnabled(veh, 0, n.left ~= false)
            SetVehicleNeonLightEnabled(veh, 1, n.right ~= false)
            SetVehicleNeonLightEnabled(veh, 2, n.front ~= false)
            SetVehicleNeonLightEnabled(veh, 3, n.back ~= false)
            if n.color then
                SetVehicleNeonLightsColour(veh, n.color.r or 0, n.color.g or 150, n.color.b or 255)
            end
        else
            SetVehicleNeonLightEnabled(veh, 0, false)
            SetVehicleNeonLightEnabled(veh, 1, false)
            SetVehicleNeonLightEnabled(veh, 2, false)
            SetVehicleNeonLightEnabled(veh, 3, false)
        end
    end

    -- Wheel type & rims
    if cosmetics.wheelType ~= nil then
        SetVehicleWheelType(veh, cosmetics.wheelType)
    end

    -- Body mods
    if cosmetics.mods then
        for key, slot in pairs(MOD_SLOTS) do
            local modIdx = cosmetics.mods[key]
            if modIdx ~= nil then
                if key == 'livery' and modIdx >= 0 and GetNumVehicleMods(veh, 48) <= 0 then
                    SetVehicleLivery(veh, modIdx)
                else
                    SetVehicleMod(veh, slot, modIdx, false)
                end
            end
        end
    end

    if applyPlate ~= false and cosmetics.plateText and cosmetics.plateText ~= '' then
        SetVehicleNumberPlateText(veh, cosmetics.plateText)
    end
    return true
end

exports('ReadCosmeticsFromVehicle', ReadCosmeticsFromVehicle)
exports('ApplyCosmetics', ApplyCosmetics)
