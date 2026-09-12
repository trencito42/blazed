-- ============================================================
--  sunset_admintools client — Cutscene & Cinematic Camera Director
--  /cinematic          — toggle free-fly cinematic camera
--  While active:
--    W/A/S/D          move camera (hold SHIFT = fast)
--    Q/E              down/up
--    Mouse            look
--    [1-4]            preset shots: wide orbit, low tracking,
--                     closeup, top-down
--    F5               snapshot current cam (coords/rot/fov) to
--                     chat for reuse in events
--    ESC / /cinematic exit, restores player camera + control
-- ============================================================

local cineActive = false
local cam = nil
local camPos = vector3(0, 0, 0)
local camRot = vector3(0, 0, 0)
local camFov = 50.0
local lastMouseX, lastMouseY = 0.0, 0.0

local function stopCinematic()
    if not cineActive then return end
    cineActive = false
    if cam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
    SetPlayerControl(PlayerId(), true, 0)
    DisplayRadar(true)
    exports.sunset_ui:SetFocus(false, false)
end

local function startCinematic()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    camPos = coords + vector3(0, -6.0, 3.0)
    camRot = vector3(-15.0, 0.0, GetEntityHeading(ped))
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(cam, camFov)
    RenderScriptCams(true, true, 800, true, false)
    SetPlayerControl(PlayerId(), false, 0)
    cineActive = true
    exports.sunset_ui:Notify('Cinematic ON: WASD+QE move, mouse look, 1-4 presets, F5 snapshot, ESC exit.', 'info', 9000)
end

local function applyPreset(n)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    if n == 1 then -- wide orbit
        camPos = coords + vector3(math.sin(heading) * -12.0, math.cos(heading) * -12.0, 5.0)
        camRot = vector3(-20.0, 0.0, heading)
        camFov = 60.0
    elseif n == 2 then -- low tracking
        camPos = coords + vector3(math.sin(heading) * -8.0, math.cos(heading) * -8.0, 0.8)
        camRot = vector3(-5.0, 0.0, heading)
        camFov = 45.0
    elseif n == 3 then -- closeup
        camPos = coords + vector3(math.sin(heading) * -2.2, math.cos(heading) * -2.2, 0.7)
        camRot = vector3(-2.0, 0.0, heading)
        camFov = 30.0
    elseif n == 4 then -- top-down
        camPos = coords + vector3(0.0, 0.0, 25.0)
        camRot = vector3(-90.0, 0.0, 0.0)
        camFov = 50.0
    end
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(cam, camFov)
end

CreateThread(function()
    while true do
        if cineActive and cam then
            local speed = IsControlPressed(0, 21) and 1.2 or 0.35
            local dx, dy, dz = 0.0, 0.0, 0.0

            -- mouse look (raw delta via disabled control normals)
            local mx = GetDisabledControlNormal(0, 1)
            local my = GetDisabledControlNormal(0, 2)
            camRot = vector3(
                math.max(-89.0, math.min(89.0, camRot.x - my * 8.0)),
                camRot.y,
                camRot.z - mx * 8.0)

            local radZ = math.rad(camRot.z)
            local fwdX, fwdY = -math.sin(radZ), math.cos(radZ)
            local rightX, rightY = math.cos(radZ), math.sin(radZ)

            if IsDisabledControlPressed(0, 32) then dx = dx + fwdX * speed dy = dy + fwdY * speed end     -- W
            if IsDisabledControlPressed(0, 33) then dx = dx - fwdX * speed dy = dy - fwdY * speed end     -- S
            if IsDisabledControlPressed(0, 34) then dx = dx - rightX * speed dy = dy - rightY * speed end -- A
            if IsDisabledControlPressed(0, 35) then dx = dx + rightX * speed dy = dy + rightY * speed end -- D
            if IsDisabledControlPressed(0, 44) then dz = dz - speed end                                    -- Q = down
            if IsDisabledControlPressed(0, 38) then dz = dz + speed end                                    -- E = up
            if IsDisabledControlJustPressed(0, 22) then dz = dz + speed * 2 end                            -- SPACE = fast up

            camPos = vector3(camPos.x + dx, camPos.y + dy, math.max(1.0, camPos.z + dz))

            SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
            SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
            SetCamFov(cam, camFov)

            -- presets
            for i = 189, 192 do -- numpad/number keys 1-4 (controls 157-160 are weapon slots; use 189-192 = num keys)
                if IsDisabledControlJustPressed(0, i) then applyPreset(i - 188) end
            end

            -- F5 snapshot
            if IsDisabledControlJustPressed(0, 166) then
                local snap = ('CINEMATIC SNAP pos=vector3(%.2f, %.2f, %.2f) rot=vector3(%.1f, %.1f, %.1f) fov=%.1f'):format(
                    camPos.x, camPos.y, camPos.z, camRot.x, camRot.y, camRot.z, camFov)
                TriggerEvent('chat:addMessage', { color = { 0, 255, 204 }, args = { 'CINE', snap } })
                print('[cinematic] ' .. snap)
            end

            -- ESC exit
            if IsDisabledControlJustPressed(0, 200) then stopCinematic() end

            -- disable movement/attack while directing
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

RegisterCommand('cinematic', function()
    CreateThread(function()
        local ok = Sunset.AwaitCallback('sunset:admintools:check')
        if ok ~= true then
            exports.sunset_ui:Notify('Cinematic: admin level 3+ required.', 'error')
            return
        end
        if cineActive then stopCinematic() else startCinematic() end
    end)
end, false)
TriggerEvent('chat:addSuggestion', '/cinematic', 'Admin: cinematic camera director')

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopCinematic()
end)
