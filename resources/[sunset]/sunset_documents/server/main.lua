exports.sunset_core:RegisterCallback('sunset:getDocuments', function(source, kind)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return nil end

    local player = exports.sunset_core:GetPlayer(source)
    local displayName = exports.sunset_core:GetPlayerDisplayName(source)

    local licenses = MySQL.query.await(
        'SELECT license_type, issued_at FROM character_licenses WHERE character_id = ?',
        { char.id }
    ) or {}

    local invLicenses = {}
    if exports.sunset_inventory:HasItem(source, 'driver_license') then
        invLicenses[#invLicenses + 1] = { license_type = 'driver', issued_at = 'Inventory item' }
    end
    if exports.sunset_inventory:HasItem(source, 'id_card') then
        invLicenses[#invLicenses + 1] = { license_type = 'id_card', issued_at = 'Inventory item' }
    end

    local allLicenses = licenses
    for _, row in ipairs(invLicenses) do
        allLicenses[#allLicenses + 1] = row
    end

    return {
        kind = kind or 'all',
        id = {
            name = displayName,
            dob = char.dateofbirth or '—',
            nationality = char.nationality or '—',
            cid = char.id,
            account = player and player.name or displayName,
        },
        licenses = allLicenses,
        job = char.job or 'unemployed',
    }
end)
