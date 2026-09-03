local activeZone = nil
local propertyZones = {}

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

local function drawMarkerAt(coords, r, g, b)
    DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        1.2, 1.2, 0.5, r, g, b, 120, false, false, 2, false, nil, nil, false)
end

local function addBlip(coords, preset, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, preset.sprite or 1)
    SetBlipColour(blip, preset.color or 0)
    SetBlipScale(blip, preset.scale or 0.7)
    SetBlipAsShortRange(blip, true)
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
        addBlip(shop.coords, presets.shop or {}, shop.label)
        zones[#zones + 1] = registerZone('shop:' .. id, shop.coords, 2.5,
            '[E] ' .. shop.label, { 46, 204, 113 }, function()
                TriggerEvent('sunset:world:openShop', id, shop)
            end)
    end

    for i, atm in ipairs(Sunset.ATMs or {}) do
        addBlip(atm, presets.atm or {}, 'ATM')
        zones[#zones + 1] = registerZone('atm:' .. i, atm, 2.0,
            '[E] ATM', { 52, 152, 219 }, function()
                TriggerEvent('sunset:world:openAtm')
            end)
    end

    for id, garage in pairs(Sunset.Garages or {}) do
        addBlip(garage.store, presets.garage or {}, garage.label)
        zones[#zones + 1] = registerZone('garage:' .. id, garage.store, 3.0,
            '[E] Store vehicle | /garage', { 241, 196, 15 }, function()
                TriggerEvent('sunset:world:garageStore', id)
            end)
    end

    for i, shop in ipairs(Sunset.ClothingShops or {}) do
        addBlip(shop, presets.clothing or {}, 'Clothing')
        zones[#zones + 1] = registerZone('clothing:' .. i, shop, 2.5,
            '[E] Clothing Store', { 199, 21, 133 }, function()
                TriggerEvent('sunset:world:openClothing')
            end)
    end

    for i, shop in ipairs(Sunset.BarberShops or {}) do
        addBlip(shop, presets.barber or {}, 'Barber')
        zones[#zones + 1] = registerZone('barber:' .. i, shop, 2.5,
            '[E] Barber', { 199, 21, 133 }, function()
                TriggerEvent('sunset:world:openBarber')
            end)
    end

    for id, center in pairs(Sunset.JobCenters or {}) do
        local preset = center.blip or presets.jobcenter or {}
        addBlip(center.coords, preset, center.label)
        zones[#zones + 1] = registerZone('job:' .. id, center.coords, 2.5,
            '[E] ' .. center.label, { 255, 140, 0 }, function()
                TriggerEvent('sunset:world:openJobCenter', id, center)
            end)
    end
end)

AddEventHandler('sunset:world:registerFactionHQ', function(factionId, faction)
    if not faction or not faction.hq then return end
    local color = faction.marker or { 255, 140, 0 }
    local label = faction.label or factionId
    if faction.type ~= 'illegal' and faction.blip then
        addBlip(faction.hq, faction.blip, label .. ' HQ')
    end
    zones[#zones + 1] = registerZone('faction:' .. factionId, faction.hq, 2.5,
        '[E] ' .. label .. ' HQ', color, function()
            TriggerEvent('sunset:world:factionHQ', factionId, faction)
        end)
end)

AddEventHandler('sunset:world:registerCraftingStation', function(stationId, station)
    if not station or not station.coords then return end
    local color = station.marker or { 200, 200, 200 }
    if station.blip then
        addBlip(station.coords, station.blip, station.label or stationId)
    end
    zones[#zones + 1] = registerZone('craft:' .. stationId, station.coords, 2.0,
        '[E] ' .. (station.label or 'Craft'), color, function()
            TriggerEvent('sunset:world:openCrafting', stationId, station)
        end)
end)

RegisterNetEvent('sunset:client:registerPropertyZones', function(properties)
    propertyZones = {}
    local preset = (Sunset.WorldBlips or {}).property or {}
    for _, prop in ipairs(properties or {}) do
        local entry = prop.entry
        if type(entry) == 'string' then entry = json.decode(entry) end
        if not entry or not entry.x then goto continue end
        local coords = vector3(entry.x, entry.y, entry.z)
        addBlip(coords, preset, prop.label)
        propertyZones[#propertyZones + 1] = {
            id = prop.id,
            label = prop.label,
            coords = coords,
            owned = prop.owner_character_id ~= nil,
            price = prop.price,
        }
        ::continue::
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
                local hint = prop.owned and ('[E] ' .. prop.label .. ' (owned)') or ('[E] Buy ' .. prop.label .. ' ($' .. prop.price .. ')')
                closest = {
                    id = 'property:' .. prop.id,
                    coords = prop.coords,
                    radius = 2.5,
                    hint = hint,
                    markerColor = { 155, 89, 182 },
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
            drawMarkerAt(closest.coords, closest.markerColor[1], closest.markerColor[2], closest.markerColor[3])
            if IsControlJustReleased(0, 38) and not IsNuiFocused() then
                if closest.onInteract then closest.onInteract() end
            end
            Wait(0)
        else
            if activeZone then
                activeZone = nil
                hideHint()
            end
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hideHint()
end)
