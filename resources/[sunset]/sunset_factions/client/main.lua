local onDuty = false
local myFaction = nil
local illegalBlip = nil
local fleetVehicle = nil
local isCuffed = false

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
    local factionId = Sunset.GetCharacterFaction(char)
    local faction = factionId and Sunset.Factions[factionId]
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

local function getServerJobInfo()
    local info = Sunset.AwaitCallback('sunset:getFactionPanel')
    if info and info.job then return info end
    local char = exports.sunset_core:GetCharacter()
    return { job = char and char.job or 'unemployed', label = 'Unknown', onDuty = onDuty }
end

local function deleteFleetVehicle()
    if fleetVehicle and DoesEntityExist(fleetVehicle) then
        SetEntityAsMissionEntity(fleetVehicle, true, true)
        DeleteVehicle(fleetVehicle)
    end
    fleetVehicle = nil
end

local function spawnFleetVehicle(depot, factionId)
    if not depot or not depot.spawn then
        exports.sunset_ui:Notify('No fleet garage configured', 'error')
        return
    end

    local char = exports.sunset_core:GetCharacter()
    local myFaction = char and Sunset.GetCharacterFaction(char)
    if not myFaction or myFaction ~= factionId then
        exports.sunset_ui:Notify('You do not work here', 'error')
        return
    end
    if not exports.sunset_factions:IsOnDuty() then
        exports.sunset_ui:Notify('Go on duty at HQ first ([E])', 'error')
        return
    end

    local authorized, err = Sunset.AwaitCallback('sunset:factionRequestFleet', factionId)
    if not authorized then
        exports.sunset_ui:Notify(err or 'Fleet request denied', 'error')
        return
    end

    deleteFleetVehicle()

    local model = joaat(authorized.vehicle or depot.vehicle or 'sultan')
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            exports.sunset_ui:Notify('Failed to load vehicle model', 'error')
            return
        end
        Wait(10)
    end

    local s = depot.spawn
    local veh = CreateVehicle(model, s.x, s.y, s.z, s.w, true, false)
    if veh == 0 then
        SetModelAsNoLongerNeeded(model)
        exports.sunset_ui:Notify('Could not spawn vehicle — clear the area', 'error')
        return
    end

    local prefix = authorized.platePrefix or depot.platePrefix or 'SUN'
    SetVehicleNumberPlateText(veh, prefix .. math.random(100, 999))
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(model)

    fleetVehicle = veh
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    exports.sunset_ui:Notify((depot.label or 'Fleet') .. ' vehicle ready', 'success')
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
    local faction = job and Sunset.Factions[job]
    local label = faction and faction.label or 'Faction'
    exports.sunset_ui:Notify(onDuty and ('ON DUTY — ' .. label) or ('OFF DUTY — ' .. label), onDuty and 'success' or 'info')
end)

function IsOnDutyLocal()
    return onDuty
end
exports('IsOnDuty', function() return onDuty end)

local function blocked()
    return IsNuiFocused()
end

RegisterCommand('leavefaction', function()
    local ok, err = Sunset.AwaitCallback('sunset:leaveFaction')
    if ok then
        deleteFleetVehicle()
        refreshIllegalBlip()
    else
        exports.sunset_ui:Notify(err or 'Could not leave faction', 'error')
    end
end, false)

RegisterCommand('quitgroup', function()
    ExecuteCommand('leavefaction')
end, false)

RegisterCommand('duty', function()
    if blocked() then return end
    local state, err = Sunset.AwaitCallback('sunset:toggleDuty')
    if state == nil then exports.sunset_ui:Notify(err or 'Cannot toggle duty', 'error') end
end, false)

RegisterCommand('fine', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:policeFine', tonumber(args[1]), tonumber(args[2]), table.concat(args, ' ', 3))
    if ok then exports.sunset_ui:Notify('Fine issued', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('cuff', function(_, args)
    local target = tonumber(args[1])
    if not target then return exports.sunset_ui:Notify('Usage: /cuff [id]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:detentionCuff', target)
    if not ok then exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('uncuff', function(_, args)
    local target = tonumber(args[1])
    if not target then return exports.sunset_ui:Notify('Usage: /uncuff [id]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:detentionUncuff', target)
    if not ok then exports.sunset_ui:Notify(err or 'Failed', 'error') end
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
    SetVehicleDirtLevel(veh, 0.0)
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

RegisterCommand('fpromote', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionPromote', tonumber(args[1]), tonumber(args[2]))
    if ok then exports.sunset_ui:Notify('Member promoted', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('fgiverank', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionGiveRank', tonumber(args[1]), tonumber(args[2]))
    if ok then exports.sunset_ui:Notify('Rank updated', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('funinvite', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionUninvite', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify('Member removed', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('fwarn', function(_, args)
    local target = tonumber(args[1])
    local reason = table.concat(args, ' ', 2)
    if not target or reason == '' then return exports.sunset_ui:Notify('Usage: /fwarn [id] [reason]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:factionWarn', target, reason)
    if ok then exports.sunset_ui:Notify('Warning issued', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('fmotd', function(_, args)
    local msg = table.concat(args, ' ')
    if msg == '' then return exports.sunset_ui:Notify('Usage: /fmotd [message]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:factionSetMotd', msg)
    if ok then exports.sunset_ui:Notify('Faction MOTD updated', 'success')
    else exports.sunset_ui:Notify(err or 'Failed', 'error') end
end, false)

RegisterCommand('fmembers', function()
    local data, err = Sunset.AwaitCallback('sunset:factionMembers')
    if not data then return exports.sunset_ui:Notify(err or 'Failed', 'error') end
    local chat = function(line)
        exports.sunset_ui:Send('chatMessage', { id = 0, name = 'FACTION', message = line, time = '' })
    end
    chat('=== Faction Members (online) ===')
    if data.motd and data.motd ~= '' then chat('MOTD: ' .. data.motd) end
    for _, m in ipairs(data.members or {}) do
        chat(('#%d %s — %s%s%s'):format(
            m.id, m.name, m.gradeLabel,
            m.onDuty and ' [ON DUTY]' or '',
            m.leader and ' [LEADER]' or ''))
    end
end, false)

RegisterCommand('sellpouch', function()
    local ok, err = Sunset.AwaitCallback('sunset:illegalSell')
    if ok then exports.sunset_ui:Notify(('Sold for $%s'):format(ok.total or 0), 'success')
    else exports.sunset_ui:Notify(err or 'Sale failed', 'error') end
end, false)

RegisterCommand('fence', function()
    local ok, err = Sunset.AwaitCallback('sunset:illegalSell')
    if ok then exports.sunset_ui:Notify(('Fenced for $%s'):format(ok.total or 0), 'success')
    else exports.sunset_ui:Notify(err or 'Fence failed', 'error') end
end, false)

local function showFactionInfo(data)
    if not data.isFaction and not data.description then
        exports.sunset_ui:Notify('You are not in a faction. Join at an HQ (LSPD, EMS, Taxi...) or get a civilian job at the Job Center.', 'info', 8000)
        return
    end

    local function chat(line)
        exports.sunset_ui:Send('chatMessage', { id = 0, name = 'FACTION', message = line, time = '' })
    end

    chat(('=== %s ==='):format(data.label))
    if data.description and data.description ~= '' then chat(data.description) end
    chat(('Rank: %s | %s | $%s/hr'):format(data.gradeLabel or data.grade, data.onDuty and 'ON DUTY' or 'OFF DUTY', data.salary or 0))
    if data.depot then chat('Fleet garage: ' .. data.depot) end
    if data.commands and #data.commands > 0 then
        chat('Your commands:')
        for _, row in ipairs(data.commands) do
            chat(row.cmd .. ' — ' .. (row.desc or ''))
        end
    end
end

RegisterCommand('faction', function()
    local data = Sunset.AwaitCallback('sunset:getFactionPanel')
    if not data then return end
    showFactionInfo(data)
end, false)

AddEventHandler('sunset:world:factionHQ', function(factionId, faction)
    if blocked() then return end
    local label = faction.label or factionId
    local ped = PlayerPedId()
    local char = exports.sunset_core:GetCharacter()
    local myFaction = char and Sunset.GetCharacterFaction(char)

    if factionId == 'mechanic' and IsPedInAnyVehicle(ped, false) then
        local ok, err = Sunset.AwaitCallback('sunset:mechanicShopRepair')
        if ok then
            local veh = GetVehiclePedIsIn(ped, false)
            SetVehicleFixed(veh)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 1000.0)
            SetVehicleDirtLevel(veh, 0.0)
            exports.sunset_ui:Notify('Vehicle repaired at LS Customs ($250)', 'success')
        else
            exports.sunset_ui:Notify(err or 'Repair failed', 'error')
        end
        return
    end

    if myFaction == factionId then
        ExecuteCommand('duty')
        return
    end

    if myFaction then
        local myLabel = Sunset.Factions[myFaction] and Sunset.Factions[myFaction].label or myFaction
        exports.sunset_ui:Notify(
            ('You are in %s. Use /leavefaction first to join %s.'):format(myLabel, label),
            'warning', 9000)
        return
    end

    local ok, err = Sunset.AwaitCallback('sunset:joinFactionHQ', factionId)
    if ok then
        exports.sunset_ui:Notify('Joined ' .. label .. ' — you are ON DUTY. Use /duty to toggle shift.', 'success')
        refreshIllegalBlip()
    else
        exports.sunset_ui:Notify(err or 'Could not join', 'error')
    end
end)

AddEventHandler('sunset:world:factionDepot', function(factionId, depot)
    if factionId == 'taxi' then
        TriggerEvent('sunset:world:taxiDepot')
        return
    end
    spawnFleetVehicle(depot, factionId)
end)

AddEventHandler('sunset:world:illegalSell', function(factionId)
    local char = exports.sunset_core:GetCharacter()
    if not char or Sunset.GetCharacterFaction(char) ~= factionId then
        exports.sunset_ui:Notify('Members only', 'error')
        return
    end
    if factionId == 'sunset_cartel' then
        ExecuteCommand('sellpouch')
    else
        ExecuteCommand('fence')
    end
end)

CreateThread(function()
    Wait(3000)
    for id, faction in pairs(Sunset.Factions or {}) do
        if faction.hq then
            TriggerEvent('sunset:world:registerFactionHQ', id, faction)
        end
        if faction.depot and id ~= 'taxi' then
            TriggerEvent('sunset:world:registerFactionDepot', id, faction.depot, faction)
        end
        if faction.stash and faction.type == 'illegal' then
            TriggerEvent('sunset:world:registerIllegalSell', id, faction.stash, faction)
        end
    end

    TriggerEvent('chat:addSuggestion', '/duty', 'Toggle faction duty shift')
    TriggerEvent('chat:addSuggestion', '/faction', 'Show faction info and your commands')
    TriggerEvent('chat:addSuggestion', '/leavefaction', 'Leave your faction; keeps your civilian job')
    TriggerEvent('chat:addSuggestion', '/quitgroup', 'Same as /leavefaction; keeps your civilian job')
    TriggerEvent('chat:addSuggestion', '/f', 'Faction chat', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/r', 'On-duty faction radio', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/d', 'Law enforcement dispatch', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/service', 'Request emergency/service dispatch', {
        { name = 'type', help = 'taxi|medic|fire|mechanic' },
        { name = 'message', help = 'optional details' },
    })
    TriggerEvent('chat:addSuggestion', '/gov', 'Government channel', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/finvite', 'Recruit player', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/funinvite', 'Remove member', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/fgiverank', 'Set member rank', { { name = 'id' }, { name = 'grade' } })
    TriggerEvent('chat:addSuggestion', '/fwarn', 'Faction warning', { { name = 'id' }, { name = 'reason' } })
    TriggerEvent('chat:addSuggestion', '/fmembers', 'List online faction members')
    TriggerEvent('chat:addSuggestion', '/fmotd', 'Set faction MOTD', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/fine', 'Issue fine (PD)', { { name = 'id' }, { name = 'amount' }, { name = 'reason' } })
    TriggerEvent('chat:addSuggestion', '/cuff', 'Cuff player (PD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/uncuff', 'Uncuff player (PD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/heal', 'Treat injuries (EMS/LSFD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/stabilize', 'Stabilize downed patient (EMS/LSFD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/revive', 'Revive downed player (EMS/LSFD)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/repairveh', 'Repair vehicle (Mechanic)', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/fare', 'Collect taxi fare', { { name = 'id' }, { name = 'amount' } })
    TriggerEvent('chat:addSuggestion', '/sellpouch', 'Sell sealed pouch at Cartel HQ')
    TriggerEvent('chat:addSuggestion', '/fence', 'Fence contraband at Syndicate HQ')
    TriggerEvent('chat:addSuggestion', '/pd', 'LSPD commands and help')
    TriggerEvent('chat:addSuggestion', '/pdgarage', 'Spawn MRPD patrol car (on duty)')
end)

local PD_HELP = {
    '=== LSPD (on duty) ===',
    '/duty — Toggle shift (uniform + gear when ON)',
    '/pdgarage — Spawn patrol car at MRPD garage',
    '[E] at MRPD garage marker — same as /pdgarage',
    '[E] at LSPD Armory inside MRPD — craft bandages (on duty)',
    '/su [id] [reason] — Set wanted (type /su for reason codes)',
    '/so [id] — Summon suspect (must be nearby)',
    '/clear [id] — Clear wanted status',
    '/wanted — List active wanted (persisted)',
    '/arrest [id] — Arrest at jail zone (restrained)',
    '/cuff [id] — Restrain suspect',
    '/uncuff [id] — Release (Sergeant+)',
    '/fine [id] [amount] [reason] — Citation (Officer+)',
    '/ticket — Issue citation (UI)',
    '/mdc — Mobile data terminal',
    '/confiscate [id] — Confiscate contraband',
    '/startradar — Activate speed radar',
    '/stopradar — Deactivate speed radar',
    '/radars — List fixed speed cameras',
    '/f [msg] — Faction radio',
    '/faction — Your rank, salary, commands',
    'Payday: every hour at :00 — must be ON DUTY — $400+ to bank',
}

RegisterCommand('pd', function()
    for _, line in ipairs(PD_HELP) do
        exports.sunset_ui:Send('chatMessage', { id = 0, name = 'LSPD', message = line, time = '' })
    end
end, false)

RegisterCommand('pdgarage', function()
    local char = exports.sunset_core:GetCharacter()
    local factionId = char and Sunset.GetCharacterFaction(char)
    if not factionId or not Sunset.FactionTypeMatches(factionId, 'law_enforcement') then
        return exports.sunset_ui:Notify('You must be law enforcement', 'error')
    end
    if not exports.sunset_factions:IsOnDuty() then
        return exports.sunset_ui:Notify('Go on duty first (/duty at MRPD)', 'error')
    end
    local faction = Sunset.Factions.police
    if faction and faction.depot then
        spawnFleetVehicle(faction.depot, 'police')
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearIllegalBlip()
    deleteFleetVehicle()
end)
