local STC = SunsetTuningClient
local lastDriverVeh = 0

CreateThread(function()
    while true do
        Wait(700)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            lastDriverVeh = 0
            goto continue
        end

        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then goto continue end
        if veh == lastDriverVeh then goto continue end
        lastDriverVeh = veh

        local plate = STC.plateOf(veh)
        if plate == '' then goto continue end

        if STC.persistedPlates[plate] and STC.plateTunes[plate] then
            ApplyTune(veh, STC.plateTunes[plate], false)
            if STC.BurstExhaust and not STC.dynoActive then
                SetTimeout(600, function()
                    if DoesEntityExist(veh) and not STC.dynoActive then STC.BurstExhaust(veh, 'flash', 3) end
                end)
            end
            goto continue
        end

        local payload = Sunset.AwaitCallback('sunset:tuning:getTune', plate)
        if payload and type(payload) == 'table' and payload.saved and payload.tune then
            local tune = SunsetTuning.SanitizeTune(payload.tune)
            STC.plateTunes[plate] = tune
            STC.persistedPlates[plate] = true
            ApplyTune(veh, tune, false)
            if STC.BurstExhaust and not SunsetTuning.IsStockTune(tune) and not STC.dynoActive then
                SetTimeout(600, function()
                    if DoesEntityExist(veh) and not STC.dynoActive then STC.BurstExhaust(veh, 'flash', 3) end
                end)
            end
        end

        ::continue::
    end
end)
