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

local function saveTuneToVehicle(charId, plate, tune, cosmetics)
    local row = getOwnedVehicleRow(charId, plate)
    if not row then return false, 'Vehicle not found in your garage', plate end

    local props = decodeProps(row.props)
    if SunsetTuning.IsStockTune(tune) then
        props.ecu = nil
    else
        props.ecu = tune
    end

    if type(cosmetics) == 'table' then
        props.cosmetics = SunsetTuning.SanitizeCosmetics(cosmetics)
    end

    local newPlate = plate
    local vanity = props.cosmetics and props.cosmetics.plateText
    if vanity and vanity ~= '' then
        vanity = normalizePlate(vanity)
        if vanity ~= '' and vanity ~= plate then
            local taken = MySQL.single.await(
                'SELECT id FROM vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND id != ? LIMIT 1',
                { vanity, row.id }
            )
            if taken then return false, 'Numarul de inmatriculare este deja folosit', plate end
            newPlate = vanity
        end
    end

    MySQL.update.await(
        'UPDATE vehicles SET props = ?, plate = ? WHERE id = ? AND character_id = ?',
        { json.encode(props), newPlate, row.id, charId }
    )
    return true, nil, newPlate
end

exports.sunset_core:RegisterCallback('sunset:tuning:getTune', function(source, plate)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    local props = decodeProps(row.props)
    local cosmetics = SunsetTuning.SanitizeCosmetics(props.cosmetics)
    if props.ecu and not SunsetTuning.IsStockTune(props.ecu) then
        return {
            tune = SunsetTuning.SanitizeTune(props.ecu),
            saved = true,
            cosmetics = cosmetics,
        }
    end
    return {
        tune = SunsetTuning.StockTune(),
        saved = false,
        cosmetics = cosmetics,
    }
end)

exports.sunset_core:RegisterCallback('sunset:tuning:saveTune', function(source, plate, tune, flash, cosmetics)
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

    local ok, err, newPlate = saveTuneToVehicle(char.id, plate, sanitized, cosmetics)
    if not ok then
        exports.sunset_core:AddMoney(source, 'bank', cost, 'ECU tune refund')
        return nil, err or 'Save failed'
    end

    return { tune = sanitized, cost = cost, plate = newPlate or plate, cosmetics = SunsetTuning.SanitizeCosmetics(cosmetics) }
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

    local ok, err = saveTuneToVehicle(char.id, plate, tune, nil)
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

RegisterNetEvent('sunset:tuning:flashApplied', function(plate, tune)
    local src = source
    local char = getCharacter(src)
    if not char then return end
    plate = normalizePlate(plate)
    TriggerClientEvent('sunset:tuning:client:applyByPlate', -1, plate, tune)
end)

RegisterNetEvent('sunset:tuning:syncExhaustFx', function(netId, fxType, intensity, color)
    local src = source
    netId = tonumber(netId)
    if not netId or netId == 0 then return end
    fxType = type(fxType) == 'string' and fxType or 'pop'
    intensity = math.max(0.1, math.min(1.0, tonumber(intensity) or 0.5))
    if type(color) ~= 'table' then color = { r = 255, g = 120, b = 40 } end

    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return end
    local coords = GetEntityCoords(srcPed)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid and pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 and #(coords - GetEntityCoords(ped)) < 90.0 then
                TriggerClientEvent('sunset:tuning:client:exhaustFx', pid, netId, fxType, intensity, color)
            end
        end
    end
end)
