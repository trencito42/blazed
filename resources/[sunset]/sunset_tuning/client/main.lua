local STC = SunsetTuningClient
local panelOpen = false
local currentShop = nil
local draftTune = nil
local draftCosmetics = nil
local savedCosmetics = nil
local hasSavedTune = false
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

local function hardwareAvailability(veh)
    local out = {}
    SetVehicleModKit(veh, 0)
    for key, slot in pairs(SunsetTuning.HardwareSlots or {}) do
        out[key] = math.max(0, GetNumVehicleMods(veh, slot.modType))
    end
    out.turbo = true
    return out
end

local function closePanel(restoreStock)
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    sendUi('close')
    if restoreStock and currentVeh ~= 0 and DoesEntityExist(currentVeh) then
        if savedCosmetics then
            ApplyCosmetics(currentVeh, savedCosmetics)
        end
        local modelName = STC.appliedVehicles[currentVeh] and STC.appliedVehicles[currentVeh].model
        if hasSavedTune and STC.plateTunes[currentPlate] then
            ApplyTune(currentVeh, STC.plateTunes[currentPlate], false, modelName)
        else
            ApplyTune(currentVeh, SunsetTuning.StockTune(), false, modelName)
        end
    end
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
    if not currentShop then
        notify('Nu esti la un shop de tuning', 'error')
        return
    end

    local modelName = GetEntityArchetypeName(veh)
    if not modelName or modelName == '' then
        modelName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    end
    if modelName then modelName = modelName:lower() end

    local caps = SunsetTuning.ProfileResolver.Resolve(modelName, GetVehicleClass(veh))
    if not caps.supported then
        notify('ECU tuning is not available for this vehicle type.', 'error')
        return
    end

    CaptureModelBaseline(veh)

    local payload, err = Sunset.AwaitCallback('sunset:tuning:getTune', currentPlate, modelName)
    if not payload then
        notify(err or 'Nu pot incarca ECU pentru aceasta masina', 'error')
        return
    end

    if type(payload) == 'table' and payload.tune then
        draftTune = SunsetTuning.SanitizeTune(payload.tune, caps)
        hasSavedTune = payload.saved == true
        draftCosmetics = SunsetTuning.SanitizeCosmetics(payload.cosmetics or ReadCosmeticsFromVehicle(veh))
    else
        draftTune = SunsetTuning.SanitizeTune(payload)
        hasSavedTune = not SunsetTuning.IsStockTune(draftTune)
        draftCosmetics = ReadCosmeticsFromVehicle(veh)
    end
    if draftCosmetics.plateText == '' then
        draftCosmetics.plateText = currentPlate
    end
    savedCosmetics = draftCosmetics

    panelOpen = true
    SetNuiFocus(true, true)

    sendUi('open', {
        tune = draftTune,
        cosmetics = draftCosmetics,
        saved = hasSavedTune,
        plate = currentPlate,
        model = modelName,
        capabilities = caps,
        drivetrainLabel = SunsetTuning.ProfileResolver.DisplayLabel(caps),
        shop = currentShop and currentShop.label or 'ECU Bay',
        costs = {
            save = SunsetTuning.SaveBaseCost,
            flash = SunsetTuning.FlashCost,
            dyno = SunsetTuning.DynoCost,
        },
        stages = SunsetTuning.Stages,
        exhaustModes = SunsetTuning.ExhaustModes,
        hardwareAvailability = hardwareAvailability(veh),
        hardwareSlots = SunsetTuning.HardwareSlots,
        featureCosts = SunsetTuning.FeatureCosts,
    })

    ApplyTune(currentVeh, draftTune, false, modelName)
    ApplyCosmetics(currentVeh, draftCosmetics, false)
end

function OpenTuningPanel(shop)
    openPanel(shop)
end

exports('OpenTuningPanel', OpenTuningPanel)

RegisterNUICallback('tuningClose', function(_, cb)
    closePanel(true)
    cb({ ok = true })
end)

RegisterNUICallback('tuningPreview', function(data, cb)
    if not panelOpen or currentVeh == 0 then cb({ ok = false }) return end
    draftTune = SunsetTuning.SanitizeTune(data.tune or draftTune, STC.appliedVehicles[currentVeh] and STC.appliedVehicles[currentVeh].caps)
    if data.cosmetics then
        draftCosmetics = SunsetTuning.SanitizeCosmetics(data.cosmetics)
    end
    local modelName = STC.appliedVehicles[currentVeh] and STC.appliedVehicles[currentVeh].model
    ApplyTune(currentVeh, draftTune, false, modelName)
    ApplyCosmetics(currentVeh, draftCosmetics, false)
    cb({ ok = true })
end)

RegisterNUICallback('tuningTestFlame', function(_, cb)
    if not panelOpen or currentVeh == 0 then cb({ ok = false }) return end
    if STC.BurstExhaust then STC.BurstExhaust(currentVeh, 'flash', 3) end
    cb({ ok = true })
end)

RegisterNUICallback('tuningSave', function(data, cb)
    if not panelOpen or currentPlate == '' then cb({ ok = false }) return end
    local flash = data.flash == true
    draftCosmetics = SunsetTuning.SanitizeCosmetics(data.cosmetics or draftCosmetics)
    local saved, err = Sunset.AwaitCallback('sunset:tuning:saveTune', currentPlate, data.tune or draftTune, flash, data.cosmetics or draftCosmetics)
    if not saved then
        notify(err or 'Salvare esuata', 'error')
        cb({ ok = false, error = err })
        return
    end

    local oldPlate = currentPlate
    draftTune = SunsetTuning.SanitizeTune(saved.tune)
    if saved.cosmetics then draftCosmetics = SunsetTuning.SanitizeCosmetics(saved.cosmetics) end
    if saved.plate and saved.plate ~= '' then currentPlate = STC.normalizePlate(saved.plate) end
    hasSavedTune = true
    savedCosmetics = draftCosmetics
    STC.plateTunes[currentPlate] = draftTune
    STC.persistedPlates[currentPlate] = true
    if oldPlate ~= currentPlate then
        STC.plateTunes[oldPlate] = nil
        STC.persistedPlates[oldPlate] = nil
    end
    ApplyTune(currentVeh, draftTune, true)
    ApplyCosmetics(currentVeh, draftCosmetics)
    if flash and STC.BurstExhaust then STC.BurstExhaust(currentVeh, 'flash', 5) end
    notify(('ECU salvat & flash — $%d'):format(saved.cost or SunsetTuning.SaveBaseCost), 'success')
    sendUi('saved', { saved = true, tune = draftTune, cosmetics = draftCosmetics, plate = currentPlate })
    cb({ ok = true, tune = draftTune })
end)

RegisterNUICallback('tuningDyno', function(_, cb)
    if not panelOpen or currentPlate == '' then cb({ ok = false }) return end
    if STC.IsDynoActive and STC.IsDynoActive() then cb({ ok = false }) return end

    local dynoSession, beginError = Sunset.AwaitCallback('sunset:tuning:beginDyno', currentPlate)
    if not dynoSession or not dynoSession.token then
        notify(beginError or ('Dyno indisponibil — ai nevoie de $%d in banca'):format(SunsetTuning.DynoCost), 'error')
        cb({ ok = false, error = beginError })
        return
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    sendUi('dynoRunning', {})

    SunsetTuningClient.RunDynoTest(currentShop, function(result)
        SetNuiFocus(true, true)
        if not result then
            Sunset.AwaitCallback('sunset:tuning:cancelDyno', dynoSession.token)
            sendUi('dynoDone', { ok = false })
            cb({ ok = false })
            return
        end

        local dynoSaved, err = Sunset.AwaitCallback('sunset:tuning:finishDyno', dynoSession.token, result.hp, result.torque)
        if dynoSaved then
            if draftTune then
                draftTune.dyno = dynoSaved
                STC.plateTunes[currentPlate] = draftTune
                hasSavedTune = true
                STC.persistedPlates[currentPlate] = true
            end
            sendUi('dynoResult', { dyno = dynoSaved, result = result })
        else
            notify(err or 'Dyno esuat — verifica banii in banca ($' .. SunsetTuning.DynoCost .. ')', 'error')
            sendUi('dynoDone', { ok = false })
        end
        cb({ ok = true })
    end)
end)

RegisterNUICallback('tuningLeaderboard', function(_, cb)
    local rows = Sunset.AwaitCallback('sunset:tuning:getLeaderboard')
    cb({ ok = true, rows = rows or {} })
end)

-- Harmony: secondary tuning shop (LS Customs uses faction HQ menu)
CreateThread(function()
    for _, shop in ipairs(SunsetTuning.Shops or {}) do
        if shop.id ~= 'lsc_main' and shop.blip then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, shop.blip.sprite or 72)
            SetBlipColour(blip, shop.blip.color or 47)
            SetBlipScale(blip, shop.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(shop.label or 'ECU Tuning')
            EndTextCommandSetBlipName(blip)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        local shop = nil
        for _, s in ipairs(SunsetTuning.Shops or {}) do
            if s.id == 'lsc_harmony' then shop = s break end
        end
        if shop and not panelOpen and not blocked() then
            local dist = #(GetEntityCoords(PlayerPedId()) - shop.coords)
            if dist <= SunsetTuning.InteractRadius and getDriverVehicle() ~= 0 then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~o~[E]~s~ Harmony — ECU Tuning')
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('sunset:tuning:openHarmonyMenu')
                end
            else
                Wait(400)
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('sunset:client:spawnOwnedVehicle', function(vehData)
    if not vehData or not vehData.plate then return end
    CreateThread(function()
        Wait(1200)
        local plate = STC.normalizePlate(vehData.plate)
        local props = vehData.props
        if type(props) == 'string' then
            local ok, decoded = pcall(json.decode, props)
            props = ok and decoded or {}
        end
        if props and props.ecu and not SunsetTuning.IsStockTune(props.ecu) then
            local tune = SunsetTuning.SanitizeTune(props.ecu)
            STC.plateTunes[plate] = tune
            STC.persistedPlates[plate] = true
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if STC.plateOf(veh) == plate then
                    ApplyTune(veh, tune, false, vehData.model)
                    break
                end
            end
        else
            STC.plateTunes[plate] = nil
            STC.persistedPlates[plate] = nil
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closePanel(false)
end)
