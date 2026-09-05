local activeZone = nil
local propertyZones = {}
local propertyBlips = {}

local function hasOx()
    return GetResourceState('ox_lib') == 'started'
end

local function showHint(text)
    if hasOx() then
        exports.ox_lib:showTextUI(text, { position = 'bottom-center' })
    end
end

local function hideHint()
    if hasOx() then
        exports.ox_lib:hideTextUI()
    end
end

local MARKER_DRAW_DIST = 75.0

local function drawPropertyLabel(prop, distance)
    local priceLine
    if prop.ownerName then
        priceLine = ('Owned by %s'):format(prop.ownerName)
    elseif prop.forSale then
        priceLine = ('For sale: $%s  |  Level %d'):format(prop.price or 0, prop.minimumLevel or 1)
    else
        priceLine = 'Not for sale'
    end
    local accessLine = ('%s  |  Renters %d/%d'):format(prop.locked and 'Locked' or 'Unlocked', prop.renterCount or 0, prop.maxRenters or 1)
    local description = prop.description and prop.description ~= '' and ('~italic~' .. prop.description .. '~italic~') or nil
    local text = ('~o~%s #%d~s~~n~%s~n~%s'):format(prop.label or 'House', prop.id or 0, priceLine, accessLine)
    if description then text = text .. '~n~' .. description end
    text = text .. '~n~~o~[E]~s~ View house'

    SetDrawOrigin(prop.coords.x, prop.coords.y, prop.coords.z + 1.05, 0)
    local scale = math.max(0.24, math.min(0.34, 0.4 - distance * 0.012))
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 235)
    SetTextDropshadow(1, 0, 0, 0, 210)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawMarkerAt(coords, r, g, b)
    DrawMarker(
        1,
        coords.x, coords.y, coords.z - 0.98,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        1.9, 1.9, 0.85,
        r, g, b, 185,
        false, false, 2, false, nil, nil, false
    )
end

local function addBlip(coords, preset, label, shortRange)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, preset.sprite or 1)
    SetBlipColour(blip, preset.color or 0)
    SetBlipScale(blip, preset.scale or 0.7)
    SetBlipAsShortRange(blip, shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function registerZone(id, coords, radius, hint, markerColor, onInteract)
    return {
        id = id,
        coords = coords,
        radius = radius or 2.0,
        hint = hint,
        markerColor = markerColor or { 255, 140, 0 },
        onInteract = onInteract,
    }
end

local zones = {}

CreateThread(function()
    local presets = Sunset.WorldBlips or {}

    for id, shop in pairs(Sunset.Shops or {}) do
        addBlip(shop.coords, presets.shop or {}, shop.label, false)
        zones[#zones + 1] = registerZone('shop:' .. id, shop.coords, 2.5,
            '[E] ' .. shop.label, { 46, 204, 113 }, function()
                TriggerEvent('sunset:world:openShop', id, shop)
            end)
    end

    for i, atm in ipairs(Sunset.ATMs or {}) do
        addBlip(atm, presets.atm or {}, 'ATM', false)
        zones[#zones + 1] = registerZone('atm:' .. i, atm, 2.0,
            '[E] ATM', { 52, 152, 219 }, function()
                TriggerEvent('sunset:world:openAtm')
            end)
    end

    for id, garage in pairs(Sunset.Garages or {}) do
        addBlip(garage.store, presets.garage or {}, garage.label, false)
        zones[#zones + 1] = registerZone('garage:' .. id, garage.store, 3.0,
            '[E] Store vehicle | /v', { 241, 196, 15 }, function()
                TriggerEvent('sunset:world:garageStore', id)
            end)
    end

    for i, shop in ipairs(Sunset.ClothingShops or {}) do
        addBlip(shop, presets.clothing or {}, 'Clothing', false)
        zones[#zones + 1] = registerZone('clothing:' .. i, shop, 2.5,
            '[E] Clothing Store', { 199, 21, 133 }, function()
                TriggerEvent('sunset:world:openClothing')
            end)
    end

    for i, shop in ipairs(Sunset.BarberShops or {}) do
        addBlip(shop, presets.barber or {}, 'Barber', false)
        zones[#zones + 1] = registerZone('barber:' .. i, shop, 2.5,
            '[E] Barber', { 199, 21, 133 }, function()
                TriggerEvent('sunset:world:openBarber')
            end)
    end

    for id, center in pairs(Sunset.JobCenters or {}) do
        local preset = center.blip or presets.jobcenter or {}
        addBlip(center.coords, preset, center.label, false)
        zones[#zones + 1] = registerZone('job:' .. id, center.coords, 2.5,
            '[E] ' .. center.label, { 255, 140, 0 }, function()
                TriggerEvent('sunset:world:openJobCenter', id, center)
            end)
    end

    for i, station in ipairs(Sunset.GasStations or {}) do
        if station.coords then
            addBlip(station.coords, presets.gas or { sprite = 361, color = 1, scale = 0.75 }, station.label or 'Gas Station', false)
        end
    end
end)

AddEventHandler('sunset:world:registerFactionHQ', function(factionId, faction)
    if not faction or not faction.hq then return end
    local color = faction.marker or { 255, 140, 0 }
    local label = faction.label or factionId
    if faction.type ~= 'illegal' and faction.blip then
        addBlip(faction.hq, faction.blip, label, false)
    end
    local hint = faction.hqHint or ('[E] ' .. label)
    zones[#zones + 1] = registerZone('faction:' .. factionId, faction.hq, 3.5, hint, color, function()
        TriggerEvent('sunset:world:factionHQ', factionId, faction)
    end)
end)

AddEventHandler('sunset:world:registerFactionDepot', function(factionId, depot, faction)
    if not depot or not depot.coords then return end
    local color = faction and faction.marker or { 255, 200, 0 }
    addBlip(depot.coords, { sprite = 326, color = 5, scale = 0.7 }, depot.label or 'Fleet Garage', false)
    zones[#zones + 1] = registerZone('depot:' .. factionId, depot.coords, 3.0,
        '[E] ' .. (depot.label or 'Spawn fleet vehicle'), color, function()
            TriggerEvent('sunset:world:factionDepot', factionId, depot)
        end)
end)

AddEventHandler('sunset:world:registerIllegalSell', function(factionId, coords, faction)
    if not coords then return end
    local color = faction and faction.marker or { 180, 0, 0 }
    local hint = factionId == 'sunset_cartel' and '[E] Sell sealed pouches' or '[E] Fence contraband'
    zones[#zones + 1] = registerZone('illegal:' .. factionId, coords, 2.0, hint, color, function()
        TriggerEvent('sunset:world:illegalSell', factionId)
    end)
end)

AddEventHandler('sunset:world:registerTaxiDepot', function(depot)
    if not depot or not depot.coords then return end
    local color = { 255, 200, 0 }
    addBlip(depot.coords, { sprite = 198, color = 5, scale = 0.75 }, depot.label or 'Cab Depot', false)
    zones[#zones + 1] = registerZone('taxi:depot', depot.coords, 3.0,
        '[E] Spawn cab', color, function()
            TriggerEvent('sunset:world:taxiDepot')
        end)
end)

AddEventHandler('sunset:world:registerCraftingStation', function(stationId, station)
    if not station or not station.coords then return end
    local color = station.marker or { 200, 200, 200 }
    if station.blip then
        addBlip(station.coords, station.blip, station.label or stationId, false)
    end
    zones[#zones + 1] = registerZone('craft:' .. stationId, station.coords, 2.0,
        '[E] ' .. (station.label or 'Craft'), color, function()
            TriggerEvent('sunset:world:openCrafting', stationId, station)
        end)
end)

RegisterNetEvent('sunset:client:registerPropertyZones', function(properties)
    propertyZones = {}
    for _, blip in ipairs(propertyBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    propertyBlips = {}
    local preset = (Sunset.WorldBlips or {}).property or {}
    for _, prop in ipairs(properties or {}) do
        local entry = prop.entry
        if type(entry) == 'string' then entry = json.decode(entry) end
        if not entry or not entry.x then goto continue end
        local coords = vector3(entry.x, entry.y, entry.z)
        propertyBlips[#propertyBlips + 1] = addBlip(coords, preset, prop.label, false)
        propertyZones[#propertyZones + 1] = {
            id = prop.id,
            label = prop.label,
            coords = coords,
            owned = prop.owner_character_id ~= nil,
            access = prop.access == true,
            rented = prop.rented == true,
            locked = prop.locked == true,
            rentEnabled = prop.rentEnabled == true,
            rentPrice = prop.rentPrice,
            forSale = prop.forSale == true,
            minimumLevel = prop.minimumLevel,
            ownerName = prop.ownerName,
            renterCount = prop.renterCount,
            maxRenters = prop.maxRenters,
            description = prop.description,
            price = prop.price,
        }
        ::continue::
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local anyNearby = false

        for _, zone in ipairs(zones) do
            if #(coords - zone.coords) < MARKER_DRAW_DIST then
                anyNearby = true
                drawMarkerAt(zone.coords, zone.markerColor[1], zone.markerColor[2], zone.markerColor[3])
            end
        end

        for _, prop in ipairs(propertyZones) do
            local distance = #(coords - prop.coords)
            if distance < 16.0 then
                anyNearby = true
                drawPropertyLabel(prop, distance)
            end
        end

        Wait(anyNearby and 0 or 500)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local closest = nil
        local closestDist = 999.0

        for _, zone in ipairs(zones) do
            local dist = #(coords - zone.coords)
            if dist < zone.radius and dist < closestDist then
                closest = zone
                closestDist = dist
            end
        end

        for _, prop in ipairs(propertyZones) do
            local dist = #(coords - prop.coords)
            if dist < 2.5 and dist < closestDist then
                closestDist = dist
                local state = prop.access and (prop.rented and 'your rental' or 'your house')
                    or (prop.owned and (prop.locked and 'locked' or 'open'))
                    or ('for sale $' .. prop.price)
                local hint = ('[E] %s (%s)'):format(prop.label, state)
                closest = {
                    id = 'property:' .. prop.id,
                    coords = prop.coords,
                    radius = 2.5,
                    hint = hint,
                    markerColor = { 255, 140, 0 },
                    onInteract = function()
                        TriggerEvent('sunset:world:propertyInteract', prop)
                    end,
                }
            end
        end

        if closest then
            if activeZone ~= closest.id then
                activeZone = closest.id
                showHint(closest.hint)
            end
            if IsControlJustReleased(0, 38) and not IsNuiFocused() then
                if closest.onInteract then closest.onInteract() end
            end
            Wait(0)
        else
            if activeZone then
                activeZone = nil
                hideHint()
            end
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hideHint()
end)
