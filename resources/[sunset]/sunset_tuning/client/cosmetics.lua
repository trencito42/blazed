local STC = SunsetTuningClient

function ReadCosmeticsFromVehicle(veh)
    if not veh or veh == 0 then return SunsetTuning.DefaultCosmetics() end
    local pr, pg, pb = GetVehicleCustomPrimaryColour(veh)
    local sr, sg, sb = GetVehicleCustomSecondaryColour(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)
    return SunsetTuning.SanitizeCosmetics({
        primary = { r = pr, g = pg, b = pb },
        secondary = { r = sr, g = sg, b = sb },
        pearl = pearl,
        wheel = wheel,
        plateText = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''):upper(),
    })
end

function ApplyCosmetics(veh, cosmetics, applyPlate)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    cosmetics = SunsetTuning.SanitizeCosmetics(cosmetics)
    local p = cosmetics.primary
    local s = cosmetics.secondary

    SetVehicleModColor_1(veh, 0)
    SetVehicleModColor_2(veh, 0)
    SetVehicleCustomPrimaryColour(veh, p.r, p.g, p.b)
    SetVehicleCustomSecondaryColour(veh, s.r, s.g, s.b)
    if cosmetics.pearl then
        SetVehicleExtraColours(veh, cosmetics.pearl, cosmetics.wheel or 0)
    end

    if applyPlate ~= false and cosmetics.plateText and cosmetics.plateText ~= '' then
        SetVehicleNumberPlateText(veh, cosmetics.plateText)
    end
    return true
end

exports('ReadCosmeticsFromVehicle', ReadCosmeticsFromVehicle)
exports('ApplyCosmetics', ApplyCosmetics)
