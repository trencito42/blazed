-- Gas station attendants + Ammunation clerk

local INTERACT_DIST = 2.4
local PROMPT_DIST = 5.5
local INTERACT_KEY = 38

local businessNpcs = {}

local GAS_STYLES = {
    ['LTD Gasoline'] = { badge = 'LTD GASOLINE', shirt = 2 },
    ['Ron Gas'] = { badge = 'RON GAS', shirt = 4 },
    ['Xero Gas'] = { badge = 'XERO GAS', shirt = 1 },
}

local function gasBrand(label)
    label = label or ''
    for prefix, style in pairs(GAS_STYLES) do
        if label:find(prefix, 1, true) then return style end
    end
    return { badge = 'SUNSET FUEL INC.', shirt = 0 }
end

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function spawnGasAttendant(station, index)
    local coords = station.attendant or station.coords
    if not coords then return end
    local heading = 0.0
    local spawn = coords
    if type(coords) == 'vector4' then
        spawn = vector3(coords.x, coords.y, coords.z)
        heading = coords.w
    elseif station.coords then
        spawn = station.coords + vector3(1.2, 0.8, 0.0)
        heading = 200.0
    end

    local brand = gasBrand(station.label)
    local ped = SunsetWorld.Npc.spawn({
        model = 's_m_m_linecook',
        coords = vector4(spawn.x, spawn.y, spawn.z, heading),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        components = {
            { 3, 0, 0 },
            { 4, 0, 0 },
            { 6, 0, 0 },
            { 8, 15, 0 },
            { 11, 13, brand.shirt or 0 },
        },
    })
    if not ped then return end

    businessNpcs[#businessNpcs + 1] = {
        id = ('gas_attendant_%d'):format(index),
        ped = ped,
        kind = 'gas',
        station = station,
        meta = {
            badge = brand.badge,
            badgeClass = 'gas',
            bodyClass = 'gas',
            icon = 'ph-gas-pump',
            title = 'Gas Station Operator',
            desc = 'Business / Interaction',
            key = 'E',
        },
        onInteract = function()
            TriggerEvent('sunset:businesses:openGasMenu')
        end,
    }
end

local function spawnAmmunationClerk()
    local shop = Sunset.Shops and Sunset.Shops.ammunation
    if not shop or not shop.coords then return end
    local c = shop.cashier or vector4(shop.coords.x, shop.coords.y, shop.coords.z, 160.0)
    local ped = SunsetWorld.Npc.spawn({
        model = 's_m_y_ammucity_01',
        coords = c,
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        components = {
            { 3, 0, 0 },
            { 4, 0, 0 },
            { 11, 1, 0 },
        },
    })
    if not ped then return end

    businessNpcs[#businessNpcs + 1] = {
        id = 'ammunation_clerk',
        ped = ped,
        kind = 'ammo',
        meta = {
            badge = 'AMMUNATION',
            badgeClass = 'ammo',
            bodyClass = 'ammo',
            icon = 'ph-crosshair',
            title = 'Marcus (Arme)',
            desc = 'Interaction / Store',
            key = 'E',
        },
        onInteract = function()
            TriggerEvent('sunset:world:openShop', 'ammunation', shop)
        end,
    }
end

CreateThread(function()
    Wait(2000)
    for index, station in ipairs(Sunset.GasStations or {}) do
        spawnGasAttendant(station, index)
    end
    spawnAmmunationClerk()
end)

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local nearest = nil
        local minGlobalDist = 999.0

        for _, row in ipairs(businessNpcs) do
            if row.ped and DoesEntityExist(row.ped) then
                local dist = #(pos - GetEntityCoords(row.ped))
                if dist < minGlobalDist then minGlobalDist = dist end
                if dist < PROMPT_DIST then
                    SunsetWorld.Npc.showTooltip(row.id, row.ped, row.meta)
                    nearest = row
                else
                    SunsetWorld.Npc.hideTooltip(row.id)
                end
            end
        end

        if nearest and minGlobalDist < INTERACT_DIST and IsControlJustPressed(0, INTERACT_KEY) and SunsetWorld.tryInteract() then
            if nearest.onInteract then nearest.onInteract() end
        end

        if nearest then
            Wait(0)
        elseif minGlobalDist < 25.0 then
            Wait(250)
        else
            Wait(800)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, row in ipairs(businessNpcs) do
        SunsetWorld.Npc.hideTooltip(row.id)
        if row.ped and DoesEntityExist(row.ped) then
            DeleteEntity(row.ped)
        end
    end
end)
