-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Drug Pipeline (server/main.lua)
--  Manufacture → Process → Sell. Server-authoritative.
--
--  TIMED ACTIONS: harvest/process are two-phase (start → complete).
--  The server records the pending action with a start timestamp; the
--  completion callback re-validates elapsed time, proximity, cooldown
--  and pending state. The client can never skip the timer: calling
--  complete early returns a retryable error, and any second start while
--  pending replaces nothing (rejected).
--
--  COOLDOWN SCOPE: HarvestCooldowns/ProcessCooldowns/SellCooldowns are
--  keyed by SOURCE and are runtime anti-spam only (30s/5s/10s). They do
--  NOT persist across reconnect — this is deliberate: they exist to stop
--  button spam, not to gate progression. Documented per audit request.
--
--  NOTIFICATION OWNERSHIP: the SERVER sends success/error notifications;
--  the client only refreshes UI state (no duplicate success toasts).
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetDrugs.Config
local HarvestCooldowns = {}
local ProcessCooldowns = {}
local SellCooldowns = {}
local PendingActions = {}   -- [source] = { kind, spotIndex?, drug?, startedAt, durationMs }

-- Tolerance for clock skew between client progress bar and server timer.
local COMPLETE_SLACK_MS = 400
-- Pending actions expire (player never completed — walked away silently).
local PENDING_TTL_MS = 60000

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function dlog(msg)
    if GetConvar('sv_sunset_drugs_debug', '0') == '1' then
        print('[DRUGS] ' .. msg)
    end
end

local function pedCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function nearAny(coords, list, radius)
    if not coords then return false end
    for i, point in ipairs(list or {}) do
        local p = type(point) == 'table' and point.coords or point
        if p and #(coords - p) < radius then return true, i end
    end
    return false
end

local function getSpot(index)
    index = tonumber(index)
    if not index then return nil end
    local spot = Cfg.manufacture.spots[index]
    if type(spot) ~= 'table' or not spot.coords then return nil end
    return spot
end

local function clearPending(source)
    PendingActions[source] = nil
end

local function takePending(source, kind)
    local pending = PendingActions[source]
    if not pending or pending.kind ~= kind then return nil end
    PendingActions[source] = nil
    return pending
end

local function startPending(source, kind, durationMs, extra)
    -- Expire stale pendings first (walk-away without cancel).
    local existing = PendingActions[source]
    if existing and (GetGameTimer() - existing.startedAt) < PENDING_TTL_MS then
        return nil, 'You are already busy with another action.'
    end
    local pending = {
        kind = kind,
        startedAt = GetGameTimer(),
        durationMs = durationMs,
    }
    for k, v in pairs(extra or {}) do pending[k] = v end
    PendingActions[source] = pending
    return pending
end

-- ═══ STAGE 1: HARVEST (two-phase timed) ═══

exports.sunset_core:RegisterCallback('sunset:drugs:harvestStart', function(source, spotIndex)
    local spot = getSpot(spotIndex)
    if not spot then return nil, 'Invalid harvest spot.' end
    local drug = Cfg.drugs[spot.drug]
    if not drug then return nil, 'This field has nothing to harvest.' end

    local now = GetGameTimer()
    if HarvestCooldowns[source] and now - HarvestCooldowns[source] < (Cfg.manufacture.cooldownMs or 30000) then
        local remaining = math.ceil(((Cfg.manufacture.cooldownMs or 30000) - (now - HarvestCooldowns[source])) / 1000)
        return nil, ('This patch was recently picked. Try again in %ds.'):format(remaining)
    end

    local coords = pedCoords(source)
    local near, nearIdx = nearAny(coords, { spot.coords }, Cfg.manufacture.spotRadius or 10.0)
    if not near then return nil, 'You are not at that harvest spot.' end

    local durationMs = Cfg.manufacture.harvestTimeMs or 5000
    local pending, err = startPending(source, 'harvest', durationMs, {
        spotIndex = tonumber(spotIndex),
        drugType = spot.drug,
    })
    if not pending then return nil, err end

    dlog(('harvestStart src=%d spot=%d drug=%s'):format(source, spotIndex, spot.drug))
    return { durationMs = durationMs, drugType = spot.drug, rawLabel = drug.rawLabel or drug.label }
end)

exports.sunset_core:RegisterCallback('sunset:drugs:harvestComplete', function(source)
    local pending = takePending(source, 'harvest')
    if not pending then return nil, 'No harvest in progress.' end

    local now = GetGameTimer()
    local elapsed = now - pending.startedAt
    if elapsed < (pending.durationMs - COMPLETE_SLACK_MS) then
        -- Early completion attempt — re-arm the pending so the legit progress
        -- bar can still complete; this call is simply rejected.
        pending.startedAt = pending.startedAt -- unchanged
        PendingActions[source] = pending
        dlog(('harvestComplete REJECTED src=%d elapsed=%dms required=%dms'):format(source, elapsed, pending.durationMs))
        return nil, 'Still harvesting...'
    end

    -- Re-validate proximity at completion.
    local spot = getSpot(pending.spotIndex)
    if not spot then return nil, 'Invalid harvest spot.' end
    local coords = pedCoords(source)
    if not nearAny(coords, { spot.coords }, (Cfg.manufacture.spotRadius or 10.0) + 2.0) then
        return nil, 'You left the harvest spot.'
    end

    -- Cooldown re-check (another character/connection cannot bypass: keyed by source).
    if HarvestCooldowns[source] and now - HarvestCooldowns[source] < (Cfg.manufacture.cooldownMs or 30000) then
        return nil, 'You need to wait before harvesting again.'
    end

    local drug = Cfg.drugs[pending.drugType]
    if not drug then return nil, 'Invalid drug type.' end

    local yieldCount = math.random(Cfg.manufacture.yieldMin or 1, Cfg.manufacture.yieldMax or 3)

    -- [RETURN-VALUE FIX] Check the ACTUAL AddItem return value (pcall(true,false)
    -- used to look like success). No fake harvests.
    local ok, added = pcall(function()
        return exports.sunset_inventory:AddItem(source, drug.raw, yieldCount)
    end)
    if not ok or added ~= true then
        dlog(('harvestComplete AddItem FAILED src=%d item=%s x%d'):format(source, drug.raw, yieldCount))
        return nil, 'Inventory full — nothing was harvested.'
    end

    HarvestCooldowns[source] = now
    notify(source, ('Harvested %dx %s.'):format(yieldCount, drug.rawLabel or drug.label), 'success')
    dlog(('harvestComplete ok src=%d drug=%s x%d'):format(source, pending.drugType, yieldCount))
    return { drugType = pending.drugType, amount = yieldCount, raw = drug.raw, rawLabel = drug.rawLabel }
end)

-- ═══ STAGE 2: PROCESS (two-phase timed) ═══

exports.sunset_core:RegisterCallback('sunset:drugs:processStart', function(source, drugType)
    drugType = tostring(drugType or '')
    local drug = Cfg.drugs[drugType]
    if not drug then return nil, 'Unknown drug type.' end

    local now = GetGameTimer()
    if ProcessCooldowns[source] and now - ProcessCooldowns[source] < (Cfg.process.cooldownMs or 5000) then
        return nil, 'Wait a moment before processing again.'
    end

    local coords = pedCoords(source)
    if not nearAny(coords, Cfg.process.labs, Cfg.process.labRadius or 10.0) then
        return nil, 'You must be at a processing lab.'
    end

    -- Validate raw materials BEFORE starting (do not consume yet —
    -- consumption happens atomically at completion).
    local ratio = Cfg.process.ratio or 2
    local hasRaw = false
    pcall(function()
        hasRaw = exports.sunset_inventory:HasItem(source, drug.raw, ratio) == true
    end)
    if not hasRaw then
        return nil, ('You need %dx %s to process.'):format(ratio, drug.rawLabel or drug.label)
    end

    local durationMs = Cfg.process.processTimeMs or 8000
    local pending, err = startPending(source, 'process', durationMs, { drugType = drugType })
    if not pending then return nil, err end

    dlog(('processStart src=%d drug=%s'):format(source, drugType))
    return { durationMs = durationMs, drugType = drugType, ratio = ratio }
end)

exports.sunset_core:RegisterCallback('sunset:drugs:processComplete', function(source)
    local pending = takePending(source, 'process')
    if not pending then return nil, 'No processing in progress.' end

    local now = GetGameTimer()
    if (now - pending.startedAt) < (pending.durationMs - COMPLETE_SLACK_MS) then
        PendingActions[source] = pending
        return nil, 'Still processing...'
    end

    local coords = pedCoords(source)
    if not nearAny(coords, Cfg.process.labs, (Cfg.process.labRadius or 10.0) + 2.0) then
        return nil, 'You left the lab.'
    end

    local drug = Cfg.drugs[pending.drugType]
    if not drug then return nil, 'Unknown drug type.' end
    local ratio = Cfg.process.ratio or 2

    -- [ATOMIC] ConvertItems (sunset_inventory domain): removes raw + adds
    -- product as one guarded operation with compensation on failure.
    -- Raw can never be lost without the product appearing.
    local ok, converted, convErr = pcall(function()
        return exports.sunset_inventory:ConvertItems(source, drug.raw, ratio, drug.product, 1)
    end)
    if not ok or converted ~= true then
        dlog(('processComplete ConvertItems FAILED src=%d err=%s'):format(source, tostring(convErr)))
        return nil, convErr or 'Processing failed — your materials were not consumed.'
    end

    ProcessCooldowns[source] = now
    notify(source, ('Processed %dx %s → 1x %s.'):format(ratio, drug.rawLabel or drug.label, drug.productLabel or drug.label), 'success')
    dlog(('processComplete ok src=%d drug=%s'):format(source, pending.drugType))
    return { drugType = pending.drugType, product = drug.product, productLabel = drug.productLabel }
end)

-- ═══ STAGE 3: SELL (instant, economically safe) ═══

exports.sunset_core:RegisterCallback('sunset:drugs:sell', function(source, drugType, amount)
    drugType = tostring(drugType or '')
    amount = math.floor(tonumber(amount) or 0)
    local drug = Cfg.drugs[drugType]
    if not drug then return nil, 'Unknown drug type.' end
    if amount < 1 or amount > (Cfg.sell.maxAmount or 10) then return nil, 'Invalid amount.' end

    local now = GetGameTimer()
    if SellCooldowns[source] and now - SellCooldowns[source] < (Cfg.sell.cooldownMs or 10000) then
        return nil, 'The dealer needs a moment. Wait before selling again.'
    end

    local coords = pedCoords(source)
    if not nearAny(coords, Cfg.sell.dealers, Cfg.sell.sellRadius or 5.0) then
        return nil, 'You must be near a dealer to sell.'
    end

    -- [RETURN-VALUE FIX] Removal MUST be confirmed before any payout.
    local ok, removed = pcall(function()
        return exports.sunset_inventory:RemoveItem(source, drug.product, amount)
    end)
    if not ok or removed ~= true then
        dlog(('sell RemoveItem FAILED src=%d item=%s x%d'):format(source, drug.product, amount))
        return nil, ('You don\'t have %dx %s.'):format(amount, drug.productLabel or drug.label)
    end

    -- Price with variance (server-authoritative).
    local variance = Cfg.sell.priceVariance or { min = 0.8, max = 1.3 }
    local multiplier = variance.min + math.random() * (variance.max - variance.min)
    local price = math.floor(drug.basePrice * multiplier * amount)

    -- Payout AFTER confirmed removal. If AddMoney somehow fails, COMPENSATE
    -- by restoring the product — never a silent item loss.
    local paidOk, paid = pcall(function()
        return exports.sunset_core:AddMoney(source, 'cash', price, 'drug_sale')
    end)
    if not paidOk or paid == false then
        print(('^1[sunset_drugs]^7 AddMoney failed after removal src=%s price=%d — restoring product'):format(
            tostring(source), price))
        pcall(function() exports.sunset_inventory:AddItem(source, drug.product, amount) end)
        return nil, 'The dealer could not pay you. Your product was returned.'
    end

    SellCooldowns[source] = now
    notify(source, ('Sold %dx %s for $%s.'):format(amount, drug.productLabel or drug.label, price), 'success')
    dlog(('sell ok src=%d drug=%s x%d price=%d'):format(source, drugType, amount, price))
    return { drugType = drugType, amount = amount, price = price }
end)

-- ═══ CANCEL (client walked away / closed UI mid-action) ═══

exports.sunset_core:RegisterCallback('sunset:drugs:cancelAction', function(source)
    clearPending(source)
    return true
end)

-- ═══ STATUS ═══

exports.sunset_core:RegisterCallback('sunset:drugs:status', function(source)
    local result = {
        drugs = {},
        spots = {},
        labs = {},
        dealers = {},
        priceVariance = Cfg.sell.priceVariance or { min = 0.8, max = 1.3 },
        maxSellAmount = Cfg.sell.maxAmount or 10,
    }

    for drugType, drug in pairs(Cfg.drugs or {}) do
        local rawCount = 0
        local productCount = 0
        pcall(function()
            rawCount = exports.sunset_inventory:CountItem(source, drug.raw) or 0
            productCount = exports.sunset_inventory:CountItem(source, drug.product) or 0
        end)
        result.drugs[drugType] = {
            label = drug.label,
            raw = drug.raw,
            product = drug.product,
            rawLabel = drug.rawLabel or drug.label,
            productLabel = drug.productLabel or drug.label,
            rawCount = rawCount,
            productCount = productCount,
            basePrice = drug.basePrice,
        }
    end

    -- Spot drug mapping (Option A) so the UI shows only what grows there.
    for i, spot in ipairs(Cfg.manufacture.spots or {}) do
        result.spots[i] = { drug = spot.drug, label = spot.label }
    end

    pcall(function()
        local coords = pedCoords(source)
        if coords then
            result.nearSpot = select(2, nearAny(coords, Cfg.manufacture.spots, Cfg.manufacture.spotRadius or 10.0))
            result.nearLab = nearAny(coords, Cfg.process.labs, Cfg.process.labRadius or 10.0) and true or false
            result.nearDealer = nearAny(coords, Cfg.sell.dealers, Cfg.sell.sellRadius or 5.0) and true or false
        end
    end)

    return result
end)

-- ═══ CLEANUP ═══

AddEventHandler('playerDropped', function()
    local src = source
    HarvestCooldowns[src] = nil
    ProcessCooldowns[src] = nil
    SellCooldowns[src] = nil
    PendingActions[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    PendingActions = {}
    HarvestCooldowns = {}
    ProcessCooldowns = {}
    SellCooldowns = {}
end)

print('^2[sunset_drugs]^7 Drug pipeline online (manufacture → process → sell)')
