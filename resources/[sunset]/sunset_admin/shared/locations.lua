SunsetAdmin = SunsetAdmin or {}

local function vec3(v)
    if not v then return nil end
    if v.x then return vector3(v.x, v.y, v.z or 0.0) end
    return v
end

--- Hardcoded world locations (HQs, shops, garages, etc.) for /gotoloc only.
function SunsetAdmin.BuildLocations()
    local list = {}
    local seen = {}

    local function add(id, label, coords, category)
        coords = vec3(coords)
        if not coords then return end
        id = id or ('loc_' .. #list + 1)
        if seen[id] then return end
        seen[id] = true
        list[#list + 1] = {
            id = id,
            label = label,
            coords = coords,
            category = category or 'Other',
        }
    end

    for id, faction in pairs(Sunset.Factions or {}) do
        if faction.hq then
            add('hq_' .. id, (faction.label or id) .. ' HQ', faction.hq, 'Factions')
        end
        if faction.depot and faction.depot.coords then
            add('depot_' .. id, (faction.depot.label or faction.label or id) .. ' Depot', faction.depot.coords, 'Factions')
        end
        if faction.stash then
            add('stash_' .. id, (faction.label or id) .. ' Stash', faction.stash, 'Factions')
        end
    end

    for id, station in pairs(Sunset.CraftingStations or {}) do
        add('craft_' .. id, station.label or id, station.coords, 'Crafting')
    end

    for id, shop in pairs(Sunset.Shops or {}) do
        add('shop_' .. id, shop.label or id, shop.coords, 'Shops')
    end

    for id, garage in pairs(Sunset.Garages or {}) do
        add('garage_' .. id, garage.label or id, garage.store or garage.spawn, 'Garages')
    end

    for i, atm in ipairs(Sunset.ATMs or {}) do
        add('atm_' .. i, 'ATM #' .. i, atm, 'Services')
    end

    for id, center in pairs(Sunset.JobCenters or {}) do
        add('job_' .. id, center.label or 'Job Center', center.coords, 'Jobs')
    end

    for jobId, cfg in pairs(Sunset.JobsConfig or {}) do
        if cfg.depot and cfg.depot.coords then
            add(jobId .. '_depot', (cfg.label or jobId) .. ' Depot', cfg.depot.coords, 'Jobs')
        end
        if cfg.warehouse and cfg.warehouse.coords then
            add(jobId .. '_warehouse', (cfg.label or jobId) .. ' Warehouse', cfg.warehouse.coords, 'Jobs')
        end
        if cfg.sellPoint and cfg.sellPoint.coords then
            add(jobId .. '_sell', cfg.sellPoint.label or (cfg.label or jobId) .. ' Sell', cfg.sellPoint.coords, 'Jobs')
        end
    end

    if Sunset.Config then
        if Sunset.Config.DefaultSpawn then
            add('spawn', 'Default Spawn', Sunset.Config.DefaultSpawn, 'Popular')
        end
        if Sunset.Config.HospitalSpawn then
            add('hospital', 'Pillbox Hospital', Sunset.Config.HospitalSpawn, 'Popular')
        end
    end

    table.sort(list, function(a, b)
        if a.category == b.category then return a.label < b.label end
        return a.category < b.category
    end)

    return list
end

function SunsetAdmin.FindLocation(query)
    if not query or query == '' then return nil end
    query = string.lower(query)

    local exact
    for _, loc in ipairs(SunsetAdmin.BuildLocations()) do
        if string.lower(loc.id) == query then
            return loc
        end
        if not exact and string.find(string.lower(loc.label), query, 1, true) then
            exact = loc
        end
    end
    return exact
end
