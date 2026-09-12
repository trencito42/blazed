local downed = false
local dead = false
local active = false
local respawning = false
local bleedoutEndsAt = 0
local stabilized = false

local function getPed()
    return PlayerPedId()
end

local function cfg()
    return Sunset.Death or {}
end

-- [AUDIT P8-14] Force-close every modal UI and release NUI focus across death
-- transitions: trade panels, inventory and phone used to survive respawn with a
-- stuck cursor.
local function closeAllModalUi()
    pcall(function() TriggerEvent('sunset:client:inventoryForceClose') end)
    pcall(function() TriggerEvent('sunset:phone:forceClose') end)
    if GetResourceState('sunset_ui') == 'started' then
        pcall(function()
            exports.sunset_ui:Send('tradeHide', {})
            exports.sunset_ui:Send('ticketReceiveHide', {})
            exports.sunset_ui:Send('mdcHide', {})
            exports.sunset_ui:SetFocus(false, false)
        end)
    end
end

local function doRespawn(coords, bill)
    if respawning then return end
    respawning = true
    dead = false
    downed = false
    stabilized = false
    bleedoutEndsAt = 0
    closeAllModalUi()

    local x = coords.x or 0.0
    local y = coords.y or 0.0
    local z = coords.z or 0.0
    local heading = coords.w or coords.heading or 0.0

    DoScreenFadeOut(400)
    Wait(500)

    NetworkResurrectLocalPlayer(x, y, z, heading, true, false)
    local ped = getPed()
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)
    ClearPedBloodDamage(ped)
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    SetPlayerControl(PlayerId(), true, 0)

    Wait(400)
    DoScreenFadeIn(800)
    respawning = false

    if bill and bill > 0 then
        exports.sunset_ui:Notify(('Hospital bill: $%s'):format(bill), 'warning')
    end
end

local function doReviveInPlace()
    if respawning then return end
    local ped = getPed()
    local coords = GetEntityCoords(ped)
    downed = false
    stabilized = false
    bleedoutEndsAt = 0
    doRespawn({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }, 0)
end

local function playDownedAnim()
    local ped = getPed()
    local dict = cfg().downedAnimDict or 'combat@damage@writhe'
    local anim = cfg().downedAnim or 'writhe_loop'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return end
        Wait(10)
    end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function enterDownedState()
    if downed or respawning then return end
    downed = true
    dead = true
    stabilized = false
    bleedoutEndsAt = GetGameTimer() + ((cfg().soloBleedoutSeconds or 15) * 1000)
    closeAllModalUi()

    local ped = getPed()
    NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 150)
    playDownedAnim()

    exports.sunset_ui:Notify('Esti la pamant. Foloseste /respawn pentru spital sau /112 pentru echipaj medical.', 'error', 10000)
    TriggerServerEvent('sunset:death:enteredDowned')
end

RegisterNetEvent('sunset:death:syncTimer', function(seconds)
    if not downed then return end
    seconds = tonumber(seconds) or 15
    bleedoutEndsAt = GetGameTimer() + (seconds * 1000)
    if seconds <= 15 then
        exports.sunset_ui:Notify(('No EMS are available. You can respawn at the hospital in %d seconds (/respawn).'):format(seconds), 'warning', 6000)
    end
end)

AddEventHandler('sunset:client:playerSpawned', function()
    active = true
    dead = false
    downed = false
    stabilized = false
    respawning = false
    bleedoutEndsAt = 0
end)

RegisterNetEvent('sunset:client:respawn', function(pos, bill)
    local spawn = pos or {}
    if not spawn.x then
        local fallback = Sunset.Config.HospitalSpawn or Sunset.Config.DefaultSpawn
        spawn = { x = fallback.x, y = fallback.y, z = fallback.z, w = fallback.w }
    end
    doRespawn(spawn, bill)
end)

RegisterNetEvent('sunset:death:reviveInPlace', function()
    doReviveInPlace()
end)

RegisterNetEvent('sunset:admin:revive', function()
    doReviveInPlace()
end)

RegisterNetEvent('sunset:death:stabilized', function()
    if not downed then return end
    stabilized = true
    bleedoutEndsAt = GetGameTimer() + ((cfg().stabilizeBonusSeconds or 120) * 1000)
    exports.sunset_ui:Notify('Stabilizat — sangerare incetinita.', 'info', 6000)
end)

RegisterNetEvent('sunset:death:forceHospital', function(pos, bill)
    doRespawn(pos or Sunset.Config.HospitalSpawn, bill or Sunset.Config.HospitalBill)
end)

RegisterCommand('respawn', function()
    if not downed and not dead and not IsEntityDead(getPed()) then
        exports.sunset_ui:Notify('Nu esti la pamant.', 'error')
        return
    end
    TriggerServerEvent('sunset:server:requestRespawn')
end, false)

CreateThread(function()
    while true do
        if active then
            local ped = getPed()
            if not downed and not respawning and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then
                enterDownedState()
                TriggerServerEvent('sunset:server:playerDied')
            end

            if downed and not respawning then
                DisableAllControlActions(0)
                EnableControlAction(0, 1, true)
                EnableControlAction(0, 2, true)
                EnableControlAction(0, 245, true)

                if bleedoutEndsAt > 0 and GetGameTimer() >= bleedoutEndsAt then
                    TriggerServerEvent('sunset:server:bleedoutExpired')
                end

                if not IsEntityPlayingAnim(ped, cfg().downedAnimDict or 'combat@damage@writhe', cfg().downedAnim or 'writhe_loop', 3) then
                    playDownedAnim()
                end
                Wait(0)
            else
                Wait(400)
            end
        else
            Wait(1000)
        end
    end
end)

exports('IsDead', function() return dead or downed end)
exports('IsDowned', function() return downed end)
exports('IsStabilized', function() return stabilized end)
exports('ClearDead', function()
    dead = false
    downed = false
    stabilized = false
    respawning = false
    bleedoutEndsAt = 0
end)

-- Kill reporting is server-authoritative; client-only death visuals desync when damage is cancelled.

RegisterCommand('112', function()
    local ped = PlayerPedId()
    if downed or dead or IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) <= 0 then
        TriggerServerEvent('sunset:death:call112')
    else
        local coords = GetEntityCoords(ped)
        local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street = GetStreetNameFromHashKey(streetHash)
        if crossingHash ~= 0 then
            street = street .. ' & ' .. GetStreetNameFromHashKey(crossingHash)
        end
        local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
        if not zone or zone == 'NULL' or zone == '' then zone = 'Los Santos' end

        exports.sunset_ui:Send('dispatch112Show', {
            street = street,
            area = zone,
            coords = { x = coords.x, y = coords.y, z = coords.z },
        })
        exports.sunset_ui:SetFocus(true, true)
    end
end, false)
