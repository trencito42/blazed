-- ============================================================
--  sunset_testdriver — DEV-ONLY diagnostics & tests
--  NOT ensured in production server.cfg. Console-only commands
--  (source == 0), no production authority, no player-facing API.
--
--  Commands:
--    integrity   — run invariant SQL checks (read-only)
--    sessiontest — unit-test the sunset_sessions state machine
--    smoke       — callback registry + rate-limit smoke checks
-- ============================================================

local PASS, FAIL = '^2PASS^7', '^1FAIL^7'
local results = {}

local function record(name, ok, detail)
    results[#results + 1] = { name = name, ok = ok, detail = detail }
    print(('  [%s] %s%s'):format(ok and PASS or FAIL, name, detail and (' — ' .. tostring(detail)) or ''))
end

-- ------------------------------------------------------------
-- 1. DB integrity checks (INVARIANTS.md, read-only)
-- ------------------------------------------------------------
local function integrityChecks()
    print('^3[testdriver] DB integrity checks^7')

    -- M1: no negative balances
    local neg = MySQL.scalar.await(
        'SELECT COUNT(*) FROM characters WHERE cash < 0 OR bank < 0')
    record('M1 no negative balances', (tonumber(neg) or 0) == 0, neg .. ' rows')

    -- V1: no duplicate plates among owned vehicles
    local dupPlates = MySQL.scalar.await([[
        SELECT COUNT(*) FROM (
            SELECT REPLACE(UPPER(plate),' ','') AS p FROM vehicles
            GROUP BY p HAVING COUNT(*) > 1
        ) t]])
    record('V1 unique plates', (tonumber(dupPlates) or 0) == 0, dupPlates .. ' dup groups')

    -- I2: no duplicate (character_id, slot) in inventory
    local dupSlots = MySQL.scalar.await([[
        SELECT COUNT(*) FROM (
            SELECT character_id, slot FROM character_inventory
            GROUP BY character_id, slot HAVING COUNT(*) > 1
        ) t]])
    record('I2 unique inventory slots', (tonumber(dupSlots) or 0) == 0, dupSlots .. ' dup groups')

    -- I3: no duplicate container rows
    local dupContainers = MySQL.scalar.await([[
        SELECT COUNT(*) FROM (
            SELECT container_type, container_id, item FROM container_inventory
            GROUP BY container_type, container_id, item HAVING COUNT(*) > 1
        ) t]])
    record('I3 unique container items', (tonumber(dupContainers) or 0) == 0, dupContainers .. ' dup groups')

    -- C6: no orphaned ownership refs (should be impossible post-sql/42 FKs,
    -- but verify anyway in case FKs were dropped)
    local orphanProps = MySQL.scalar.await([[
        SELECT COUNT(*) FROM properties p
        LEFT JOIN characters c ON c.id = p.owner_character_id
        WHERE p.owner_character_id IS NOT NULL AND c.id IS NULL]])
    record('C6 no orphan property owners', (tonumber(orphanProps) or 0) == 0, orphanProps .. ' rows')

    local orphanBiz = MySQL.scalar.await([[
        SELECT COUNT(*) FROM player_businesses b
        LEFT JOIN characters c ON c.id = b.owner_character_id
        WHERE b.owner_character_id IS NOT NULL AND c.id IS NULL]])
    record('C6 no orphan business owners', (tonumber(orphanBiz) or 0) == 0, orphanBiz .. ' rows')

    local orphanTurfs = MySQL.scalar.await([[
        SELECT COUNT(*) FROM turfs t
        LEFT JOIN clans cl ON cl.id = t.owner_clan_id
        WHERE t.owner_clan_id IS NOT NULL AND cl.id IS NULL]])
    record('C6 no orphan turf clans', (tonumber(orphanTurfs) or 0) == 0, orphanTurfs .. ' rows')

    -- I1-proxy: no zero/negative-count inventory rows
    local badCounts = MySQL.scalar.await(
        'SELECT COUNT(*) FROM character_inventory WHERE count <= 0')
    record('I1 no zero-count inventory rows', (tonumber(badCounts) or 0) == 0, badCounts .. ' rows')

    -- M5: no duplicate payday runs per period
    local dupPaydays = MySQL.scalar.await([[
        SELECT COUNT(*) FROM (
            SELECT character_id, period_key FROM payday_runs
            GROUP BY character_id, period_key HAVING COUNT(*) > 1
        ) t]])
    record('M5 unique payday runs', (tonumber(dupPaydays) or 0) == 0, dupPaydays .. ' dup groups')

    -- M2-proxy: ledger sanity — no rows with amount <= 0
    local badLedger = MySQL.scalar.await(
        'SELECT COUNT(*) FROM money_transactions WHERE amount <= 0')
    record('M2 ledger amounts positive', (tonumber(badLedger) or 0) == 0, badLedger .. ' rows')

    -- V5: destroyed vehicles must not be stored=0 spawnable with healthy engine
    local zombieVeh = MySQL.scalar.await([[
        SELECT COUNT(*) FROM vehicles
        WHERE destroyed = 1 AND engine > 0]])
    record('V5 destroyed vehicles have dead engine', (tonumber(zombieVeh) or 0) == 0, zombieVeh .. ' rows')
end

-- ------------------------------------------------------------
-- 2. Session framework unit tests (sunset_sessions, no players needed)
-- ------------------------------------------------------------
local function sessionTests()
    print('^3[testdriver] sunset_sessions unit tests^7')
    if GetResourceState('sunset_sessions') ~= 'started' then
        record('sessions resource started', false, 'sunset_sessions not running')
        return
    end

    local testActivity = 'td_test_' .. tostring(os.time())
    local endedStates = {}
    local endedEventName = 'td_test_ended_' .. tostring(os.time())
    AddEventHandler(endedEventName, function(session, state)
        endedStates[#endedStates + 1] = state
    end)
    -- Functions cannot cross the export boundary; register via event name.
    local ok = exports.sunset_sessions:RegisterActivity(testActivity, {
        reconnect = 'ABANDON',
        onEndEvent = endedEventName,
    })
    record('RegisterActivity accepts valid def', ok == true)

    local rejected = exports.sunset_sessions:RegisterActivity('td_bad', {})
    record('RegisterActivity rejects def without cleanup', rejected == false)

    -- fake source (999999 is not a connected player; framework must tolerate)
    local session, err = exports.sunset_sessions:CreateSession({
        source = 999999, charId = 999999, activity = testActivity, timeoutSec = 60,
    })
    record('CreateSession', session ~= nil, err)
    if not session then return end

    record('initial state STARTING', session.state == 'STARTING')

    local t1 = exports.sunset_sessions:Transition(session.id, 'ACTIVE')
    record('STARTING->ACTIVE', t1 == true)

    -- reward idempotency
    local m1 = exports.sunset_sessions:MarkRewardPending(session.id)
    local m2 = exports.sunset_sessions:MarkRewardPending(session.id)
    record('MarkRewardPending once', m1 == true and m2 == false)
    exports.sunset_sessions:CommitReward(session.id)
    local m3 = exports.sunset_sessions:MarkRewardPending(session.id)
    record('reward cannot re-arm after commit', m3 == false)

    -- duplicate create for same char refused
    local dup, dupErr = exports.sunset_sessions:CreateSession({
        source = 999998, charId = 999999, activity = testActivity,
    })
    record('duplicate session refused', dup == nil, dupErr)

    -- terminal transition
    local t2 = exports.sunset_sessions:Transition(session.id, 'COMPLETED', 'test')
    record('ACTIVE->COMPLETED', t2 == true)
    record('onEnd cleanup ran once', #endedStates == 1, 'states: ' .. table.concat(endedStates, ','))

    -- terminal absorbing
    local t3 = exports.sunset_sessions:Transition(session.id, 'ACTIVE')
    record('terminal state absorbing', t3 == false)

    -- cancel after end is a no-op returning false (idempotent)
    local t4 = exports.sunset_sessions:CancelSession(session.id)
    record('cancel after end rejected', t4 == false)

    -- invalid state name
    local session2 = exports.sunset_sessions:CreateSession({
        source = 999997, charId = 999997, activity = testActivity, timeoutSec = 60,
    })
    if session2 then
        local t5 = exports.sunset_sessions:Transition(session2.id, 'BOGUS')
        record('invalid state rejected', t5 == false)
        exports.sunset_sessions:CancelSession(session2.id, 'test done')
        record('cancel works', #endedStates == 2)
    end

    record('GetSessionBySource nil for offline', exports.sunset_sessions:GetSessionBySource(999999) == nil)
end

-- ------------------------------------------------------------
-- 3. Smoke checks: registry, limits, resources
-- ------------------------------------------------------------
local function smokeChecks()
    print('^3[testdriver] smoke checks^7')

    -- required resources up
    for _, res in ipairs({ 'oxmysql', 'sunset_core', 'sunset_ui', 'sunset_sessions',
                           'sunset_inventory', 'sunset_economy', 'sunset_jobs',
                           'sunset_factions', 'sunset_vehicles', 'sunset_admin' }) do
        record('resource started: ' .. res, GetResourceState(res) == 'started', GetResourceState(res))
    end

    -- core exports exist
    local coreExports = { 'GetCharacter', 'AddMoney', 'RemoveMoney', 'GetMoney',
        'TransferMoney', 'RefreshMoney', 'LogMoneyTransaction', 'IsIncapacitated',
        'RegisterCallback', 'SaveCharacter', 'RateLimit' }
    for _, name in ipairs(coreExports) do
        local okCall, res = pcall(function()
            local fn = exports.sunset_core[name]
            return fn ~= nil
        end)
        record('core export: ' .. name, okCall == true and res == true)
    end

    -- RateLimit behaves (same key twice within window)
    local rl1 = exports.sunset_core.RateLimit(999990, 'td_smoke', 1000)
    local rl2 = exports.sunset_core.RateLimit(999990, 'td_smoke', 1000)
    record('RateLimit first passes', rl1 == true)
    record('RateLimit second throttled', rl2 == false)

    -- money API rejects nonsense for offline source (no side effects)
    local bad = exports.sunset_core.AddMoney(999991, 'cash', 100, 'td_should_fail')
    record('AddMoney offline source rejected', bad == false or bad == nil, tostring(bad))
    local neg = exports.sunset_core.RemoveMoney(999991, 'cash', -500, 'td_neg')
    record('RemoveMoney negative rejected', neg == false or neg == nil, tostring(neg))
end

-- ------------------------------------------------------------
-- Runner (console-only)
-- ------------------------------------------------------------
local function runAll(which)
    results = {}
    local t0 = os.clock()
    local ok, err = pcall(function()
        if which == 'integrity' then integrityChecks()
        elseif which == 'sessiontest' then sessionTests()
        elseif which == 'smoke' then smokeChecks()
        else
            integrityChecks()
            sessionTests()
            smokeChecks()
        end
    end)
    if not ok then
        print(('^1[testdriver] harness error: %s^7'):format(tostring(err)))
    end
    local failed = 0
    for _, r in ipairs(results) do if not r.ok then failed = failed + 1 end end
    print(('^3[testdriver]^7 %s: %d checks, %d failed (%.2fs)'):format(
        which or 'all', #results, failed, os.clock() - t0))
    return failed
end

RegisterCommand('integrity', function(source)
    if source ~= 0 then return end
    runAll('integrity')
end, true)

RegisterCommand('sessiontest', function(source)
    if source ~= 0 then return end
    runAll('sessiontest')
end, true)

RegisterCommand('smoketest', function(source)
    if source ~= 0 then return end
    runAll('smoke')
end, true)

RegisterCommand('testall', function(source)
    if source ~= 0 then return end
    runAll('all')
end, true)

print('^3[sunset_testdriver]^7 loaded (DEV-ONLY). Console commands: integrity | sessiontest | smoketest | testall')

-- Auto-run once after startup when the convar is set (used by CI/remote runs
-- where console stdin injection is unavailable):
--   +setr testdriver_autorun 1
if GetConvar('testdriver_autorun', '') == '1' then
    CreateThread(function()
        Wait(30000)
        runAll('all')
    end)
end
