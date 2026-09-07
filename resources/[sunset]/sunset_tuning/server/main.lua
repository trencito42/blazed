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
    if SunsetTuning.IsStockTune(tune) then
        props.ecu = nil
    else
        props.ecu = tune
    end
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
    if props.ecu and not SunsetTuning.IsStockTune(props.ecu) then
        return {
            tune = SunsetTuning.SanitizeTune(props.ecu),
            saved = true,
        }
    end
    return {
        tune = SunsetTuning.StockTune(),
        saved = false,
    }
end)

exports.sunset_core:RegisterCallback('sunset:tuning:saveTune', function(source, plate, tune, flash)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    local sanitized
    if type(tune) == 'table' then
        sanitized = SunsetTuning.SanitizeTune(tune)
    else
        return nil, 'Invalid tune data'
    end
    local cost = SunsetTuning.SaveBaseCost + (flash and SunsetTuning.FlashCost or 0)

    if not exports.sunset_core:RemoveMoney(source, 'bank', cost, 'ECU tune save') then
        return nil, ('Need $%d in bank for ECU save'):format(cost)
    end

    local ok, err = saveTuneToVehicle(char.id, plate, sanitized)
    if not ok then
        exports.sunset_core:AddMoney(source, 'bank', cost, 'ECU tune refund')
        return nil, err or 'Save failed'
    end

    return { tune = sanitized, cost = cost }
end)

exports.sunset_core:RegisterCallback('sunset:tuning:runDyno', function(source, plate, hp, torque, clientTune)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    if not exports.sunset_core:RemoveMoney(source, 'bank', SunsetTuning.DynoCost, 'Dyno run') then
        return nil, ('Need $%d in bank for dyno'):format(SunsetTuning.DynoCost)
    end

    local props = decodeProps(row.props)
    local tune
    if type(clientTune) == 'table' then
        tune = SunsetTuning.SanitizeTune(clientTune)
    else
        tune = SunsetTuning.SanitizeTune(props.ecu)
    end
    tune.dyno.lastHp = math.max(0, math.min(2000, math.floor(tonumber(hp) or 0)))
    tune.dyno.lastTorque = math.max(0, math.min(2000, math.floor(tonumber(torque) or 0)))
    tune.dyno.lastRunAt = os.time()

    local ok, err = saveTuneToVehicle(char.id, plate, tune)
    if not ok then
        exports.sunset_core:AddMoney(source, 'bank', SunsetTuning.DynoCost, 'Dyno refund')
        return nil, err or 'Dyno save failed'
    end

    return tune.dyno
end)

exports.sunset_core:RegisterCallback('sunset:tuning:getLeaderboard', function(source)
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT plate, model, props FROM vehicles
            WHERE props IS NOT NULL
            ORDER BY id DESC
            LIMIT 200
        ]]) or {}
    end)

    if not ok then
        print(('^1[sunset_tuning]^7 leaderboard query failed: %s'):format(tostring(rows)))
        return {}
    end

    local out = {}
    for _, row in ipairs(rows) do
        local props = decodeProps(row.props)
        local tune = props.ecu and SunsetTuning.SanitizeTune(props.ecu) or nil
        local hp = tune and tune.dyno and tune.dyno.lastHp or 0
        if hp > 0 then
            out[#out + 1] = {
                plate = row.plate,
                model = row.model,
                hp = hp,
                torque = tune.dyno.lastTorque or 0,
            }
        end
    end

    table.sort(out, function(a, b) return (a.hp or 0) > (b.hp or 0) end)
    if #out > 15 then
        local trimmed = {}
        for i = 1, 15 do trimmed[i] = out[i] end
        out = trimmed
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
