-- LS Customs / Harmony — uses sunset_ui Context Menu (playerInteractionShow).
-- Same interface as 24/7 stores, fisherman NPC, gas stations, etc.

local menuOpen = false
local pendingShop = nil

local LSC_ACTIONS = {
    lsc_repair = true,
    lsc_tune = true,
}

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function formatMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return '$' .. formatted
end

local function closeContextMenu()
    if not menuOpen then return end
    menuOpen = false
    pendingShop = nil
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)
end

local function getDriverVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return 0 end
    return veh
end

local function buildActions(opts)
    local actions = {}
    if opts.repairAvailable == true then
        local price = opts.repairPrice or 250
        actions[#actions + 1] = {
            id = 'lsc_repair',
            label = ('Repair Vehicle (%s)'):format(formatMoney(price)),
            group = 'CUSTOMS',
        }
    end
    actions[#actions + 1] = {
        id = 'lsc_tune',
        label = 'ECU Tuning',
        group = 'CUSTOMS',
    }
    return actions
end

function OpenLsCustomsMenu(opts)
    opts = opts or {}
    if menuOpen then return end
    local veh = getDriverVehicle()
    if veh == 0 then
        notify('Get in the driver seat to use this shop.', 'error')
        return
    end

    pendingShop = opts.shop
    local title = opts.title or 'LS Customs'
    exports.sunset_ui:Send('playerInteractionShow', {
        menuTitle = title,
        target = { name = opts.shopLabel or title, id = '' },
        actions = buildActions(opts),
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = true
end

exports('OpenLsCustomsMenu', OpenLsCustomsMenu)

AddEventHandler('sunset:nui:playerInteractionClose', function()
    if menuOpen then closeContextMenu() end
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not menuOpen or not data or not data.action then return end
    if not LSC_ACTIONS[data.action] then return end

    local action = data.action
    local shop = pendingShop
    closeContextMenu()

    if action == 'lsc_repair' then
        local veh = getDriverVehicle()
        if veh == 0 then
            notify('Not in a vehicle.', 'error')
            return
        end

        local ok, err = Sunset.AwaitCallback('sunset:mechanicShopRepair')
        if ok then
            SetVehicleFixed(veh)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 1000.0)
            SetVehicleDirtLevel(veh, 0.0)
            notify('Vehicle repaired ($250).', 'success')
        else
            notify(err or 'Repair failed.', 'error')
        end

    elseif action == 'lsc_tune' then
        exports.sunset_tuning:OpenTuningPanel(shop)
    end
end)

AddEventHandler('sunset:tuning:openLsCustomsMenu', function()
    OpenLsCustomsMenu({
        title = 'LS Customs',
        shopLabel = 'LS Customs — Burton',
        repairAvailable = true,
        repairPrice = 250,
        shop = SunsetTuning.Shops[1],
    })
end)

AddEventHandler('sunset:tuning:openHarmonyMenu', function()
    OpenLsCustomsMenu({
        title = 'Harmony Tuning',
        shopLabel = 'Harmony — ECU Bay',
        repairAvailable = false,
        shop = SunsetTuning.Shops[2],
    })
end)
