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

local FxRate = {}
local DynoSessions = {}

local function activeVehicle(source, plate, requireShop)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'Player entity is unavailable' end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 or GetEntityType(veh) ~= 2 then return nil, 'Sit in the driver seat of the vehicle' end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil, 'Only the driver can tune this vehicle' end
    if normalizePlate(GetVehicleNumberPlateText(veh)) ~= plate then return nil, 'Vehicle plate changed; reopen the tuning menu' end
    if requireShop then
        local pos = GetEntityCoords(veh)
        local close = false
        for _, shop in ipairs(SunsetTuning.Shops or {}) do
            if #(pos - shop.coords) <= (SunsetTuning.InteractRadius or 6.0) + 4.0 then close = true break end
        end
        if not close then return nil, 'Bring the vehicle inside a tuning shop' end
    end
    return veh
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

    local changed = MySQL.update.await(
        'UPDATE vehicles SET props = ?, plate = ? WHERE id = ? AND character_id = ?',
        { json.encode(props), newPlate, row.id, charId }
    )
    if not changed or changed < 1 then return false, 'Vehicle changed while the tune was being saved', plate end
    return true, nil, newPlate
end

exports.sunset_core:RegisterCallback('sunset:tuning:getTune', function(source, plate)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end
    local veh, vehicleError = activeVehicle(source, plate, false)
    if not veh then return nil, vehicleError end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    local props = decodeProps(row.props)
    local cosmetics = props.cosmetics and SunsetTuning.SanitizeCosmetics(props.cosmetics) or nil
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
    local veh, vehicleError = activeVehicle(source, plate, true)
    if not veh then return nil, vehicleError end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    local sanitized
    if type(tune) == 'table' then
        sanitized = SunsetTuning.SanitizeTune(tune)
    else
        return nil, 'Invalid tune data'
    end
    local props = decodeProps(row.props)
    local oldTune = props.ecu or SunsetTuning.StockTune()
    local sanitizedCosmetics = SunsetTuning.SanitizeCosmetics(cosmetics)
    local oldCosmetics = props.cosmetics or sanitizedCosmetics
    local cost = SunsetTuning.CalculateInstallCost(oldTune, sanitized, oldCosmetics, sanitizedCosmetics, flash == true)

    if not exports.sunset_core:RemoveMoney(source, 'bank', cost, 'ECU tune save') then
        return nil, ('Need $%d in bank for ECU save'):format(cost)
    end

    local callOk, ok, err, newPlate = pcall(saveTuneToVehicle, char.id, plate, sanitized, sanitizedCosmetics)
    if not callOk or not ok then
        exports.sunset_core:AddMoney(source, 'bank', cost, 'ECU tune refund')
        return nil, callOk and (err or 'Save failed') or 'Database error while saving; your money was refunded'
    end

    TriggerClientEvent('sunset:tuning:client:applyByPlate', -1, newPlate or plate, sanitized)
    return { tune = sanitized, cost = cost, plate = newPlate or plate, cosmetics = sanitizedCosmetics }
end)

exports.sunset_core:RegisterCallback('sunset:tuning:beginDyno', function(source, plate)
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    plate = normalizePlate(plate)
    if plate == '' then return nil, 'Invalid plate' end
    local veh, vehicleError = activeVehicle(source, plate, true)
    if not veh then return nil, vehicleError end

    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end
    if DynoSessions[source] then return nil, 'A dyno run is already active' end

    if not exports.sunset_core:RemoveMoney(source, 'bank', SunsetTuning.DynoCost, 'Dyno run') then
        return nil, ('Need $%d in bank for dyno'):format(SunsetTuning.DynoCost)
    end

    local token = ('%d:%d:%d'):format(source, os.time(), math.random(100000, 999999))
    DynoSessions[source] = { token = token, plate = plate, startedAt = os.time() }
    return { token = token, cost = SunsetTuning.DynoCost }
end)

exports.sunset_core:RegisterCallback('sunset:tuning:cancelDyno', function(source, token)
    local session = DynoSessions[source]
    if not session or session.token ~= tostring(token or '') then return false end
    DynoSessions[source] = nil
    exports.sunset_core:AddMoney(source, 'bank', SunsetTuning.DynoCost, 'Dyno cancelled refund')
    return true
end)

exports.sunset_core:RegisterCallback('sunset:tuning:finishDyno', function(source, token, hp, torque)
    local session = DynoSessions[source]
    DynoSessions[source] = nil
    if not session or session.token ~= tostring(token or '') then return nil, 'Dyno session is not valid' end
    local elapsed = os.time() - session.startedAt
    if elapsed < 8 or elapsed > 45 then return nil, 'Dyno run timing is invalid' end
    local plate = session.plate
    local veh, vehicleError = activeVehicle(source, plate, true)
    if not veh then return nil, vehicleError end
    local char = getCharacter(source)
    if not char then return nil, 'No character' end
    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return nil, 'Not your vehicle' end

    local props = decodeProps(row.props)
    local tune = SunsetTuning.SanitizeTune(props.ecu)
    tune.dyno.lastHp = math.max(0, math.min(2000, math.floor(tonumber(hp) or 0)))
    tune.dyno.lastTorque = math.max(0, math.min(2000, math.floor(tonumber(torque) or 0)))
    tune.dyno.lastRunAt = os.time()

    local callOk, ok, err = pcall(saveTuneToVehicle, char.id, plate, tune, nil)
    if not callOk or not ok then
        exports.sunset_core:AddMoney(source, 'bank', SunsetTuning.DynoCost, 'Dyno error refund')
        return nil, callOk and (err or 'Dyno save failed') or 'Dyno database error; your money was refunded'
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
    local veh = activeVehicle(src, plate, true)
    if not veh then return end
    local row = getOwnedVehicleRow(char.id, plate)
    if not row then return end
    local props = decodeProps(row.props)
    if not props.ecu then return end
    TriggerClientEvent('sunset:tuning:client:applyByPlate', -1, plate, SunsetTuning.SanitizeTune(props.ecu))
end)

RegisterNetEvent('sunset:tuning:syncExhaustFx', function(netId, fxType, intensity, color)
    local src = source
    local now = GetGameTimer()
    if now - (FxRate[src] or 0) < 120 then return end
    FxRate[src] = now
    netId = tonumber(netId)
    if not netId or netId == 0 then return end
    local allowedFx = { pop = true, twostep = true, antilag = true, flame = true, extra = true, diesel = true, smoke = true, flash = true }
    fxType = type(fxType) == 'string' and fxType or 'pop'
    if not allowedFx[fxType] then return end
    intensity = math.max(0.1, math.min(1.0, tonumber(intensity) or 0.5))
    if type(color) ~= 'table' then color = { r = 255, g = 120, b = 40 } end

    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or GetEntityType(entity) ~= 2
        or GetVehiclePedIsIn(srcPed, false) ~= entity or GetPedInVehicleSeat(entity, -1) ~= srcPed then return end
    local plate = normalizePlate(GetVehicleNumberPlateText(entity))
    local char = getCharacter(src)
    local row = char and plate ~= '' and getOwnedVehicleRow(char.id, plate) or nil
    if not row then return end
    local props = decodeProps(row.props)
    local persistedTune = props.ecu and SunsetTuning.SanitizeTune(props.ecu) or nil
    if not persistedTune or SunsetTuning.IsStockTune(persistedTune) then return end
    local mode = SunsetTuning.ExhaustModes[persistedTune.exhaust] or {}
    if (fxType == 'pop' and not persistedTune.pop.enabled)
        or (fxType == 'twostep' and (not persistedTune.pop.enabled or not persistedTune.hardware.launchControl))
        or (fxType == 'antilag' and not persistedTune.antiLag.enabled)
        or ((fxType == 'flame' or fxType == 'extra' or fxType == 'flash') and not persistedTune.flames.enabled)
        or ((fxType == 'diesel' or fxType == 'smoke') and not mode.diesel) then return end
    color = persistedTune.flames.color
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

AddEventHandler('playerDropped', function()
    DynoSessions[source] = nil
    FxRate[source] = nil
end)

exports('GetVehicleTuningInfo', function(rawProps)
    local decoded = decodeProps(rawProps)
    local ecu = decoded and decoded.ecu or nil
    local cosmetics = decoded and decoded.cosmetics or nil
    local info = SunsetTuning.BuildVehicleInfo(ecu)

    local mods = {}
    if decoded.modEngine and decoded.modEngine >= 0 then
        mods[#mods + 1] = ('Motor: Nivel %d/4'):format(decoded.modEngine + 1)
    end
    if decoded.modBrakes and decoded.modBrakes >= 0 then
        mods[#mods + 1] = ('Frâne: Nivel %d/3'):format(decoded.modBrakes + 1)
    end
    if decoded.modTransmission and decoded.modTransmission >= 0 then
        mods[#mods + 1] = ('Transmisie: Nivel %d/3'):format(decoded.modTransmission + 1)
    end
    if decoded.modSuspension and decoded.modSuspension >= 0 then
        mods[#mods + 1] = ('Suspensie: Nivel %d/4'):format(decoded.modSuspension + 1)
    end
    if decoded.modTurbo and (decoded.modTurbo == 1 or decoded.modTurbo == true) then
        mods[#mods + 1] = 'Turbină instalată'
    end
    if decoded.windowTint and decoded.windowTint > 0 then
        local tints = { [1] = 'Pure Black (Ilegal)', [2] = 'Dark Smoke', [3] = 'Light Smoke', [4] = 'Stock', [5] = 'Limo (Ilegal)', [6] = 'Green' }
        mods[#mods + 1] = ('Folii geamuri: %s'):format(tints[decoded.windowTint] or ('Nivel ' .. decoded.windowTint))
    end
    if cosmetics and cosmetics.plateText and cosmetics.plateText ~= '' then
        mods[#mods + 1] = ('Plăcuță custom: %s'):format(cosmetics.plateText)
    end

    local isTuned = info.tuned
    if not isTuned and (#mods > 0) then
        for _, m in ipairs(mods) do
            if m:find('Turbină') or m:find('Motor') or m:find('Ilegal') then
                isTuned = true
                break
            end
        end
    end

    return {
        tuned = isTuned,
        stock = not isTuned,
        summary = info.summary,
        chips = info.chips or {},
        lines = info.lines or {},
        hardwareMods = mods,
    }
end)

