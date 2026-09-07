local STC = SunsetTuningClient
local lscOpen = false
local pendingShop = nil

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function sendUi(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function closeLscMenu()
    if not lscOpen then return end
    lscOpen = false
    pendingShop = nil
    SetNuiFocus(false, false)
    sendUi('lscClose')
end

local function getDriverVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return 0 end
    return veh
end

function OpenLsCustomsMenu(opts)
    opts = opts or {}
    if lscOpen then return end
    local veh = getDriverVehicle()
    if veh == 0 then
        notify('Intra la volan pentru LS Customs', 'error')
        return
    end

    pendingShop = opts.shop
    lscOpen = true
    SetNuiFocus(true, true)
    sendUi('lscOpen', {
        title = opts.title or 'LS CUSTOMS',
        repairAvailable = opts.repairAvailable == true,
        repairPrice = opts.repairPrice or 250,
        shopLabel = opts.shopLabel or 'LS Customs',
    })
end

exports('OpenLsCustomsMenu', OpenLsCustomsMenu)

RegisterNUICallback('lscClose', function(_, cb)
    closeLscMenu()
    cb({ ok = true })
end)

RegisterNUICallback('lscRepair', function(_, cb)
    closeLscMenu()
    local veh = getDriverVehicle()
    if veh == 0 then
        notify('Nu esti in vehicul', 'error')
        cb({ ok = false })
        return
    end

    local ok, err = Sunset.AwaitCallback('sunset:mechanicShopRepair')
    if ok then
        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehicleDirtLevel(veh, 0.0)
        notify('Vehicul reparat la LS Customs ($250)', 'success')
    else
        notify(err or 'Reparatie esuata', 'error')
    end
    cb({ ok = ok == true })
end)

RegisterNUICallback('lscTune', function(_, cb)
    closeLscMenu()
    exports.sunset_tuning:OpenTuningPanel(pendingShop)
    cb({ ok = true })
end)

AddEventHandler('sunset:tuning:openLsCustomsMenu', function()
    OpenLsCustomsMenu({
        title = 'LS CUSTOMS',
        shopLabel = 'LS Customs — Burton',
        repairAvailable = true,
        repairPrice = 250,
        shop = SunsetTuning.Shops[1],
    })
end)

AddEventHandler('sunset:tuning:openHarmonyMenu', function()
    OpenLsCustomsMenu({
        title = 'HARMONY TUNING',
        shopLabel = 'Harmony — ECU Bay',
        repairAvailable = false,
        shop = SunsetTuning.Shops[2],
    })
end)
