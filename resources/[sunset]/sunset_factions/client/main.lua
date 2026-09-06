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
    Wait(0)
    TriggerServerEvent('sunset:factionRegisterFleetVehicle', NetworkGetNetworkIdFromEntity(veh), factionId)
    exports.sunset_ui:Notify((depot.label or 'Fleet') .. ' vehicle ready', 'success')
end

RegisterNetEvent('sunset:client:updateCharacter', function()
    refreshIllegalBlip()
end)

RegisterNetEvent('sunset:client:characterLoaded', function()
    refreshIllegalBlip()
end)

RegisterNetEvent('sunset:client:dutyState', function(state, job, silent)
    onDuty = state == true
    myFaction = job
    if silent then return end
    local faction = job and Sunset.Factions[job]
    if not faction or faction.duty ~= true then return end
    local label = faction.label or 'Faction'
    exports.sunset_ui:Notify(onDuty and ('ON DUTY — ' .. label) or ('OFF DUTY — ' .. label), onDuty and 'success' or 'info')
end)

function IsOnDutyLocal()
    return onDuty
end
exports('IsOnDuty', function() return onDuty end)

local fleetAccessWarningAt = 0
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local current = GetVehiclePedIsIn(ped, false)
        local entering = GetVehiclePedIsTryingToEnter(ped)
        local vehicle = current ~= 0 and current or entering
        local wait = 500

        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            local restrictedTo = Entity(vehicle).state.sunsetFactionVehicle
            if restrictedTo then
                wait = 100
                local char = exports.sunset_core:GetCharacter()
                local factionId = char and Sunset.GetCharacterFaction(char)
                local allowed = factionId == restrictedTo
                SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), not allowed)
                if not allowed then
                    if current == vehicle then
                        TaskLeaveVehicle(ped, vehicle, 16)
                    else
                        ClearPedTasks(ped)
                    end
                    local now = GetGameTimer()
                    if now >= fleetAccessWarningAt then
                        fleetAccessWarningAt = now + 4000
                        local faction = Sunset.Factions and Sunset.Factions[restrictedTo]
                        exports.sunset_ui:Notify(
                            ('This vehicle is reserved for %s members.'):format(faction and faction.label or restrictedTo),
                            'error', 6000)
                    end
                end
            end
        end
        Wait(wait)
    end
end)

local function blocked()
    return IsNuiFocused()
end

local function leaveFactionCommand()
    local ok, err = Sunset.AwaitCallback('sunset:leaveFaction')
    if ok then
        onDuty = false
        myFaction = nil
        deleteFleetVehicle()
        refreshIllegalBlip()
    else
        exports.sunset_ui:Notify(err or 'Could not leave faction', 'error')
    end
end

RegisterCommand('leavefaction', leaveFactionCommand, false)
RegisterCommand('quitfaction', leaveFactionCommand, false)
RegisterCommand('factionquit', leaveFactionCommand, false)

RegisterCommand('quitgroup', function()
    leaveFactionCommand()
end, false)

RegisterCommand('duty', function()
    if blocked() then return end
    local state, err = Sunset.AwaitCallback('sunset:toggleDuty')
    if state == nil then exports.sunset_ui:Notify(err or 'Cannot toggle duty', 'error') end
end, false)

RegisterCommand('fine', function(_, args)
    local target = tonumber(args[1])
    ExecuteCommand(target and ('ticket %d'):format(target) or 'ticket')
end, false)

RegisterCommand('cuff', function(_, args)
    local target = tonumber(args[1])
    if not target then return exports.sunset_ui:Notify('Usage: /cuff [id]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:detentionCuff', target)
    if not ok then exports.sunset_ui:Notify(err or 'Could not cuff the suspect. Check duty, rank, ID and distance.', 'error') end
end, false)

RegisterCommand('uncuff', function(_, args)
    local target = tonumber(args[1])
    if not target then return exports.sunset_ui:Notify('Usage: /uncuff [id]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:detentionUncuff', target)
    if not ok then exports.sunset_ui:Notify(err or 'Could not remove the cuffs. Check duty, rank, ID and distance.', 'error') end
end, false)

RegisterCommand('repairveh', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:mechanicRepair', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify('Vehicle repaired', 'success')
    else exports.sunset_ui:Notify(err or 'Repair could not start. Check duty, rank, distance and that the target is in a vehicle.', 'error') end
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
    else exports.sunset_ui:Notify(err or 'Fare could not be charged. Check duty, passenger ID, distance, amount and funds.', 'error') end
end, false)

RegisterCommand('finvite', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionInvite', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify(('%s was invited to %s and has %d seconds to accept.'):format(ok.target, ok.label, ok.expiresIn), 'success', 8000)
    else exports.sunset_ui:Notify(err or 'Recruitment failed. Check your leader permission and the target ID.', 'error') end
end, false)

RegisterNetEvent('sunset:faction:inviteReceived', function(invite)
    exports.sunset_ui:Notify(
        ('%s invited you to %s. Use /acceptfaction or /declinefaction within %d seconds.'):format(
            invite.leader or 'The leader', invite.label or 'a faction', invite.expiresIn or 120),
        'info', 12000)
    exports.sunset_ui:Send('chatMessage', {
        id = 0, type = 'faction_info', name = 'FACTION INVITATION',
        message = ('%s invited you to %s. Type /acceptfaction to join or /declinefaction to refuse.'):format(
            invite.leader or 'The leader', invite.label or 'a faction'), time = '',
    })
end)

local function acceptFactionInvite()
    local result, err = Sunset.AwaitCallback('sunset:factionAcceptInvite')
    if not result then return exports.sunset_ui:Notify(err or 'The faction invitation could not be accepted.', 'error', 8000) end
    exports.sunset_ui:Notify(('You joined %s. Your civilian job is unchanged. Go to HQ and press E to start duty.'):format(result.label), 'success', 10000)
    refreshIllegalBlip()
end

RegisterCommand('acceptfaction', acceptFactionInvite, false)
RegisterCommand('accept', function(_, args)
    if string.lower(tostring(args[1] or '')) ~= 'faction' then
        return exports.sunset_ui:Notify('Usage: /accept faction', 'error')
    end
    acceptFactionInvite()
end, false)

RegisterCommand('declinefaction', function()
    local ok, err = Sunset.AwaitCallback('sunset:factionDeclineInvite')
    if ok then exports.sunset_ui:Notify('Faction invitation declined.', 'info')
    else exports.sunset_ui:Notify(err or 'The faction invitation could not be declined.', 'error') end
end, false)

RegisterCommand('fpromote', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionPromote', tonumber(args[1]), tonumber(args[2]))
    if ok then exports.sunset_ui:Notify('Member promoted', 'success')
    else exports.sunset_ui:Notify(err or 'Promotion failed. Check your leader permission, target ID and grade.', 'error') end
end, false)

RegisterCommand('fgiverank', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionGiveRank', tonumber(args[1]), tonumber(args[2]))
    if ok then exports.sunset_ui:Notify('Rank updated', 'success')
    else exports.sunset_ui:Notify(err or 'Rank change failed. Check your leader permission, target ID and grade.', 'error') end
end, false)

RegisterCommand('funinvite', function(_, args)
    local ok, err = Sunset.AwaitCallback('sunset:factionUninvite', tonumber(args[1]))
    if ok then exports.sunset_ui:Notify('Member removed', 'success')
    else exports.sunset_ui:Notify(err or 'Member removal failed. Check your leader permission and target ID.', 'error') end
end, false)

RegisterCommand('fwarn', function(_, args)
    local target = tonumber(args[1])
    local reason = table.concat(args, ' ', 2)
    if not target or reason == '' then return exports.sunset_ui:Notify('Usage: /fwarn [id] [reason]', 'error') end
    local ok, err = Sunset.AwaitCallback('sunset:factionWarn', target, reason)
    if ok then exports.sunset_ui:Notify('Warning issued', 'success')
    else exports.sunset_ui:Notify(err or 'Faction warning failed. Check your leader permission, target ID and reason.', 'error') end
end, false)

RegisterCommand('fmotd', function(_, args)
    local msg = table.concat(args, ' ')
    if msg == '' then
        local data, err = Sunset.AwaitCallback('sunset:factionGetMotd')
        if not data then return exports.sunset_ui:Notify(err or 'Faction MOTD could not be loaded.', 'error') end
        exports.sunset_ui:Send('chatMessage', {
            id = 0, type = 'faction_info', name = (data.label or 'FACTION') .. ' MOTD',
            message = data.message ~= '' and data.message or 'No message of the day has been set.', time = '',
        })
        return
    end
    local ok, err = Sunset.AwaitCallback('sunset:factionSetMotd', msg)
    if ok then exports.sunset_ui:Notify('Faction MOTD updated', 'success')
    else exports.sunset_ui:Notify(err or 'MOTD update failed. Check your faction permission and message.', 'error') end
end, false)

RegisterCommand('fmembers', function()
    local data, err = Sunset.AwaitCallback('sunset:factionMembers')
    if not data then return exports.sunset_ui:Notify(err or 'Faction members could not be loaded. Check your membership and try again.', 'error') end
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

RegisterCommand('faction', function()
    local data, err = Sunset.AwaitCallback('sunset:factionDashboard')
    if not data then return exports.sunset_ui:Notify(err or 'Faction panel could not be opened.', 'error', 7000) end
    exports.sunset_ui:Send('factionPanelShow', data)
    exports.sunset_ui:SetFocus(true, true)
end, false)

RegisterCommand('factions', function()
    local data, err = Sunset.AwaitCallback('sunset:factionDirectory')
    if not data then return exports.sunset_ui:Notify(err or 'Faction directory could not be opened.', 'error', 7000) end
    exports.sunset_ui:Send('factionDirectoryShow', { factions = data })
    exports.sunset_ui:SetFocus(true, true)
end, false)

AddEventHandler('sunset:nui:factionManage', function(data)
    data = data or {}
    local action = data.action
    local ok, err

    if action == 'invite' then
        ok, err = Sunset.AwaitCallback('sunset:factionInvite', tonumber(data.targetId))
        if ok then
            exports.sunset_ui:Notify(('%s was invited to %s.'):format(ok.target, ok.label), 'success', 8000)
        end
    elseif action == 'motd' then
        ok, err = Sunset.AwaitCallback('sunset:factionSetMotd', data.message)
        if ok then exports.sunset_ui:Notify('Faction MOTD updated.', 'success') end
    elseif action == 'rankDelta' then
        ok, err = Sunset.AwaitCallback('sunset:factionMemberRankDelta', tonumber(data.characterId), tonumber(data.delta))
        if ok then exports.sunset_ui:Notify(('Rank updated to %s.'):format(ok.gradeLabel or '?'), 'success') end
    elseif action == 'kick' then
        ok, err = Sunset.AwaitCallback('sunset:factionMemberKick', tonumber(data.characterId), data.mode or 'online')
        if ok then
            local msg = ok.offline and 'Offline member removed.' or 'Member removed from faction.'
            exports.sunset_ui:Notify(msg, 'success')
        end
    elseif action == 'gradeLabels' then
        ok, err = Sunset.AwaitCallback('sunset:factionSetGradeLabels', data.labels or {})
        if ok then exports.sunset_ui:Notify('Rank names saved.', 'success') end
    else
        return exports.sunset_ui:Notify('Unknown faction action.', 'error')
    end

    if not ok then
        return exports.sunset_ui:Notify(err or 'Faction action failed.', 'error', 8000)
    end

    local dashboard, dashErr = Sunset.AwaitCallback('sunset:factionDashboard')
    if dashboard then
        exports.sunset_ui:Send('factionPanelShow', dashboard)
    elseif dashErr then
        exports.sunset_ui:Notify(dashErr, 'error', 7000)
    end
end)

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
        return exports.sunset_ui:Notify(('You are a member of %s; this is %s HQ.'):format(myLabel, label), 'warning', 7000)
    end

    exports.sunset_ui:Notify(
        faction.applicationsOpen
            and ('%s recruitment uses applications on Discord/the website. After acceptance, the leader invites you in-game.'):format(label)
            or ('%s is not accepting public applications. Only its leader can invite members.'):format(label),
        'info', 10000)
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
    TriggerEvent('chat:addSuggestion', '/faction', 'Open your faction dashboard, roster and weekly report')
    TriggerEvent('chat:addSuggestion', '/factions', 'Browse every server faction and application status')
    TriggerEvent('chat:addSuggestion', '/leavefaction', 'Leave your faction; keeps your civilian job')
    TriggerEvent('chat:addSuggestion', '/quitfaction', 'Same as /leavefaction; keeps your civilian job')
    TriggerEvent('chat:addSuggestion', '/quitgroup', 'Same as /leavefaction; keeps your civilian job')
    TriggerEvent('chat:addSuggestion', '/f', 'Faction chat', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/r', 'On-duty faction radio', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/d', 'Law enforcement dispatch', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/service', 'Request emergency/service dispatch', {
        { name = 'type', help = 'taxi|medic|fire|mechanic' },
        { name = 'message', help = 'optional details' },
    })
    TriggerEvent('chat:addSuggestion', '/gov', 'Public emergency notice (on-duty LSPD/EMS/LSFD only; everyone can read)', { { name = 'message' } })
    TriggerEvent('chat:addSuggestion', '/finvite', 'Leader: invite an accepted applicant nearby', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/acceptfaction', 'Accept your pending faction invitation')
    TriggerEvent('chat:addSuggestion', '/declinefaction', 'Decline your pending faction invitation')
    TriggerEvent('chat:addSuggestion', '/funinvite', 'Remove member', { { name = 'id' } })
    TriggerEvent('chat:addSuggestion', '/fgiverank', 'Set member rank', { { name = 'id' }, { name = 'grade' } })
    TriggerEvent('chat:addSuggestion', '/fwarn', 'Faction warning', { { name = 'id' }, { name = 'reason' } })
    TriggerEvent('chat:addSuggestion', '/fmembers', 'List online faction members')
    TriggerEvent('chat:addSuggestion', '/fmotd', 'Read MOTD, or set it if you have permission', { { name = 'message', help = 'optional new MOTD' } })
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
    TriggerEvent('chat:addSuggestion', '/fd', 'LSFD how-to: duty, garage, fires, extinguisher')
    TriggerEvent('chat:addSuggestion', '/firestart', 'Dispatch a vehicle fire if none is active (LSFD on duty)')
    TriggerEvent('chat:addSuggestion', '/firecalls', 'List active fire incidents and set GPS (LSFD on duty)')
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
    '/booking — GPS to nearest MRPD/Bolingbroke booking marker',
    '/arrest [id] — Book a CUFFED + WANTED suspect inside that marker',
    '/cuff [id] — Restrain suspect',
    '/uncuff [id] — Remove restraints',
    '/ticket [id] (or /fine [id]) — choose an official citation in UI',
    '/mdc — Mobile data terminal',
    '/confiscate [id] — Confiscate contraband',
    '/startradar [limit_kmh] — Lock patrol car and monitor traffic',
    '/stopradar — Deactivate speed radar',
    '/radars — List fixed speed cameras',
    '/f [msg] — Faction radio',
    '/faction — Your rank, salary, commands',
    '/help — personalized list filtered to commands your current rank can use',
    'Payday: every hour at :00 — must be ON DUTY — salary goes to bank',
}

RegisterCommand('pd', function()
    for _, line in ipairs(PD_HELP) do
        exports.sunset_ui:Send('chatMessage', { id = 0, name = 'LSPD', message = line, time = '' })
    end
end, false)

local FD_HELP = {
    '=== LSFD (on duty) ===',
    '/duty — Toggle shift at LS Fire Department HQ (orange marker)',
    '[E] at Fire Station Garage — spawn firetruk',
    '/firestart — Create a vehicle fire if none is active',
    '/firecalls — List fires and put GPS on the first one',
    '/calls — Accept civilian /service fire requests',
    'At the wreck: you get a fire extinguisher — hold LMB and spray until it dies',
    'Stay within ~8m of the burning car. When health hits 0 you get paid (~$350)',
    'Engineer+ can /revive, Firefighter+ can /heal, all ranks /stabilize',
    '/f [msg] — Faction radio  |  /faction — rank, salary, commands',
    '/help — same commands filtered to your current rank',
}

RegisterCommand('fd', function()
    for _, line in ipairs(FD_HELP) do
        exports.sunset_ui:Send('chatMessage', { id = 0, type = 'faction_info', name = 'LSFD', message = line, time = '' })
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
