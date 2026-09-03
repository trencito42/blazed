local editing = false
local saving = false
local pendingChar = nil
local currentAppearance = nil
local studioCam = nil
local pedHeading = 180.0
local cameraMode = 'full'
local studioCenter = nil
local FIXED_CAM_BEARING = 0.0 -- camera stays fixed in world; ped spins on spot

Sunset = Sunset or {}

local FALLBACK_STUDIO = vector4(-1037.58, -2737.58, 20.17, 328.0)

local CAMERA_PRESETS = {
    full = { dist = 3.6, z = 0.05, aim = 0.02, fov = 48.0 },
    face = { dist = 1.05, z = 0.68, aim = 0.62, fov = 32.0 },
    feet = { dist = 2.4, z = -0.72, aim = -0.62, fov = 42.0 },
}

local function getStudioCoords()
    local spawn = (Sunset.Config and Sunset.Config.DefaultSpawn) or FALLBACK_STUDIO
    return vector4(spawn.x, spawn.y, spawn.z, spawn.w or 328.0)
end

local function destroyStudio()
    RenderScriptCams(false, true, 600, true, true)
    if studioCam then
        DestroyCam(studioCam, false)
        studioCam = nil
    end
    ClearFocus()
end

local function setupCamera(ped, mode)
    mode = mode or cameraMode or 'full'
    cameraMode = mode
    local preset = CAMERA_PRESETS[mode] or CAMERA_PRESETS.full

    if not studioCam then
        studioCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end

    local center = studioCenter or GetEntityCoords(ped)
    local bearing = math.rad(FIXED_CAM_BEARING)
    local camX = center.x - math.sin(bearing) * preset.dist
    local camY = center.y + math.cos(bearing) * preset.dist

    SetCamCoord(studioCam, camX, camY, center.z + preset.z)
    PointCamAtCoord(studioCam, center.x, center.y, center.z + preset.aim)
    SetCamFov(studioCam, preset.fov)
    SetCamActive(studioCam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function rotatePed(delta)
    local ped = PlayerPedId()
    pedHeading = (pedHeading + delta) % 360.0
    SetEntityHeading(ped, pedHeading)
end

local function loadFreemodePed(char)
    local model = (char.gender == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)

    currentAppearance = SunsetAppearance.normalize(char.appearance, char.gender or 0)
    SunsetAppearance.apply(ped, currentAppearance, char.gender or 0)
    return true
end

local function waitForWorldAt(x, y, z, ped)
    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
    local timeout = GetGameTimer() + 8000
    while not IsNewLoadSceneLoaded() do
        if GetGameTimer() > timeout then break end
        Wait(0)
    end
    NewLoadSceneStop()
    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)

    timeout = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) do
        if GetGameTimer() > timeout then break end
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
end

local function pushEditorUi(char)
    local ped = PlayerPedId()
    local fields, appearance = SunsetAppearance.buildEditor(ped, currentAppearance, char.gender or 0)
    currentAppearance = appearance
    exports.sunset_ui:Send('appearanceShow', {
        gender = char.gender or 0,
        fields = fields,
        camera = cameraMode,
    })
end

local function enterStudio(char, skipFade)
    if not skipFade then
        DoScreenFadeOut(400)
        Wait(500)
    end

    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()
    exports.sunset_ui:Send('hide', {})

    if not loadFreemodePed(char) then
        if not skipFade then DoScreenFadeIn(500) end
        exports.sunset_ui:Notify('Failed to load character model', 'error')
        return false
    end

    local studio = getStudioCoords()
    local ped = PlayerPedId()
    pedHeading = studio.w
    studioCenter = vector3(studio.x, studio.y, studio.z)
    cameraMode = 'full'

    SetEntityCoordsNoOffset(ped, studio.x, studio.y, studio.z, false, false, false)
    SetEntityHeading(ped, pedHeading)
    waitForWorldAt(studio.x, studio.y, studio.z, ped)

    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    SetLocalPlayerVisibleLocally(true)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityCollision(ped, false, false)

    setupCamera(ped, 'full')
    DisplayRadar(false)
    NetworkOverrideClockTime(20, 30, 0)
    SetWeatherTypeNowPersist('CLEAR')
    SetRainLevel(0.0)

    if not skipFade then DoScreenFadeIn(700) end
    return true
end

local function openEditor(char)
    if editing then return end
    saving = false
    pendingChar = char
    char.gender = char.gender or 0

    if not enterStudio(char, false) then return end

    editing = true
    pushEditorUi(char)
    exports.sunset_ui:SetFocus(true, true, true)
end

CreateThread(function()
    while true do
        if editing then
            local ped = PlayerPedId()
            SetEntityVisible(ped, true, false)
            if IsControlPressed(0, 34) or IsControlPressed(0, 174) then
                rotatePed(-1.8)
            end
            if IsControlPressed(0, 35) or IsControlPressed(0, 175) then
                rotatePed(1.8)
            end
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('sunset:client:appearanceRequired', function(char)
    openEditor(char)
end)

AddEventHandler('sunset:nui:appearanceChange', function(data)
    if not editing or not pendingChar or not currentAppearance then return end
    currentAppearance = SunsetAppearance.applyField(PlayerPedId(), currentAppearance, pendingChar.gender or 0, data)
    if data.camera then
        setupCamera(PlayerPedId(), data.camera)
        exports.sunset_ui:Send('appearanceCamera', { camera = data.camera })
    end
end)

AddEventHandler('sunset:nui:appearanceCamera', function(data)
    if not editing then return end
    setupCamera(PlayerPedId(), data.mode or 'full')
    exports.sunset_ui:Send('appearanceCamera', { camera = cameraMode })
end)

AddEventHandler('sunset:nui:appearanceRotate', function(data)
    local delta = (data.direction == 'left') and -15.0 or 15.0
    rotatePed(delta)
end)

AddEventHandler('sunset:nui:appearanceGender', function(data)
    if not pendingChar or not editing then return end
    pendingChar.gender = tonumber(data.gender) or 0
    currentAppearance = SunsetAppearance.default(pendingChar.gender)
    enterStudio(pendingChar, true)
    pushEditorUi(pendingChar)
end)

local function finishAppearanceAndSpawn(char)
    editing = false
    saving = false
    studioCenter = nil
    destroyStudio()

    local ped = PlayerPedId()
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    exports.sunset_ui:SetFocus(false, false, false)
    exports.sunset_ui:Send('appearanceHide', {})
    exports.sunset_ui:Show('loading')

    TriggerEvent('sunset:client:spawnCharacter', char)
end

AddEventHandler('sunset:nui:appearanceSave', function()
    if not editing or saving or not pendingChar or not currentAppearance then return end

    saving = true
    exports.sunset_ui:Send('appearanceSaving', {})

    CreateThread(function()
        local ok, err = pcall(function()
            Sunset.AwaitCallback(
                'sunset:saveAppearance',
                currentAppearance,
                pendingChar.gender,
                pendingChar.id
            )
        end)

        if not ok then
            saving = false
            exports.sunset_ui:Send('appearanceSaveFailed', {})
            exports.sunset_ui:Notify(tostring(err) or 'Could not save appearance', 'error')
            return
        end

        pendingChar.appearance = currentAppearance
        pendingChar.gender = pendingChar.gender or 0

        local char = pendingChar
        pendingChar = nil
        currentAppearance = nil

        finishAppearanceAndSpawn(char)
    end)
end)

function ApplyAppearance(ped, appearance, gender)
    SunsetAppearance.apply(ped, appearance, gender or 0)
end
exports('ApplyAppearance', ApplyAppearance)
exports('IsEditing', function() return editing end)

AddEventHandler('sunset:client:playerSpawned', function(char)
    if char and char.appearance then
        SunsetAppearance.apply(PlayerPedId(), char.appearance, char.gender or 0)
    end
end)

RegisterCommand('relook', function()
    if editing then return end
    local char = exports.sunset_core:GetCharacter()
    if not char then
        exports.sunset_ui:Notify('No character loaded', 'error')
        return
    end
    openEditor(char)
end, false)
TriggerEvent('chat:addSuggestion', '/relook', 'Re-open character appearance editor')
