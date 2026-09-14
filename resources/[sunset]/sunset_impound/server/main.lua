-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Vehicle Impound (server/main.lua)
--  Police confiscation + owner recovery at the impound lot.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetImpound.Config

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function getCharId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id) or nil
end

-- ═══ IMPOUND (police) ═══

exports.sunset_core:RegisterCallback('sunset:impound:confiscate', function(source, vehicleId, reasonId)
    -- Must be law enforcement on duty
    local isLE = false
    pcall(function()
        isLE = exports.sunset_factions:HasFactionPerm(source, 'impound') == true
    end)
    if not isLE then
        return nil, 'Only law enforcement on duty can impound vehicles.'
    end

    vehicleId = tonumber(vehicleId)
    if not vehicleId then return nil, 'Invalid vehicle.' end

    reasonId = tostring(reasonId or 'other')
    local reasonRow = nil
    for _, r in ipairs(Cfg.reasons or {}) do
        if r.id == reasonId then reasonRow = r break end
    end
    if not reasonRow then reasonRow = { id = 'other', label = 'Other', fee = Cfg.baseFee or 500 } end

    -- Get vehicle info
    local veh = nil
    pcall(function()
        veh = exports.sunset_vehicles:GetVehicleById(vehicleId)
    end)
    if not veh then return nil, 'Vehicle not found.' end

    local ownerCharId = tonumber(veh.character_id)
    if not ownerCharId then return nil, 'This vehicle has no registered owner.' end

    -- Check if already impounded
    local existing = MySQL.scalar.await(
        'SELECT id FROM impounded_vehicles WHERE vehicle_id = ? AND status = "impounded" LIMIT 1', { vehicleId })
    if existing then return nil, 'This vehicle is already impounded.' end

    local impoundedByName = exports.sunset_core:GetPlayerDisplayName(source) or 'Officer'
    local impoundedBy = getCharId(source)

    MySQL.insert.await([[
        INSERT INTO impounded_vehicles (vehicle_id, character_id, impounded_by, impounded_by_name, reason, fee, daily_fee)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { vehicleId, ownerCharId, impoundedBy, impoundedByName, reasonRow.label, reasonRow.fee, Cfg.dailyFee or 100 })

    -- Delete the vehicle entity from the world
    pcall(function()
        exports.sunset_vehicles:DeleteVehicleEntity(vehicleId)
    end)

    notify(source, ('Vehicle impounded: %s (%s).'):format(veh.plate or 'Unknown', reasonRow.label), 'success')

    -- Notify owner if online
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local cid = getCharId(src)
        if cid == ownerCharId then
            notify(src, ('Your vehicle %s has been impounded by %s. Reason: %s. Recover it at the impound lot.'):format(
                veh.plate or 'Unknown', impoundedByName, reasonRow.label), 'error', 10000)
        end
    end

    return true
end)

-- ═══ RECOVERY (owner) ═══

exports.sunset_core:RegisterCallback('sunset:impound:list', function(source)
    local charId = getCharId(source)
    if not charId then return nil, 'No character loaded.' end

    local rows = MySQL.query.await([[
        SELECT iv.id, iv.vehicle_id, iv.reason, iv.fee, iv.daily_fee, iv.impounded_at, iv.impounded_by_name,
               v.plate, v.model
        FROM impounded_vehicles iv
        LEFT JOIN vehicles v ON v.id = iv.vehicle_id
        WHERE iv.character_id = ? AND iv.status = 'impounded'
        ORDER BY iv.impounded_at DESC
    ]], { charId }) or {}

    local now = os.time()
    local result = {}
    for _, row in ipairs(rows) do
        local impoundedAt = 0
        if row.impounded_at then
            -- Parse MySQL timestamp
            local y, mo, d, h, mi, s = tostring(row.impounded_at):match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
            if y then
                impoundedAt = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                    hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
            end
        end
        local daysHeld = math.floor((now - impoundedAt) / 86400)
        local totalFee = (tonumber(row.fee) or 0) + (tonumber(row.daily_fee) or 0) * daysHeld

        result[#result + 1] = {
            impoundId = row.id,
            vehicleId = row.vehicle_id,
            plate = row.plate or 'Unknown',
            model = row.model or 'Unknown',
            reason = row.reason,
            fee = totalFee,
            baseFee = tonumber(row.fee) or 0,
            daysHeld = daysHeld,
            impoundedBy = row.impounded_by_name or 'Unknown',
        }
    end

    return result
end)

exports.sunset_core:RegisterCallback('sunset:impound:recover', function(source, impoundId)
    local charId = getCharId(source)
    if not charId then return nil, 'No character loaded.' end

    impoundId = tonumber(impoundId)
    if not impoundId then return nil, 'Invalid impound record.' end

    local row = MySQL.single.await([[
        SELECT iv.*, v.plate, v.model FROM impounded_vehicles iv
        LEFT JOIN vehicles v ON v.id = iv.vehicle_id
        WHERE iv.id = ? AND iv.character_id = ? AND iv.status = 'impounded'
    ]], { impoundId, charId })
    if not row then return nil, 'Impound record not found.' end

    -- Calculate total fee
    local now = os.time()
    local impoundedAt = 0
    if row.impounded_at then
        local y, mo, d, h, mi, s = tostring(row.impounded_at):match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
        if y then
            impoundedAt = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
        end
    end
    local daysHeld = math.floor((now - impoundedAt) / 86400)
    local totalFee = (tonumber(row.fee) or 0) + (tonumber(row.daily_fee) or 0) * daysHeld

    -- Check if player is near the impound lot (server-side coords check)
    local nearLot = false
    pcall(function()
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            nearLot = #(coords - Cfg.lot) < 10.0
        end
    end)
    if not nearLot then
        return nil, 'You must be at the impound lot to recover your vehicle.'
    end

    -- Charge the fee
    if not exports.sunset_core:RemoveMoney(source, 'cash', totalFee, 'impound_fee') then
        return nil, ('Not enough cash. Recovery fee: $%s.'):format(totalFee)
    end

    -- Mark as released
    MySQL.update.await('UPDATE impounded_vehicles SET status = "released", released_at = NOW() WHERE id = ?', { impoundId })

    -- Respawn the vehicle at the impound lot
    pcall(function()
        exports.sunset_vehicles:SpawnVehicleAt(source, row.vehicle_id, Cfg.lot, Cfg.lotHeading)
    end)

    notify(source, ('Vehicle %s recovered for $%s.'):format(row.plate or 'Unknown', totalFee), 'success')
    return { plate = row.plate, fee = totalFee }
end)

-- ═══ AUTO-SELL (expired impounds) ═══

CreateThread(function()
    Wait(30000) -- Wait for server to fully boot
    while true do
        Wait(3600000) -- Check every hour
        local cutoff = os.date('%Y-%m-%d %H:%M:%S', os.time() - (Cfg.autoSellDays or 7) * 86400)
        local expired = MySQL.query.await(
            'SELECT id, vehicle_id FROM impounded_vehicles WHERE status = "impounded" AND impounded_at < ?', { cutoff }) or {}
        for _, row in ipairs(expired) do
            MySQL.update.await('UPDATE impounded_vehicles SET status = "sold" WHERE id = ?', { row.id })
            pcall(function()
                exports.sunset_vehicles:DeleteVehicleRecord(row.vehicle_id)
            end)
            print(('[sunset_impound] Vehicle %d sold (impound expired)'):format(row.vehicle_id))
        end
    end
end)

print('^2[sunset_impound]^7 Vehicle impound system online')
