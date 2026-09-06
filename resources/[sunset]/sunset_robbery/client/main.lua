local session = nil
local blips = {}
local mapBlips = {}
local escapeBlip = nil
local fencePed = nil

local function notify(msg, kind, ms)
    exports.sunset_ui:Notify(msg, kind or 'info', ms or 5000)
end

local function dist(a, b)
    if not a or not b then return 9999.0 end
    return #(a - b)
end

local function nearestLocation(pos)
    local best, bestDist
    for id, loc in pairs(SunsetRobbery.Locations) do
        local d = dist(pos, loc.coords)
        if d <= (loc.radius or 16.0) and (not bestDist or d < bestDist) then
            best, bestDist = loc, d
        end
    end
    return best
end

local function drawPrompt(coords, text)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z + 0.35)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function clearBlips()
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end

local function addMapBlip(coords, preset, fallbackLabel)
    if not coords then return end
    preset = preset or {}
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, preset.sprite or 617)
    SetBlipColour(blip, preset.color or 1)
    SetBlipScale(blip, preset.scale or 0.85)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(preset.label or fallbackLabel or 'Robbery')
    EndTextCommandSetBlipName(blip)
    mapBlips[#mapBlips + 1] = blip
end

local function createMapBlips()
    for _, blip in ipairs(mapBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    mapBlips = {}
    for _, loc in pairs(SunsetRobbery.Locations or {}) do
        local point = (loc.entrance and loc.entrance.coords) or loc.coords
        addMapBlip(point, loc.blip, loc.label or 'Robbery')
    end
end

local function clearEscapeGuide()
    if escapeBlip and DoesBlipExist(escapeBlip) then RemoveBlip(escapeBlip) end
    escapeBlip = nil
end

local function markFenceGps()
    local f = SunsetRobbery.Fence.coords
    SetNewWaypoint(f.x, f.y)
end

local function markEscapeGuide(origin)
    clearEscapeGuide()
    if not origin then return end
    escapeBlip = AddBlipForRadius(origin.x, origin.y, origin.z, SunsetRobbery.EscapeRadius)
    SetBlipColour(escapeBlip, 1)
    SetBlipAlpha(escapeBlip, 80)
    SetNewWaypoint(SunsetRobbery.Fence.coords.x, SunsetRobbery.Fence.coords.y)
end

local function spawnFence()
    if fencePed and DoesEntityExist(fencePed) then return end
    local model = `g_m_m_armgoon_01`
    RequestModel(model)
    local deadline = GetGameTimer() + 4000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(model) then return end
    local f = SunsetRobbery.Fence
    fencePed = CreatePed(4, model, f.coords.x, f.coords.y, f.coords.z - 1.0, f.heading or 0.0, false, true)
    SetEntityInvincible(fencePed, true)
    SetBlockingOfNonTemporaryEvents(fencePed, true)
    FreezeEntityPosition(fencePed, true)
    SetModelAsNoLongerNeeded(model)
end

local function startRobbery(locationId)
    local dead = false
    pcall(function()
        dead = exports.sunset_death:IsDead() == true
    end)
    if dead then return notify('You cannot rob right now', 'error') end
    TriggerServerEvent('sunset:robbery:tryStart', locationId or 'luxury_store')
end

RegisterNetEvent('sunset:robbery:tryCommand', function()
    local loc = nearestLocation(GetEntityCoords(PlayerPedId()))
    if not loc then return notify('You are not near a robbery location', 'error') end
    startRobbery(loc.id)
end)

RegisterNetEvent('sunset:robbery:started', function(payload)
    session = {
        location = payload.location,
        stage = payload.stage,
        bagCap = payload.bagCap,
        smashed = {},
    }
    RobberyAnims.sound('terminal')
    notify('Get to the security terminal', 'warning', 6000)
end)

RegisterNetEvent('sunset:robbery:hackResult', function(payload)
    RobberyNui.focus(false, false)
    RobberyNui.send('hackHide', {})
    RobberyAnims.stop()
    RobberyAnims.attachBag()
    RobberyAnims.sound(payload.result == 'failed' and 'hackFail' or 'hackOk')
    session = session or {}
    session.stage = 'LOOTING'
    if payload.result == 'perfect' then
        notify('SECURITY BYPASSED — police delayed', 'success', 6000)
    elseif payload.result == 'normal' then
        notify('Firewall down — short delay only', 'info', 6000)
    else
        notify('TRACE COMPLETE — alarm going out now', 'error', 7000)
        RobberyAnims.sound('alarm')
    end
    if payload.hud then RobberyNui.send('hudShow', payload.hud) end
end)

RegisterNetEvent('sunset:robbery:hackOpenUi', function(payload)
    if not session or session.stage ~= 'HACKING' then return end
    RobberyAnims.play('hack', -1)
    RobberyNui.focus(true, true)
    RobberyNui.send('hackShow', payload or {})
end)

RegisterNetEvent('sunset:robbery:hackProgress', function(payload)
    RobberyNui.send('hackProgress', payload)
end)

RegisterNetEvent('sunset:robbery:displayLoot', function(payload)
    RobberyAnims.sound('glass')
    RobberyNui.focus(true, true)
    RobberyNui.send('lootShow', payload)
end)

RegisterNetEvent('sunset:robbery:itemTaken', function(payload)
    RobberyAnims.sound('pickup')
    if session then
        session.bagUsed = payload.bagUsed
        session.bagCap = payload.bagCap
        session.estimated = payload.estimated
    end
    RobberyNui.send('lootTaken', payload)
    RobberyNui.send('hudShow', payload)
end)

RegisterNetEvent('sunset:robbery:hud', function(payload)
    if session then RobberyNui.send('hudShow', payload) end
end)

RegisterNetEvent('sunset:robbery:escaping', function(payload)
    session = session or {}
    session.stage = 'ESCAPING'
    session.escapeOrigin = payload.origin or (session.location and session.location.coords)
    markEscapeGuide(session.escapeOrigin)
    RobberyNui.send('hudShow', payload.hud or { stage = 'ESCAPING' })
    notify('Get 300m away from the store. GPS set to the fence after you clear.', 'warning', 8000)
end)

RegisterNetEvent('sunset:robbery:alarm', function()
    RobberyAnims.sound('alarm')
end)

RegisterNetEvent('sunset:robbery:ended', function(payload)
    RobberyNui.focus(false, false)
    RobberyNui.send('hackHide', {})
    RobberyNui.send('lootHide', {})
    RobberyNui.send('hudHide', {})
    RobberyAnims.stop()
    RobberyAnims.detachBag()
    clearEscapeGuide()
    session = nil
    if payload and payload.ok then
        RobberyAnims.sound('complete')
        markFenceGps()
        notify(('ROBBERY COMPLETE — $%s est. GPS set to the dock fence. Sell there.'):format(payload.estimated or 0), 'success', 9000)
    else
        notify((payload and payload.reason) or 'Robbery ended', 'error', 6000)
    end
end)

RegisterNetEvent('sunset:robbery:policePing', function(data)
    local blip = AddBlipForRadius(data.x, data.y, data.z, data.radius or 50.0)
    SetBlipColour(blip, 1)
    SetBlipAlpha(blip, 90)
    local point = AddBlipForCoord(data.x, data.y, data.z)
    SetBlipSprite(point, 161)
    SetBlipColour(point, 1)
    SetBlipScale(point, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.label or 'Robbery')
    EndTextCommandSetBlipName(point)
    blips[#blips + 1] = blip
    blips[#blips + 1] = point
    SetTimeout(90000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        if DoesBlipExist(point) then RemoveBlip(point) end
    end)
end)

AddEventHandler('sunset:robbery:nuiFenceSell', function(data)
    CreateThread(function()
        local result, err = Sunset.AwaitCallback('sunset:robbery:fenceSell', data and data.offerId)
        if result then
            notify(('Fence paid $%s'):format(result.paid), 'success')
            local preview = Sunset.AwaitCallback('sunset:robbery:fencePreview')
            if preview then RobberyNui.send('fenceShow', preview) end
        else
            notify(err or 'Deal fell through', 'error')
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    RobberyAnims.detachBag()
    if fencePed and DoesEntityExist(fencePed) then DeleteEntity(fencePed) end
    clearBlips()
    clearEscapeGuide()
    for _, blip in ipairs(mapBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    mapBlips = {}
    RobberyNui.focus(false, false)
end)

CreateThread(function()
    createMapBlips()
    spawnFence()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local sleep = 700
        local loc = nearestLocation(pos)

        if SunsetRobbery.Debug and loc then
            sleep = 0
            DrawMarker(1, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, 0, 0, 0, 0, 0, 0, loc.radius * 2, loc.radius * 2, 0.4, 255, 80, 40, 40, false, false, 2, false, nil, nil, false)
            DrawMarker(2, loc.hackTerminal.coords.x, loc.hackTerminal.coords.y, loc.hackTerminal.coords.z + 0.2, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.25, 255, 140, 40, 160, false, false, 2, false, nil, nil, false)
            for _, display in ipairs(loc.displays) do
                DrawMarker(28, display.coords.x, display.coords.y, display.coords.z + 0.2, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, 255, 200, 60, 140, false, false, 2, false, nil, nil, false)
            end
        end

        if not session and loc then
            local startAt = (loc.entrance and loc.entrance.coords) or loc.coords
            local startRange = (loc.entrance and loc.entrance.radius) or 3.2
            if dist(pos, startAt) <= startRange then
                sleep = 0
                DrawMarker(1, startAt.x, startAt.y, startAt.z - 1.05, 0, 0, 0, 0, 0, 0, 1.4, 1.4, 0.35, 255, 120, 40, 90, false, false, 2, false, nil, nil, false)
                drawPrompt(startAt, loc.startHint or '[E] Start robbery')
                if IsControlJustPressed(0, 38) then startRobbery(loc.id) end
            end
        end

        if session and session.stage == 'HACKING' then
            local term = session.location.hackTerminal
            if dist(pos, term.coords) <= 2.0 then
                sleep = 0
                drawPrompt(term.coords, term.label or '[E] Bypass security')
                DrawMarker(2, term.coords.x, term.coords.y, term.coords.z + 0.35, 0, 0, 0, 0, 0, 0, 0.28, 0.28, 0.28, 255, 140, 40, 180, false, false, 2, false, nil, nil, false)
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent('sunset:robbery:hackOpen')
                end
            end
        end

        if session and session.stage == 'LOOTING' then
            local inside = dist(pos, session.location.coords) <= (session.location.radius + 1.5)
            if not inside then
                TriggerServerEvent('sunset:robbery:leaveStore')
                session.stage = 'ESCAPING'
            else
                for _, display in ipairs(session.location.displays) do
                    if dist(pos, display.coords) <= SunsetRobbery.StoreInteractRadius then
                        sleep = 0
                        drawPrompt(display.coords, '[E] Break display — ' .. display.label)
                        if IsControlJustPressed(0, 38) then
                            RobberyAnims.play('smash', 1600)
                            RobberyAnims.shake(0.07)
                            RobberyAnims.glassFx(display.coords)
                            SetTimeout(700, function()
                                TriggerServerEvent('sunset:robbery:smash', display.id)
                            end)
                        end
                    end
                end
            end
        end

        if session and session.stage == 'ESCAPING' then
            sleep = 0
            local origin = session.escapeOrigin or session.location.coords
            local left = math.max(0, math.floor(SunsetRobbery.EscapeRadius - dist(pos, origin)))
            RobberyNui.send('hudShow', {
                stage = 'ESCAPING',
                bagUsed = session.bagUsed,
                bagCap = session.bagCap,
                estimated = session.estimated,
                escapeLeft = left,
                policeAlerted = true,
            })
            if dist(pos, origin) >= SunsetRobbery.EscapeRadius then
                TriggerServerEvent('sunset:robbery:escaped')
                session.stage = 'DONE'
            end
        end

        if dist(pos, SunsetRobbery.Fence.coords) <= SunsetRobbery.Fence.interact then
            sleep = 0
            drawPrompt(SunsetRobbery.Fence.coords, '[E] Fence — "Got anything worth my time?"')
            if IsControlJustPressed(0, 38) then
                RobberyAnims.play('fence', 1400)
                CreateThread(function()
                    local data, err = Sunset.AwaitCallback('sunset:robbery:fencePreview')
                    if not data then
                        notify(err or 'The fence is not talking', 'error')
                        return
                    end
                    RobberyNui.focus(true, true)
                    RobberyNui.send('fenceShow', data)
                end)
            end
        end

        Wait(sleep)
    end
end)
