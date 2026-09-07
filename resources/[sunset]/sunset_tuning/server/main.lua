local function normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

local function decodeProps(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, props = pcall(json.decode, raw)
    return (ok and type(props) == 'table') and props or {}
end

local function getCharacter(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char or not char.id then return nil end
    return char
end

local function getOwnedVehicleRow(charId, plate)
    return MySQL.single.await(
        'SELECT id, props FROM vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND character_id = ? LIMIT 1',
        { plate, charId }
    )
end

local function saveTuneToVehicle(charId, plate, tune)
    local row = getOwnedVehicleRow(charId, plate)
    if not row then return false, 'Vehicle not found in your garage' end

    local props = decodeProps(row.props)
    props.ecu = tune
    MySQL.update.await('UPDATE vehicles SET props = ? WHERE id = ? AND character_id = ?',
        { json.encode(props), row.id, charId })
    return true
end

exports.sunset_core:RegisterCallback('sunset:tuning:getTune', function(source, plate)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    local props = decodeProps(row.props)
    return SunsetTuning.SanitizeTune(props.ecu)
end)

exports.sunset_core:RegisterCallback('sunset:tuning:saveTune', function(source, plate, tune, flash)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    local sanitized = SunsetTuning.SanitizeTune(tune)
    local cost = SunsetTuning.SaveBaseCost + (flash and SunsetTuning.FlashCost or 0)

    if not Sunset.RemoveMoney(source, 'bank', cost, 'ECU tune save') then
        return nil, ('Need $%d in bank for ECU save'):format(cost)
    end

    local ok, err = saveTuneToVehicle(char.id, plate, sanitized)
    if not ok then
        Sunset.AddMoney(source, 'bank', cost, 'ECU tune refund')
        return nil, err or 'Save failed'
    end

    return { tune = sanitized, cost = cost }
end)

exports.sunset_core:RegisterCallback('sunset:tuning:runDyno', function(source, plate, hp, torque)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    if not Sunset.RemoveMoney(source, 'bank', SunsetTuning.DynoCost, 'Dyno run') then
        return nil, ('Need $%d in bank for dyno'):format(SunsetTuning.DynoCost)
    end

    local props = decodeProps(row.props)
    local tune = SunsetTuning.SanitizeTune(props.ecu)
    tune.dyno.lastHp = math.max(0, math.min(2000, math.floor(tonumber(hp) or 0)))
    tune.dyno.lastTorque = math.max(0, math.min(2000, math.floor(tonumber(torque) or 0)))
    tune.dyno.lastRunAt = os.time()

    local ok, err = saveTuneToVehicle(char.id, plate, tune)
    if not ok then
        Sunset.AddMoney(source, 'bank', SunsetTuning.DynoCost, 'Dyno refund')
        return nil, err or 'Dyno save failed'
    end

    return tune.dyno
end)

exports.sunset_core:RegisterCallback('sunset:tuning:getLeaderboard', function(source)
    local rows = MySQL.query.await([[
        SELECT v.plate, v.model, JSON_UNQUOTE(JSON_EXTRACT(v.props, '$.ecu.dyno.lastHp')) AS hp,
               JSON_UNQUOTE(JSON_EXTRACT(v.props, '$.ecu.dyno.lastTorque')) AS torque
        FROM vehicles v
        WHERE JSON_EXTRACT(v.props, '$.ecu.dyno.lastHp') IS NOT NULL
          AND CAST(JSON_UNQUOTE(JSON_EXTRACT(v.props, '$.ecu.dyno.lastHp')) AS UNSIGNED) > 0
        ORDER BY CAST(JSON_UNQUOTE(JSON_EXTRACT(v.props, '$.ecu.dyno.lastHp')) AS UNSIGNED) DESC
        LIMIT 15
    ]]) or {}

    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            plate = row.plate,
            model = row.model,
            hp = math.floor(tonumber(row.hp) or 0),
            torque = math.floor(tonumber(row.torque) or 0),
        }
    end
    return out
end)

RegisterNetEvent('sunset:tuning:flashApplied', function(plate)
    local src = source
    local char = getCharacter(src)
    if not char then return end
    plate = normalizePlate(plate)
    TriggerClientEvent('sunset:tuning:client:applyByPlate', -1, plate)
end)
