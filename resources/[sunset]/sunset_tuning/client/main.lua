local STC = SunsetTuningClient
local panelOpen = false
local currentShop = nil
local draftTune = nil
local currentPlate = ''
local currentVeh = 0

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function blocked()
    if IsNuiFocused() or IsPauseMenuActive() then return true end
    local ok, open = pcall(function() return exports.sunset_chat:IsChatOpen() end)
    return ok and open == true
end

local function getDriverVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return 0 end
    return veh
end

local function nearestShop()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, SunsetTuning.InteractRadius + 1.0
    for _, shop in ipairs(SunsetTuning.Shops or {}) do
        local dist = #(coords - shop.coords)
        if dist < bestDist then
            bestDist = dist
            best = shop
        end
    end
    if best and bestDist <= SunsetTuning.InteractRadius then return best end
    return nil
end

local function sendUi(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    sendUi('close')
end

local function openPanel(shop)
    local veh = getDriverVehicle()
    if veh == 0 then
        notify('Intra la volan in masina ta pentru ECU tuning', 'error')
        return
    end

    currentVeh = veh
    currentPlate = STC.plateOf(veh)
    currentShop = shop or nearestShop()

    local tune, err = Sunset.AwaitCallback('sunset:tuning:getTune', currentPlate)
    if not tune then
        notify(err or 'Nu pot incarca ECU pentru aceasta masina', 'error')
        return
    end

    draftTune = SunsetTuning.SanitizeTune(tune)
    panelOpen = true
    SetNuiFocus(true, true)

    sendUi('open', {
        tune = draftTune,
        plate = currentPlate,
        shop = currentShop and currentShop.label or 'ECU Bay',
        costs = {
            save = SunsetTuning.SaveBaseCost,
            flash = SunsetTuning.FlashCost,
            dyno = SunsetTuning.DynoCost,
        },
        stages = SunsetTuning.Stages,
        exhaustModes = SunsetTuning.ExhaustModes,
    })
end

function OpenTuningPanel()
    local shop = nearestShop()
    if not shop then
        notify('Mergi la LS Customs / Harmony pentru ECU tuning', 'error')
        return
    end
    openPanel(shop)
end

exports('OpenTuningPanel', OpenTuningPanel)

RegisterNUICallback('tuningClose', function(_, cb)
    closePanel()
    cb({ ok = true })
end)

RegisterNUICallback('tuningPreview', function(data, cb)
    if not panelOpen or currentVeh == 0 then cb({ ok = false }) return end
    draftTune = SunsetTuning.SanitizeTune(data.tune or draftTune)
    ApplyTune(currentVeh, draftTune)
    cb({ ok = true })
end)

RegisterNUICallback('tuningSave', function(data, cb)
    if not panelOpen or currentPlate == '' then cb({ ok = false }) return end
    local flash = data.flash == true
    local saved, err = Sunset.AwaitCallback('sunset:tuning:saveTune', currentPlate, data.tune or draftTune, flash)
    if not saved then
        notify(err or 'Salvare esuata', 'error')
        cb({ ok = false, error = err })
        return
    end

    draftTune = SunsetTuning.SanitizeTune(saved.tune)
    STC.plateTunes[currentPlate] = draftTune
    ApplyTune(currentVeh, draftTune)
    if flash then TriggerServerEvent('sunset:tuning:flashApplied', currentPlate) end
    notify(('ECU salvat — $%d'):format(saved.cost or SunsetTuning.SaveBaseCost), 'success')
    cb({ ok = true, tune = draftTune })
end)

RegisterNUICallback('tuningDyno', function(_, cb)
    if not panelOpen or currentPlate == '' then cb({ ok = false }) return end
    closePanel()
    SunsetTuningClient.RunDynoTest(currentShop, function(result)
        local dynoSaved, err = Sunset.AwaitCallback('sunset:tuning:runDyno', currentPlate, result.hp, result.torque)
        if dynoSaved then
            if draftTune then
                draftTune.dyno = dynoSaved
                STC.plateTunes[currentPlate] = draftTune
            end
            sendUi('dynoResult', { dyno = dynoSaved, result = result })
        else
            notify(err or 'Dyno esuat', 'error')
        end
    end)
    cb({ ok = true })
end)

RegisterNUICallback('tuningLeaderboard', function(_, cb)
    local rows = Sunset.AwaitCallback('sunset:tuning:getLeaderboard')
    cb({ ok = true, rows = rows or {} })
end)

RegisterCommand('ecu', function()
    if blocked() then return end
    OpenTuningPanel()
end, false)

RegisterCommand('tuning', function()
    if blocked() then return end
    OpenTuningPanel()
end, false)

RegisterKeyMapping('ecu', 'Deschide ECU Tuning', 'keyboard', '')

CreateThread(function()
    for _, shop in ipairs(SunsetTuning.Shops or {}) do
        if shop.blip then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, shop.blip.sprite or 72)
            SetBlipColour(blip, shop.blip.color or 47)
            SetBlipScale(blip, shop.blip.scale or 0.85)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(shop.label or 'ECU Tuning')
            EndTextCommandSetBlipName(blip)
        end
    end
end)

CreateThread(function()
    local hint = false
    while true do
        Wait(0)
        local shop = nearestShop()
        if shop and not panelOpen and not blocked() then
            local veh = getDriverVehicle()
            if veh ~= 0 then
                SetTextComponentFormat('STRING')
                AddTextComponentSubstringPlayerName('~o~[E]~s~ ECU Tuning — ' .. (shop.label or ''))
                DisplayHelpTextFromStringLabel(0, false, true, -1)
                if IsControlJustReleased(0, 38) then
                    openPanel(shop)
                end
                hint = true
            elseif hint then hint = false end
        else
            if hint then hint = false end
            Wait(400)
        end
    end
end)

RegisterNetEvent('sunset:client:spawnOwnedVehicle', function(vehData)
    if not vehData or not vehData.props then return end
    CreateThread(function()
        Wait(1200)
        local plate = STC.normalizePlate(vehData.plate)
        local props = vehData.props
        if type(props) == 'string' then
            local ok, decoded = pcall(json.decode, props)
            props = ok and decoded or {}
        end
        if props and props.ecu then
            STC.plateTunes[plate] = SunsetTuning.SanitizeTune(props.ecu)
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if STC.plateOf(veh) == plate then
                    ApplyTune(veh, props.ecu)
                    break
                end
            end
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closePanel()
end)
