exports.sunset_core:RegisterCallback('sunset:world:canUseFactionLift', function(source, factionId)
    factionId = tostring(factionId or '')
    if factionId == '' then return false end

    if Player(source).state.sunsetFaction == factionId then
        return true
    end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end

    local md = char.metadata or {}
    if md.faction == factionId then return true end
    if char.job == factionId then return true end

    return false
end)
