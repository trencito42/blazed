Sunset = Sunset or {}

local function vec3(v)
    if not v then return nil end
    if v.x then return vector3(v.x, v.y, v.z or 0.0) end
    return v
end

function Sunset.Taxi.BuildAllDestinations()
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

    for _, dest in ipairs(Sunset.Taxi.destinations or {}) do
        add(dest.id, dest.label, dest.coords, dest.category or 'Popular')
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

    for i, shop in ipairs(Sunset.ClothingShops or {}) do
        add('clothing_' .. i, 'Clothing Store #' .. i, shop, 'Shops')
    end

    for i, shop in ipairs(Sunset.BarberShops or {}) do
        add('barber_' .. i, 'Barber #' .. i, shop, 'Shops')
    end

    for id, center in pairs(Sunset.JobCenters or {}) do
        add('job_' .. id, center.label or 'Job Center', center.coords, 'Jobs')
    end

    for id, faction in pairs(Sunset.Factions or {}) do
        if faction.hq then
            add('hq_' .. id, (faction.label or id) .. ' HQ', faction.hq, 'Factions')
        end
    end

    for i, station in ipairs(Sunset.GasStations or {}) do
        add('gas_' .. i, station.label or ('Gas Station #' .. i), station.coords, 'Services')
    end

    if Sunset.Config and Sunset.Config.DefaultSpawn then
        add('spawn_default', 'Airport Spawn', Sunset.Config.DefaultSpawn, 'Popular')
    end
    if Sunset.Config and Sunset.Config.HospitalSpawn then
        add('hospital', 'Pillbox Hospital', Sunset.Config.HospitalSpawn, 'Popular')
    end

    table.sort(list, function(a, b)
        if a.category == b.category then return a.label < b.label end
        return a.category < b.category
    end)

    return list
end

function Sunset.Taxi.FindDestination(id)
    for _, dest in ipairs(Sunset.Taxi.BuildAllDestinations()) do
        if dest.id == id then return dest end
    end
end
