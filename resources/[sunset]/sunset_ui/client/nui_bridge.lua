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
forward('inventoryClose')
forward('inventoryUse')
forward('shopBuy')
forward('shopClose')
forward('atmAction')
forward('atmClose')
forward('mdcClose')
forward('mdcSearch')
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
forward('garageSpawn')
forward('garageStore')
forward('garageLocate')
forward('garageClose')
forward('propertiesClose')
forward('emotePlay')
forward('emotesClose')
forward('clothingApply')
forward('clothingPreview')
forward('clothingClose')
forward('phoneClose')
forward('phoneSend')
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
forward('jobsClose')
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
    'mdcClose', 'ticketClose', 'serviceCallsClose', 'jobsClose', 'skillsClose', 'helpClose',
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
        end
        SetFocus(false, false)
    end)
end

AddEventHandler('sunset:nui:mdcSearch', function(data)
    TriggerEvent('sunset:ui:mdcSearchRequest', data)
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
