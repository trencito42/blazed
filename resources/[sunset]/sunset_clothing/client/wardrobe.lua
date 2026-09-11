WardrobeShop = WardrobeShop or {}

local shopCam = nil
local pedHeading = 0.0
local camDist = 2.35
local camMode = 'full'
local camCenter = nil
local controlThread = nil

local CAMERA_PRESETS = {
    full = { dist = 2.35, z = 0.05, aim = 0.02, fov = 48.0 },
    face = { dist = 1.05, z = 0.68, aim = 0.62, fov = 32.0 },
    feet = { dist = 2.2, z = -0.72, aim = -0.62, fov = 42.0 },
}

local function destroyCamera()
    RenderScriptCams(false, true, 400, true, true)
    if shopCam then
        DestroyCam(shopCam, false)
        shopCam = nil
    end
end

local function updateCamera(ped, mode)
    mode = mode or camMode or 'full'
    camMode = mode
    local preset = CAMERA_PRESETS[mode] or CAMERA_PRESETS.full
    camDist = preset.dist

    if not shopCam then
        shopCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end

    local center = camCenter or GetEntityCoords(ped)
    local heading = math.rad(pedHeading)
    local camX = center.x - math.sin(heading) * camDist
    local camY = center.y + math.cos(heading) * camDist

    SetCamCoord(shopCam, camX, camY, center.z + preset.z)
    PointCamAtCoord(shopCam, center.x, center.y, center.z + preset.aim)
    SetCamFov(shopCam, preset.fov)
    SetCamActive(shopCam, true)
    RenderScriptCams(true, false, 0, true, true)
end

function WardrobeShop.startCamera(ped, mode)
    camCenter = GetEntityCoords(ped)
    pedHeading = GetEntityHeading(ped)
    updateCamera(ped, mode or 'full')

    if controlThread then return end
    controlThread = CreateThread(function()
        while shopCam do
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)

            if IsDisabledControlPressed(0, 34) then
                pedHeading = (pedHeading - 1.8) % 360.0
                SetEntityHeading(ped, pedHeading)
                updateCamera(ped, camMode)
            elseif IsDisabledControlPressed(0, 35) then
                pedHeading = (pedHeading + 1.8) % 360.0
                SetEntityHeading(ped, pedHeading)
                updateCamera(ped, camMode)
            end

            if IsDisabledControlJustPressed(0, 241) then
                camDist = math.max(1.0, camDist - 0.12)
                updateCamera(ped, camMode)
            elseif IsDisabledControlJustPressed(0, 242) then
                camDist = math.min(4.0, camDist + 0.12)
                updateCamera(ped, camMode)
            end

            Wait(0)
        end
        controlThread = nil
    end)
end

function WardrobeShop.setCameraMode(ped, mode)
    updateCamera(ped, mode)
end

function WardrobeShop.stopCamera()
    destroyCamera()
    camCenter = nil
end
