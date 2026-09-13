-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Blaze Shield (server/ledger.lua)
--  Phase-2 ledger detectors (ANTICHEAT_SPEC §4.6/§4.7/§4.8/§4.9):
--    economy_check        §4.9  money_transactions reason whitelist
--    weapon_check         §4.6  client weapon list vs inventory ledger
--    ammo_check           §4.7  ammo vs owned boxes (generous floor)
--    vehicle_spawn_check  §4.8  entityCreated without MarkLegit window
--  Server-authoritative accounting: a client cannot forge these rows.
--  NEVER auto-bans (AutoBanAnything=false is hard-guarded in main.lua).
--  The economy detector auto-KICKS only when Cfg.AutoKickOnEconomyInjection.
-- ═══════════════════════════════════════════════════════════════

Anticheat = Anticheat or {}

local Ledger = {}
Anticheat.Ledger = Ledger

local Cfg = SunsetAnticheat.Config
local Strikes = Anticheat.Strikes
local Context = Anticheat.Context

local function playerName(src)
    local name = nil
    if GetResourceState('sunset_core') == 'started' then
        pcall(function() name = exports.sunset_core:GetPlayerDisplayName(src) end)
    end
    return name or GetPlayerName(src) or ('#%d'):format(src)
end

local function detCfg(key) return Cfg.Detectors[key] or {} end

-- ── Cooldowns (AddTick has none; ledger detectors need their own) ──
local LedgerCooldown = {} -- [src] = { [detector] = readyAt }

local function onLedgerCooldown(src, detector)
    local entry = LedgerCooldown[src]
    return entry and entry[detector] and os.time() < entry[detector] or false
end

local function setLedgerCooldown(src, detector)
    local cd = tonumber(detCfg(detector == 'weapon_check' and 'weapon'
        or detector == 'ammo_check' and 'ammo'
        or detector == 'vehicle_spawn_check' and 'vehspawn' or detector).cooldown) or 300
    LedgerCooldown[src] = LedgerCooldown[src] or {}
    LedgerCooldown[src][detector] = os.time() + cd
end

local function ledgerFire(src, detector, severity, measured)
    if onLedgerCooldown(src, detector) then return end
    setLedgerCooldown(src, detector)
    Strikes.AddTick(src, detector, severity, measured, Context.Snapshot(src))
end

-- ══════════════ §4.9 economy_check ══════════════
-- Every balance change on the server flows through sunset_core AddMoney /
-- RemoveMoney / MoveMoney / TransferMoney → money_transactions with a reason
-- string. A client cannot insert money; if an 'in' row appears with a reason
-- NOT in the whitelist below, it came from a compromised/injected code path.
-- Whitelist enumerated from the whole codebase 2025 (grep AddMoney/
-- RemoveMoney/LogMoneyTransaction/TransferMoney/MoveMoney). Direct-DB writes
-- (lottery draws, /setcash) never create rows and are not scanned.
local ECON_REASON_WHITELIST = {
    -- jobs & activities (dynamic 'job_<id>' covered by prefix below)
    carjack_sale = true, fire_incident = true,
    fish_sell_247 = true, fish_sell_legacy = true,
    -- dice / gambling
    dice_win = true, dice_refund = true,
    -- commerce refunds
    appearance_refund = true, shop_refund = true, business_withdraw = true,
    license_exam_refund = true,
    -- taxi
    taxi_fare = true, taxi_ride = true, taxi_ride_retry = true, taxi_tip = true,
    -- criminal economy
    illegal_sale = true, fence_sale = true, fence = true,
    -- police
    arrest_bounty = true,
    -- player economy
    player_transfer = true, player_transfer_rollback = true, player_trade = true,
    bank_transfer = true, atm_deposit = true,
    -- systems
    sunset_pass = true, turf_payout = true,
    house_rent_income = true, house_sale = true,
    -- tuning refunds
    ['Dyno cancelled refund'] = true, ['Dyno error refund'] = true,
    -- testdriver (fake src, guarded by core anyway)
    td_should_fail = true, td_neg = true,
}

-- Prefix whitelist for dynamic reasons ('job_<id>', 'quest_<key>', ...).
local ECON_REASON_PREFIXES = {
    'job_', 'quest_',
}

local function reasonWhitelisted(reason)
    reason = tostring(reason or '')
    if ECON_REASON_WHITELIST[reason] then return true end
    for _, prefix in ipairs(ECON_REASON_PREFIXES) do
        if reason:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local LastEconScanId = nil
local economyScanCounter = 0

local function sourceForCharacterId(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            local cid = nil
            pcall(function()
                local char = exports.sunset_core:GetCharacter(src)
                cid = char and tonumber(char.id) or nil
            end)
            if cid == charId then return src end
        end
    end
    return nil
end

local function flagEconomy(src, charId, row)
    -- [FLAG] anticheat_flags row with full evidence (spec §4.9).
    local kickNow = Cfg.AutoKickOnEconomyInjection == true and Cfg.Mode ~= 'log_only'
    local accountId = nil
    pcall(function()
        local player = exports.sunset_core:GetPlayer(src or 0)
        accountId = player and tonumber(player.account_id) or nil
    end)
    local evidence = json.encode({
        transaction = row,
        reason = row.reason,
        amount = row.amount,
        account = row.account,
        balance_after = row.balance_after,
        scanned_at = os.date('%Y-%m-%d %H:%M:%S'),
    }) or '{}'
    pcall(function()
        MySQL.insert.await(
            'INSERT INTO anticheat_flags (account_id, player_name, flag_type, evidence, action_taken) VALUES (?, ?, ?, ?, ?)',
            { accountId, (playerName(src or 0)):sub(1, 64), 'economy_injection', evidence,
              kickNow and 'auto_kick' or 'none' })
    end)

    -- [ROLLOUT SAFETY] During log_only mode the whitelist may still be
    -- incomplete — never auto-kick until the owner flips Mode='enforce'.

    Strikes.BroadcastStaff(('^1[SHIELD ECONOMY]^7 %s (#%s) — suspicious money: %s +$%d (reason "%s" not in ledger whitelist). Evidence in anticheat_flags.%s'):format(
        playerName(src or 0), tostring(src or charId), tostring(row.account), tonumber(row.amount) or 0, tostring(row.reason),
        kickNow and ' AUTO-KICKED.' or ' (log_only: flag only)'), 'warning')

    if Anticheat.Discord then
        pcall(Anticheat.Discord.EconomyInjection, src or 0, playerName(src or 0),
            ('+$%s to %s with unknown reason "%s"'):format(tostring(row.amount), tostring(row.account), tostring(row.reason)),
            kickNow)
    end

    if kickNow and src and GetPlayerName(src) then
        DropPlayer(src, 'Disconnected: economy anomaly detected. Contact staff if this was a mistake.')
    end
end

-- Scan new money_transactions rows every 60 s (id-cursor; no full-table scan).
CreateThread(function()
    Wait(15000)
    -- Seed the cursor so pre-existing history never re-fires.
    pcall(function()
        LastEconScanId = tonumber(MySQL.scalar.await('SELECT MAX(id) FROM money_transactions')) or 0
    end)
    while Cfg.Enabled do
        Wait(60000)
        if detCfg('economy').enabled ~= false and LastEconScanId then
            local ok, err = pcall(function()
                local rows = MySQL.query.await(
                    "SELECT id, character_id, account, direction, amount, reason, balance_after FROM money_transactions WHERE id > ? AND direction = 'in' ORDER BY id ASC LIMIT 200",
                    { LastEconScanId }) or {}
                for _, row in ipairs(rows) do
                    LastEconScanId = math.max(LastEconScanId, tonumber(row.id) or 0)
                    if not reasonWhitelisted(row.reason) then
                        local src = sourceForCharacterId(row.character_id)
                        -- Admins doing /setstat are whitelisted by context too.
                        if not (src and Context.IsLegit(src, 'economy')) then
                            flagEconomy(src, row.character_id, row)
                        end
                    end
                end
            end)
            if not ok then print(('[sunset_anticheat] economy scan error: %s'):format(tostring(err))) end
        end
        economyScanCounter = economyScanCounter + 1
    end
end)

-- ══════════════ §4.6/§4.7 weapon + ammo ledger ══════════════
-- Client sampler reports its full weapon list + per-weapon ammo every 5 s
-- (payload.weapons = { { hash, ammo }, ... }). Server ledger = inventory
-- weapon items + MarkLegit windows + context (war/duty/loadout).
local LastWeaponReport = {}   -- [src] = { list, at }
local WeaponGrace = {}        -- [src] = { [hash] = firstSeenAt }
local RecentWeaponFlags = {}  -- [src] = { at } for the 10-min escalation

-- Inventory weapon hashes for a source (server-authoritative).
local function inventoryWeaponHashes(src)
    local hashes = {}
    if GetResourceState('sunset_inventory') ~= 'started' then return hashes, 0 end
    local ok, inv = pcall(function() return exports.sunset_inventory:GetInventory(src) end)
    if not ok or type(inv) ~= 'table' then return hashes, 0 end
    local ammoRounds = 0
    for _, row in ipairs(inv) do
        local def = Sunset.Items[row.item]
        if def and def.weapon then
            hashes[joaat(def.weapon)] = true
        end
        if def and def.ammoRounds then
            ammoRounds = ammoRounds + (tonumber(def.ammoRounds) or 0) * (tonumber(row.count) or 0)
        end
    end
    return hashes, ammoRounds
end

-- Melee/utility gadget hashes are EXEMPT from the weapon ledger (spec §4.6
-- targets firearms; melee items are inventory-tracked but systems like
-- sunset_fire hand out extinguishers directly — zero-value FP source).
local EXEMPT_WEAPON_HASHES = {}
for _, name in ipairs({
    'WEAPON_UNARMED', 'WEAPON_KNIFE', 'WEAPON_SWITCHBLADE', 'WEAPON_BAT',
    'WEAPON_CROWBAR', 'WEAPON_FLASHLIGHT', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER',
    'WEAPON_GOLFCLUB', 'WEAPON_BOTTLE', 'WEAPON_DAGGER', 'WEAPON_HATCHET',
    'WEAPON_KNUCKLE', 'WEAPON_MACHETE', 'WEAPON_WRENCH', 'WEAPON_POOLCUE',
    'WEAPON_STONE_HATCHET', 'WEAPON_FIREEXTINGUISHER', 'WEAPON_PETROLCAN',
    'WEAPON_HAZARDCAN', 'WEAPON_FERTILIZERCAN', 'WEAPON_BALL', 'WEAPON_SNOWBALL',
    'GADGET_PARACHUTE', 'WEAPON_STUNGUN', 'WEAPON_DOUBLEACTION',
}) do EXEMPT_WEAPON_HASHES[joaat(name)] = true end

function Ledger.OnWeaponReport(src, weapons)
    if not Cfg.Enabled or detCfg('weapon').enabled == false then return end
    if type(weapons) ~= 'table' then return end
    LastWeaponReport[src] = { list = weapons, at = os.time() }

    -- Context exemptions first (war, duty, admin action, MarkLegit window).
    if Context.IsLegit(src, 'weapons') then
        WeaponGrace[src] = nil
        return
    end

    local ledger = inventoryWeaponHashes(src)
    local grace = WeaponGrace[src] or {}
    WeaponGrace[src] = grace
    local now = os.time()

    for _, w in ipairs(weapons) do
        local hash = tonumber(w.hash)
        if hash and not ledger[hash] and not EXEMPT_WEAPON_HASHES[hash] then
            if not grace[hash] then
                grace[hash] = now -- 10 s inventory-sync grace (spec §4.6)
            elseif now - grace[hash] >= 10 then
                grace[hash] = nil
                local escalation = RecentWeaponFlags[src] and (now - RecentWeaponFlags[src].at) < 600
                RecentWeaponFlags[src] = { at = now }
                local severity = escalation and 3 or 1
                ledgerFire(src, 'weapon_check', severity,
                    ('unledgered weapon hash %s (ammo %s)%s'):format(
                        tostring(hash), tostring(w.ammo or '?'),
                        escalation and ' — SECOND unledgered weapon within 10 min' or ' — first flag, verify inventory sync'))
            end
        else
            grace[hash] = nil
        end
    end
end

function Ledger.OnAmmoReport(src, weaponHash, ammo)
    if not Cfg.Enabled or detCfg('ammo').enabled == false then return end
    ammo = tonumber(ammo) or 0
    if ammo <= 0 then return end
    if Context.IsLegit(src, 'ammo') then return end

    -- Generous floor (spec §4.7): owned_boxes × 24 + 300.
    local _, ammoRounds = inventoryWeaponHashes(src)
    local cap = (ammoRounds > 0 and ammoRounds or 0) * 1 + 300
    if ammo > cap then
        ledgerFire(src, 'ammo_check', 2,
            ('ammo %d on weapon %s exceeds ledger cap %d (boxes≈%d + 300 floor)'):format(
                ammo, tostring(weaponHash), cap, ammoRounds))
    end
end

-- ══════════════ §4.8 vehicle_spawn_check ══════════════
-- All legit spawn paths funnel through our resources; each spawn point calls
-- exports.sunset_anticheat:MarkLegitLocal('vehicle_spawn') client-side (which
-- relays to server MarkLegit) BEFORE CreateVehicle. entityCreated without a
-- matching window = spawned by an external trainer/injector.
local function findVehicleOwner(veh)
    local owner = NetworkGetEntityOwner(veh)
    if owner and owner ~= -1 then return owner end
    return nil
end

AddEventHandler('entityCreated', function(entity)
    if not Cfg.Enabled or detCfg('vehspawn').enabled == false then return end
    if not entity or entity == 0 then return end
    local ok, err = pcall(function()
        if GetEntityType(entity) ~= 2 then return end -- vehicles only
        -- Ambient traffic (population 0-5) is never player-created.
        local okPop, pop = pcall(GetEntityPopulationType, entity)
        if okPop and pop ~= nil and pop < 6 then return end
        local src = findVehicleOwner(entity)
        if not src then return end
        if Context.IsLegit(src, 'vehicle_spawn') then return end
        local okModel, model = pcall(GetEntityModel, entity)
        if not okModel then model = '?' end
        ledgerFire(src, 'vehicle_spawn_check', 3,
            ('vehicle entity %s (model %s) created with no server-side spawn source'):format(
                tostring(entity), tostring(model)))
    end)
    if not ok then print(('[sunset_anticheat] vehspawn hook error: %s'):format(tostring(err))) end
end)

-- Client relay: MarkLegitLocal from any resource's client script.
RegisterNetEvent('sunset:anticheat:markLegitLocal', function(checkType, seconds)
    local src = source
    checkType = tostring(checkType or 'all')
    -- Only trust calls that name a real check type; cap the window at 30 s.
    seconds = math.min(30, math.max(1, tonumber(seconds) or 10))
    Context.MarkLegit(src, checkType, seconds)
end)

AddEventHandler('playerDropped', function()
    local src = source
    LastWeaponReport[src] = nil
    WeaponGrace[src] = nil
    RecentWeaponFlags[src] = nil
    LedgerCooldown[src] = nil
end)

print('^5[sunset_anticheat]^7 ledger detectors online (economy scan 60s, weapon/ammo reports, entityCreated vehspawn)')
