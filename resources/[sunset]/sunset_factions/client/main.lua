local onDuty = false
local myFaction = nil
local illegalBlip = nil

local function clearIllegalBlip()
    if illegalBlip and DoesBlipExist(illegalBlip) then
        RemoveBlip(illegalBlip)
    end
    illegalBlip = nil
end

local function refreshIllegalBlip()
    clearIllegalBlip()
    local char = exports.sunset_core:GetCharacter()
    if not char then return end
    local faction = Sunset.Factions and Sunset.Factions[char.job]
    if not faction or faction.type ~= 'illegal' or not faction.hq or not faction.blip then return end
    illegalBlip = AddBlipForCoord(faction.hq.x, faction.hq.y, faction.hq.z)
    SetBlipSprite(illegalBlip, faction.blip.sprite or 84)
    SetBlipColour(illegalBlip, faction.blip.color or 1)
    SetBlipScale(illegalBlip, faction.blip.scale or 0.8)
    SetBlipAsShortRange(illegalBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(faction.label .. ' HQ')
    EndTextCommandSetBlipName(illegalBlip)
end

RegisterNetEvent('sunset:client:updateCharacter', function()
    refreshIllegalBlip()
end)

RegisterNetEvent('sunset:client:characterLoaded', function()
    refreshIllegalBlip()
end)

RegisterNetEvent('sunset:client:dutyState', function(state, job)
    onDuty = state == true
    myFaction = job
    exports.sunset_ui:Notify(state and 'ON DUTY' or 'OFF DUTY', state and 'success' or 'info')
end)

function IsOnDutyLocal()
    return onDuty
end
exports('IsOnDuty', function() return onDuty end)

local function blocked()
    return IsNuiFocused()
end

RegisterCommand('duty', function()
    if blocked() then return end
    local state, err = Sunset.AwaitCallback('sunset:toggleDuty')
    if state == nil then exports.sunset_ui:Notify(err or 'Cannot toggle duty', 'error') end
end, false)

RegisterCommand('leavefaction', function()
    local ok, err = Sunset.AwaitCallback('sunset:leaveFaction')
    if ok then exports.sunset_ui:Notify('You left your faction', 'warning')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('fine', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:policeFine', tonumber(args[1]), tonumber(args[2]), table.concat(args, ' ', 3))
    if ok then exports.sunset_ui:Notify('Fine issued', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('cuff', function(_, args)
    local target = tonumber(args[1])
    if not target then return exports.sunset_ui:Notify('Usage: /cuff [id]', 'error') end
    TriggerServerEvent('sunset:server:factionCmd', 'cuff', target)
end, false)

RegisterNetEvent('sunset:faction:cuff', function()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    exports.sunset_ui:Notify('You have been cuffed', 'error')
    SetTimeout(15000, function() FreezeEntityPosition(PlayerPedId(), false) end)
end)

RegisterCommand('heal', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionHeal', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify('Patient healed', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('revive', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionRevive', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify('Patient revived', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('repairveh', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:mechanicRepair', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify('Vehicle repaired', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterNetEvent('sunset:faction:repairVehicle', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local veh = GetVehiclePedIsIn(ped, false)
    SetVehicleFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
end)

RegisterCommand('fare', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:taxiFare', tonumber(args[1]), tonumber(args[2]))
    if ok then exports.sunset_ui:Notify('Fare collected', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('finvite', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionInvite', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify('Member recruited', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('faction', function()
    local data = Sunset.AwaitCallback('sunset:getFactionPanel')
    if not data then return end
    exports.sunset_ui:Notify(('%s | %s | Grade %s | %s | $%s/hr'):format(
        data.label, data.type or '—', data.gradeLabel or data.grade,
        data.onDuty and 'ON DUTY' or 'OFF DUTY', data.salary or 0
    ), 'info', 8000)
end, false)

AddEventHandler('sunset:world:factionHQ', function(factionId, faction)
    if blocked() then return end
    local char = exports.sunset_core:GetCharacter()
    if not char then return end

    if char.job == factionId then
        ExecuteCommand('duty')
        return
    end

    if char.job ~= 'unemployed' then
        exports.sunset_ui:Notify('Leave your faction first (/leavefaction)', 'error')
        return
    end

    local ok, err = Sunset.AwaitCallback('sunset:joinFactionHQ', factionId)
    if ok then
        exports.sunset_ui:Notify('Welcome to ' .. (faction.label or factionId) .. ' — return to HQ for /duty', 'success')
        refreshIllegalBlip()
    else
        exports.sunset_ui:Notify(err or 'Could not join', 'error')
    end
end)

CreateThread(function()
    Wait(3000)
    for id, faction in pairs(Sunset.Factions or {}) do
        if faction.hq then
            TriggerEvent('sunset:world:registerFactionHQ', id, faction)
        end
    end

    TriggerEvent('chat:addSuggestion', '/duty', 'Toggle faction duty shift')
    TriggerEvent('chat:addSuggestion', '/faction', 'Show faction info')
    TriggerEvent('chat:addSuggestion', '/leavefaction', 'Leave your faction')
    TriggerEvent('chat:addSuggestion', '/f', 'Faction chat', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/finvite', 'Recruit player', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/fine', 'Issue fine (PD)', { { name = 'id' }, { name = 'amount' }, { name = 'reason' } })
    TriggerEvent('chat:addSuggestion', '/cuff', 'Cuff player (PD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/heal', 'Heal player (EMS)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/revive', 'Revive player (EMS)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/repairveh', 'Repair vehicle (Mechanic)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/fare', 'Collect taxi fare', { { name = 'id' }, { name = 'amount' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearIllegalBlip()
end)
