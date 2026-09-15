-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Test Agent (server/domains.lua)
--  Domain-specific test adapters. Each adapter READS through the
--  domain owner's exports/callbacks — no business logic here, no
--  duplicated state. New domains register with
--  TestAgentTools.registerDomain(name, spec).
-- ═══════════════════════════════════════════════════════════════

local E = SunsetTestAgent.Errors

local function invalid(msg)
    return { code = 'INVALID_ARGUMENT', message = msg, retryable = false }
end

local function requireResource(name)
    if GetResourceState(name) ~= 'started' then
        return nil, { code = 'RESOURCE_NOT_STARTED', message = (name .. ' is not started'), retryable = true }
    end
    return true
end

-- ── Robbery ──
-- Live session state is owned by sunset_robbery; we expose read-only views
-- through its own globals/exports where they exist, plus the DB ledger for
-- completed runs (already exposed via core tools).
TestAgentTools.registerDomain('get_robbery_state', {
    fn = function(target)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        local ok = requireResource('sunset_robbery')
        if not ok then return nil, err end
        -- RobberySessions is a global in the sunset_robbery server context,
        -- NOT visible cross-resource (per-resource Lua environments). Use the
        -- exported snapshot instead (added for the test agent).
        local live = nil
        pcall(function()
            live = exports.sunset_robbery:GetTestSnapshot(src)
        end)
        return {
            live = live,
            doorState = (function()
                local d = nil
                pcall(function() d = exports.sunset_robbery:GetDoorSnapshot() end)
                return d
            end)(),
        }
    end,
    target = true,
})

-- ── Racing ──
TestAgentTools.registerDomain('get_race_state', {
    fn = function(target)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        local ok = requireResource('sunset_racing')
        if not ok then return nil, err end
        local raceNightActive = nil
        pcall(function() raceNightActive = exports.sunset_racing:IsRaceNightActive() == true end)
        local points = nil
        local char = exports.sunset_core:GetCharacter(src)
        if char and tonumber(char.id) then
            pcall(function() points = exports.sunset_racing:GetRaceNightPoints(tonumber(char.id)) end)
        end
        local snapshot = nil
        pcall(function() snapshot = exports.sunset_racing:GetTestSnapshot(src) end)
        return {
            raceNightActive = raceNightActive,
            raceNightPoints = points,
            session = snapshot,
        }
    end,
    target = true,
})

-- ── Jobs (civilian work sessions) ──
TestAgentTools.registerDomain('get_job_state', {
    fn = function(target)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        local jobSession = nil
        if GetResourceState('sunset_jobs') == 'started' then
            local ok, res = pcall(function() return exports.sunset_jobs:GetSessionSnapshot(src) end)
            if ok and type(res) == 'table' then jobSession = res end
        end
        local char = exports.sunset_core:GetCharacter(src)
        local jobId = char and select(1, Sunset.GetCharacterJob(char)) or nil
        local level = nil
        if jobId and GetResourceState('sunset_jobs') == 'started' then
            pcall(function() level = exports.sunset_jobs:GetJobLevel(src, jobId) end)
        end
        return { jobId = jobId, level = level, session = jobSession }
    end,
    target = true,
})

-- ── Wanted / police ──
TestAgentTools.registerDomain('get_wanted_state', {
    fn = function(target)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        local ok = requireResource('sunset_factions')
        if not ok then return nil, err end
        local wanted = nil
        pcall(function() wanted = exports.sunset_factions:GetWantedState(src) end)
        local jailed = nil
        pcall(function() jailed = exports.sunset_factions:IsJailed(src) == true end)
        return { wanted = wanted, jailed = jailed }
    end,
    target = true,
})

-- ── Vehicle ownership ──
TestAgentTools.registerDomain('get_vehicle_ownership_state', {
    fn = function(target)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        local char = exports.sunset_core:GetCharacter(src)
        if not char or not tonumber(char.id) then return nil, E.TEST_PLAYER_NOT_CONNECTED end
        local ok, rows = pcall(function()
            return MySQL.query.await(
                'SELECT id, model, plate, garage, parked_x, parked_y, parked_z FROM vehicles WHERE owner_id = ? LIMIT 25',
                { tonumber(char.id) })
        end)
        if not ok then return nil, E.INTERNAL end
        return { vehicles = rows or {} }
    end,
    target = true,
})

-- ── Clan ──
TestAgentTools.registerDomain('get_clan_state', {
    fn = function(target)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        local char = exports.sunset_core:GetCharacter(src)
        if not char or not tonumber(char.id) then return nil, E.TEST_PLAYER_NOT_CONNECTED end
        local ok, row = pcall(function()
            return MySQL.single.await(
                'SELECT clan_id FROM characters WHERE id = ?', { tonumber(char.id) })
        end)
        if not ok then return nil, E.INTERNAL end
        return { clanId = row and row.clan_id or nil }
    end,
    target = true,
})

-- ── House / properties ──
TestAgentTools.registerDomain('get_house_state', {
    fn = function(target, args)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        args = type(args) == 'table' and args or {}
        local char = exports.sunset_core:GetCharacter(src)
        if not char or not tonumber(char.id) then return nil, E.TEST_PLAYER_NOT_CONNECTED end
        local houseId = tonumber(args.houseId)
        local ok, rows
        if houseId then
            ok, rows = pcall(function()
                return MySQL.query.await('SELECT * FROM properties WHERE id = ? LIMIT 1', { houseId })
            end)
        else
            ok, rows = pcall(function()
                return MySQL.query.await('SELECT id, label, owner_id FROM properties WHERE owner_id = ? LIMIT 10',
                    { tonumber(char.id) })
            end)
        end
        if not ok then return nil, invalid('properties table not readable (schema?)') end
        return { houses = rows or {} }
    end,
    target = true,
    args = true,
})

-- ── Drug pipeline ──
TestAgentTools.registerDomain('get_drug_pipeline_state', {
    fn = function(target)
        local src, err = TestAgentAuth.resolveTarget(target)
        if not src then return nil, err end
        -- Inventory counts via the domain owner; no drug-specific SQL here.
        if GetResourceState('sunset_inventory') ~= 'started' then
            return nil, { code = 'RESOURCE_NOT_STARTED', message = 'sunset_inventory not started', retryable = true }
        end
        local items = {}
        local names = { 'weed_leaf', 'weed_brick', 'coke_leaf', 'coke_brick', 'meth_chemical', 'meth_bag' }
        for _, item in ipairs(names) do
            local ok, count = pcall(function() return exports.sunset_inventory:CountItem(src, item) end)
            items[item] = ok and (tonumber(count) or 0) or 0
        end
        return { items = items }
    end,
    target = true,
})
