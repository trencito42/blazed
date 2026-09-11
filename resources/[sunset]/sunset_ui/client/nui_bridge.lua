local function forward(name)
    RegisterNUICallback(name, function(data, cb)
        TriggerEvent('sunset:nui:' .. name, data)
        cb('ok')
    end)
end

forward('select')
forward('create')
forward('delete')
forward('characterCreate')
forward('characterBack')
forward('chatSend')
forward('chatClose')
forward('chatHistory')
forward('menuClose')
forward('menuAction')
forward('menuVehicleAction')
forward('menuJobAction')
forward('authLogin')
forward('authRegister')
forward('authPickAccount')
forward('authRemoveAccount')
forward('authSetEmail')
forward('authSetQuickLogin')
forward('authSavePortrait')
forward('spawnSelect')
forward('spawnClose')
forward('inventoryClose')
forward('inventoryUse')
forward('inventoryTradeRequest')
forward('inventoryTradeAccept')
forward('inventoryTradeDecline')
forward('inventoryTradeOffer')
forward('inventoryTradeRemove')
forward('inventoryTradeOfferCash')
forward('inventoryTradeRemoveCash')
forward('inventoryTradeCatalog')
forward('inventoryTradeOfferAsset')
forward('inventoryTradeRemoveAsset')
forward('inventoryTradeConfirm')
forward('inventoryTradeCancel')
forward('inventoryDrop')
forward('inventoryMoveSlot')
forward('shopBuy')
forward('shopClose')
forward('atmAction')
forward('atmClose')
forward('mdcClose')
forward('mdcSearch')
forward('mdcVehicleSearch')
forward('mdcToggleBolo')
forward('mdcSetUnitStatus')
forward('mdcSetCallStatus')
forward('mdcSetWaypoint')
forward('mdcRequestBackup')
forward('mdcCancelBackup')
forward('mdcSetWanted')
forward('mdcClearWanted')
forward('mdcSummon')
forward('mdcFindWanted')
forward('mdcUnjail')
forward('mdcIssueCitation')
forward('mdcSuspendLicense')
forward('mdcStartRadar')
forward('mdcStopRadar')
forward('mdcSetUnitWaypoint')
forward('mdcBookingGps')
forward('submit112Call')
forward('close112Modal')
forward('ticketClose')
forward('ticketIssue')
forward('ticketPay')
forward('ticketRefuse')
forward('serviceCallsClose')
forward('serviceCallsAccept')
forward('jobsClose')
forward('jobsSelect')
forward('skillsClose')
forward('helpClose')
forward('businessPanelsClose')
forward('businessManage')
forward('businessOwnerRefresh')
forward('businessAdminRefresh')
forward('businessSelect')
forward('factionPanelsClose')
forward('factionManage')
forward('factionBrowse')
forward('factionDirectoryDetail')
forward('clanPanelsClose')
forward('clanPanelsReady')
forward('clanBrowse')
forward('clanProfile')
forward('clanManage')
forward('garageSpawn')
forward('garageStore')
forward('garageLocate')
forward('garageClaimInsurance')
forward('garageRenewInsurance')
forward('garageClose')
forward('fleetGarageSpawn')
forward('fleetGarageClose')
forward('fleetGarageReady')
forward('propertiesClose')
forward('propertyAction')
forward('propertyOpenManage')
forward('propertyRenters')
forward('emotePlay')
forward('emotesClose')
forward('hotbarAssign')
forward('hotbarUse')
forward('emoteWheelClose')
forward('clothingApply')
forward('clothingPreview')
forward('clothingClose')
forward('wardrobeClose')
forward('wardrobeReady')
forward('wardrobeCategory')
forward('wardrobePreview')
forward('wardrobePurchase')
forward('phoneClose')
forward('phoneSend')
forward('phoneAddContact')
forward('phoneDeleteContact')
forward('phoneTrigger112')
forward('phoneBankTransfer')
forward('taxiRefresh')
forward('taxiEstimate')
forward('taxiRequestRide')
forward('taxiAcceptRide')
forward('taxiCancelRide')
forward('taxiPickup')
forward('taxiComplete')
forward('taxiSetAvailable')
forward('taxiPickMap')
forward('taxiPickPlace')
forward('taxiTip')
forward('documentsClose')
forward('jobCenterHire')
forward('jobCenterClose')
forward('jobCenterWaypoint')
forward('jobsStartWork')
forward('jobsCancelWork')
forward('craftingCraft')
forward('craftingClose')
forward('dealershipClose')
forward('dealershipSelect')
forward('dealershipRotate')
forward('dealershipBuy')
forward('dealershipTestDrive')
forward('dealershipAdminSave')
forward('dealershipAdminDelete')
forward('appearanceChange')
forward('appearanceCamera')
forward('appearancePreview')
forward('appearanceSave')
forward('appearanceRotate')
forward('appearanceGender')
forward('licenseQuizClose')
forward('licenseQuizSubmit')
forward('playerInteractionClose')
forward('playerInteractionAction')
forward('playerInteractionHoldComplete')
forward('fuelPumpCheckout')
forward('fuelPumpPumpStart')
forward('fuelPumpPumpStop')
forward('fishingShopBuy')
forward('fishingShopSell')
forward('fishingShopClose')

RegisterNUICallback('licenseQuizAnswer', function(data, cb)
    data = type(data) == 'table' and data or {}
    local licenseType = data.licenseType
    local questionIndex = tonumber(data.questionIndex)
    local answer = tonumber(data.answer)
    if not licenseType or not questionIndex or not answer then
        cb({ ok = false, error = 'Missing answer data.' })
        return
    end

    exports.sunset_core:TriggerCallback('sunset:license:gradeTheoryAnswer', function(result, err)
        if err then
            cb({ ok = false, error = tostring(err) })
            return
        end
        cb({
            ok = true,
            correct = type(result) == 'table' and result.correct == true,
        })
    end, licenseType, questionIndex, answer)
end)

RegisterNUICallback('hudEditSave', function(data, cb)
    TriggerEvent('sunset:nui:hudEditSave', data)
    cb('ok')
end)

RegisterNUICallback('hudEditClose', function(_, cb)
    TriggerEvent('sunset:nui:hudEditClose')
    SetFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('hudEditFocus', function(data, cb)
    SetFocus(data.focus == true, data.focus == true)
    cb('ok')
end)

-- Client events for other resources to trigger UI (no server logic here)
RegisterNetEvent('sunset:ui:policeOrder', function(data)
    Send('policeOrderShow', data or {})
end)

RegisterNetEvent('sunset:ui:announcement', function(data)
    Send('announcementShow', data or {})
end)

RegisterNetEvent('sunset:ui:ticketReceive', function(data)
    Send('ticketReceiveShow', data or {})
    SetFocus(true, true)
end)

RegisterNetEvent('sunset:ui:serviceCalls', function(data)
    Send('serviceCallsShow', data or {})
    SetFocus(true, true)
end)

RegisterNetEvent('sunset:ui:jobs', function(data)
    Send('jobsShow', data or {})
    SetFocus(true, true)
end)

RegisterNetEvent('sunset:ui:skills', function(data)
    Send('skillsShow', data or {})
    SetFocus(true, true)
end)

RegisterNetEvent('sunset:ui:help', function(data)
    Send('helpShow', data or {})
    SetFocus(true, true)
end)

RegisterNetEvent('sunset:ui:jobObjective', function(data)
    if data and data.hide then
        Send('jobObjectiveHide', {})
    elseif data then
        Send('jobObjectiveShow', data)
    end
end)

RegisterNetEvent('sunset:ui:taxiMeter', function(data)
    if data and data.hide then
        Send('taxiMeterHide', {})
    elseif data then
        Send('taxiMeterUpdate', data)
    end
end)

-- NUI close handlers — release focus
local closePanels = {
    'mdcClose', 'ticketClose', 'serviceCallsClose', 'jobsClose', 'skillsClose', 'helpClose', 'factionPanelsClose', 'clanPanelsClose',
}
for _, name in ipairs(closePanels) do
    AddEventHandler('sunset:nui:' .. name, function()
        if name == 'mdcClose' then
            Send('mdcHide', {})
        elseif name == 'ticketClose' then
            Send('ticketHide', {})
        elseif name == 'serviceCallsClose' then
            Send('serviceCallsHide', {})
        elseif name == 'jobsClose' then
            Send('jobsHide', {})
        elseif name == 'skillsClose' then
            Send('skillsHide', {})
        elseif name == 'helpClose' then
            Send('helpHide', {})
        elseif name == 'factionPanelsClose' then
            Send('factionPanelsHide', {})
        elseif name == 'clanPanelsClose' then
            Send('clanPanelsHide', {})
        end
        ReleaseFocusUnlessModal()
    end)
end

AddEventHandler('sunset:nui:fleetGarageReady', function()
    SetFocus(true, true)
end)

AddEventHandler('sunset:nui:fleetGarageClose', function()
    Send('fleetGarageHide', {})
    SetFocus(false, false)
    TriggerEvent('sunset:world:uiModalClose')
end)

AddEventHandler('sunset:nui:fleetGarageSpawn', function()
    SetFocus(false, false)
    TriggerEvent('sunset:world:uiModalClose')
end)

AddEventHandler('sunset:nui:mdcSearch', function(data)
    TriggerEvent('sunset:ui:mdcSearchRequest', data)
end)

AddEventHandler('sunset:nui:mdcVehicleSearch', function(data)
    TriggerEvent('sunset:ui:mdcVehicleSearch', data)
end)

AddEventHandler('sunset:nui:mdcToggleBolo', function(data)
    TriggerEvent('sunset:ui:mdcToggleBolo', data)
end)

AddEventHandler('sunset:nui:mdcSetUnitStatus', function(data)
    TriggerEvent('sunset:ui:mdcSetUnitStatus', data)
end)

AddEventHandler('sunset:nui:mdcSetCallStatus', function(data)
    TriggerEvent('sunset:ui:mdcSetCallStatus', data)
end)

AddEventHandler('sunset:nui:mdcSetWaypoint', function(data)
    TriggerEvent('sunset:ui:mdcSetWaypoint', data)
end)

AddEventHandler('sunset:nui:mdcRequestBackup', function(data)
    TriggerEvent('sunset:ui:mdcRequestBackup', data)
end)

AddEventHandler('sunset:nui:mdcCancelBackup', function(data)
    TriggerEvent('sunset:ui:mdcCancelBackup', data)
end)

AddEventHandler('sunset:nui:mdcSetWanted', function(data)
    TriggerEvent('sunset:ui:mdcSetWanted', data)
end)

AddEventHandler('sunset:nui:mdcClearWanted', function(data)
    TriggerEvent('sunset:ui:mdcClearWanted', data)
end)

AddEventHandler('sunset:nui:mdcSummon', function(data)
    TriggerEvent('sunset:ui:mdcSummon', data)
end)

AddEventHandler('sunset:nui:mdcFindWanted', function(data)
    TriggerEvent('sunset:ui:mdcFindWanted', data)
end)

AddEventHandler('sunset:nui:mdcUnjail', function(data)
    TriggerEvent('sunset:ui:mdcUnjail', data)
end)

AddEventHandler('sunset:nui:mdcIssueCitation', function(data)
    TriggerEvent('sunset:ui:mdcIssueCitation', data)
end)

AddEventHandler('sunset:nui:mdcSuspendLicense', function(data)
    TriggerEvent('sunset:ui:mdcSuspendLicense', data)
end)

AddEventHandler('sunset:nui:mdcStartRadar', function(data)
    TriggerEvent('sunset:ui:mdcStartRadar', data)
end)

AddEventHandler('sunset:nui:mdcStopRadar', function(data)
    TriggerEvent('sunset:ui:mdcStopRadar', data)
end)

AddEventHandler('sunset:nui:mdcSetUnitWaypoint', function(data)
    TriggerEvent('sunset:ui:mdcSetUnitWaypoint', data)
end)

AddEventHandler('sunset:nui:mdcBookingGps', function(data)
    TriggerEvent('sunset:ui:mdcBookingGps', data)
end)

AddEventHandler('sunset:nui:phoneTrigger112', function()
    TriggerEvent('sunset:nui:phoneClose')
    Wait(150)
    ExecuteCommand('112')
end)

local function release112Focus()
    local phoneStillOpen = false
    if GetResourceState('sunset_phone') == 'started' then
        local ok, result = pcall(function()
            return exports.sunset_phone:IsPhoneOpen()
        end)
        phoneStillOpen = ok and result == true
    end
    SetFocus(phoneStillOpen, phoneStillOpen)
end

AddEventHandler('sunset:nui:close112Modal', function()
    Send('dispatch112Hide', {})
    release112Focus()
end)

AddEventHandler('sunset:nui:submit112Call', function(data)
    data = data or {}
    exports.sunset_core:TriggerCallback('sunset:dispatch:call112', function(res, err)
        if res and res.ok then
            exports.sunset_ui:Notify(('112 Dispatch: Emergency call registered at %s. Units notified.'):format(res.street or 'your location'), 'success', 8000)
        else
            exports.sunset_ui:Notify(err or 'Could not transmit 112 call.', 'error')
        end
    end, data.category, data.description, data.street, data.area, data.coords)
    Send('dispatch112Hide', {})
    release112Focus()
end)

AddEventHandler('sunset:nui:ticketPay', function(data)
    TriggerEvent('sunset:ui:ticketPayRequest', data)
end)

AddEventHandler('sunset:nui:ticketRefuse', function(data)
    TriggerEvent('sunset:ui:ticketRefuseRequest', data)
end)

AddEventHandler('sunset:nui:serviceCallsAccept', function(data)
    TriggerEvent('sunset:ui:serviceCallsAcceptRequest', data)
end)

AddEventHandler('sunset:nui:jobsSelect', function(data)
    TriggerEvent('sunset:ui:jobsSelectRequest', data)
end)

RegisterNetEvent('sunset:ui:radarAlert', function(data)
    Send('radarAlertShow', data or {})
end)
