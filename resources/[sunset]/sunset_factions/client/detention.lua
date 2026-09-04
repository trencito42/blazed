local isCuffed = false
local isEscorted = false
local escortOfficer = nil
local handsUp = false

local CUFF_DICT = 'mp_arresting'
local CUFF_ANIM = 'idle'
local HANDS_DICT = 'missminuteman_1ig_2'
local HANDS_ANIM = 'handsup_base'

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function applyCuffState(state)
    local changed = isCuffed ~= (state == true)
    isCuffed = state == true
    local ped = PlayerPedId()
    if isCuffed then
        SetEnableHandcuffs(ped, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        SetPedCanPlayGestureAnims(ped, false)
        if loadAnimDict(CUFF_DICT) then
            TaskPlayAnim(ped, CUFF_DICT, CUFF_ANIM, 8.0, -8.0, -1, 49, 0, false, false, false)
        end
        if changed then exports.sunset_ui:Notify('You have been restrained', 'error') end
    else
        SetEnableHandcuffs(ped, false)
        SetPedCanPlayGestureAnims(ped, true)
        isEscorted = false
        escortOfficer = nil
        DetachEntity(ped, true, false)
        if changed then
            ClearPedTasks(ped)
            exports.sunset_ui:Notify('Restraints removed', 'success')
        end
    end
end

RegisterNetEvent('sunset:faction:cuff', function()
    applyCuffState(true)
end)

CreateThread(function()
    Wait(1500)
    applyCuffState(LocalPlayer.state.sunsetCuffed == true)
end)

AddEventHandler('playerSpawned', function()
    Wait(500)
    applyCuffState(LocalPlayer.state.sunsetCuffed == true)
end)

RegisterNetEvent('sunset:faction:uncuff', function()
    applyCuffState(false)
end)

RegisterNetEvent('sunset:detention:sync', function(targetId, state)
    if targetId ~= GetPlayerServerId(PlayerId()) then return end
    if state.cuffed ~= nil then applyCuffState(state.cuffed) end
    if state.cuffed == false then
        isEscorted = false
        escortOfficer = nil
    end
end)

CreateThread(function()
    local wasInVehicle = false
    while true do
        if isCuffed then
            local ped = PlayerPedId()
            local inVehicle = IsPedInAnyVehicle(ped, false)
            if inVehicle ~= wasInVehicle then
                wasInVehicle = inVehicle
                TriggerServerEvent('sunset:server:detentionVehicleState', inVehicle)
            end
            Wait(500)
        else
            wasInVehicle = false
            Wait(800)
        end
    end
end)

RegisterNetEvent('sunset:detention:escort', function(officerServerId)
    if not officerServerId then
        isEscorted = false
        escortOfficer = nil
        DetachEntity(PlayerPedId(), true, false)
        return
    end
    isEscorted = true
    escortOfficer = officerServerId
end)

RegisterNetEvent('sunset:detention:escortOfficer', function(targetServerId)
    -- officer side marker only
end)

RegisterNetEvent('sunset:detention:putInVehicle', function(officerServerId)
    local ped = PlayerPedId()
    local officer = GetPlayerPed(GetPlayerFromServerId(officerServerId))
    local veh = officer ~= 0 and GetVehiclePedIsIn(officer, false) or 0
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 71)
    end
    if veh ~= 0 then
        for seat = 1, GetVehicleMaxNumberOfPassengers(veh) do
            if IsVehicleSeatFree(veh, seat) then
                TaskWarpPedIntoVehicle(ped, veh, seat)
                break
            end
        end
    end
    isEscorted = false
end)

RegisterNetEvent('sunset:detention:takeOutVehicle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
end)

RegisterNetEvent('sunset:detention:handsUp', function(serverId, state)
    if serverId ~= GetPlayerServerId(PlayerId()) then return end
    handsUp = state == true
    local ped = PlayerPedId()
    if handsUp and loadAnimDict(HANDS_DICT) then
        TaskPlayAnim(ped, HANDS_DICT, HANDS_ANIM, 8.0, -8.0, -1, 49, 0, false, false, false)
    elseif not isCuffed then
        ClearPedTasks(ped)
    end
end)

RegisterCommand('handsup', function()
    handsUp = not handsUp
    TriggerServerEvent('sunset:server:handsUp', handsUp)
    local ped = PlayerPedId()
    if handsUp and loadAnimDict(HANDS_DICT) then
        TaskPlayAnim(ped, HANDS_DICT, HANDS_ANIM, 8.0, -8.0, -1, 49, 0, false, false, false)
    elseif not isCuffed then
        ClearPedTasks(ped)
    end
end, false)

RegisterKeyMapping('handsup', 'Hands Up', 'keyboard', 'X')

local function detentionCmd(name, callbackName, usage)
    RegisterCommand(name, function(_, args)
        local target = tonumber(args[1])
        if not target then return exports.sunset_ui:Notify(usage, 'error') end
        local ok, err = Sunset.AwaitCallback(callbackName, target)
        if ok == nil and err then exports.sunset_ui:Notify(err, 'error') end
    end, false)
end

detentionCmd('escort', 'sunset:detentionEscort', 'Usage: /escort [id]')
detentionCmd('drag', 'sunset:detentionEscort', 'Usage: /drag [id]')
detentionCmd('putinveh', 'sunset:detentionPutInVehicle', 'Usage: /putinveh [id]')
detentionCmd('takeout', 'sunset:detentionTakeOut', 'Usage: /takeout [id]')

RegisterCommand('frisk', function(_, args)
    local target = tonumber(args[1])
    if not target then return exports.sunset_ui:Notify('Usage: /frisk [id]', 'error') end
    local items, err = Sunset.AwaitCallback('sunset:detentionFrisk', target)
    if not items then return exports.sunset_ui:Notify(err or 'Frisk failed. Check duty, rank, target ID and 3m distance.', 'error') end
    exports.sunset_ui:Send('chatMessage', { id = 0, name = 'FRI SK', message = ('=== Frisk #%d ==='):format(target), time = '' })
    if #items == 0 then
        exports.sunset_ui:Send('chatMessage', { id = 0, name = 'FRI SK', message = 'No items found', time = '' })
        return
    end
    for _, row in ipairs(items) do
        exports.sunset_ui:Send('chatMessage', { id = 0, name = 'FRI SK', message = ('%s x%d'):format(row.label or row.item, row.count), time = '' })
    end
end, false)

CreateThread(function()
    while true do
        if isCuffed or handsUp then
            local ped = PlayerPedId()
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
            if IsPedInAnyVehicle(ped, false) then
                DisableControlAction(0, 75, true)
                DisableControlAction(0, 23, true)
            end
            if isCuffed and not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped)
                and not IsEntityPlayingAnim(ped, CUFF_DICT, CUFF_ANIM, 3) and loadAnimDict(CUFF_DICT) then
                TaskPlayAnim(ped, CUFF_DICT, CUFF_ANIM, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if isEscorted and escortOfficer then
            local ped = PlayerPedId()
            local officerIdx = GetPlayerFromServerId(escortOfficer)
            if officerIdx ~= -1 then
                local officerPed = GetPlayerPed(officerIdx)
                if officerPed ~= 0 then
                    AttachEntityToEntity(ped, officerPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

exports('IsCuffedLocal', function() return isCuffed end)
exports('IsHandsUp', function() return handsUp end)
