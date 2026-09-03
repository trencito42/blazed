local editing = false
local pendingChar = nil
local studioCam = nil
local pedHeading = 180.0

local STUDIO = vector4(402.87, -996.41, -99.0, 180.0)

local function applyAppearance(ped, appearance)
    if not appearance then return end
    for i = 0, 11 do
        local comp = appearance[tostring(i)] or appearance[i]
        if comp then
            SetPedComponentVariation(ped, i, comp.drawable or 0, comp.texture or 0, 0)
        end
    end
    if appearance.hair then
        SetPedComponentVariation(ped, 2, appearance.hair.drawable or 0, appearance.hair.texture or 0, 0)
    end
end

local function destroyStudio()
    RenderScriptCams(false, true, 600, true, true)
    if studioCam then
        DestroyCam(studioCam, false)
        studioCam = nil
    end
end

local function setupCamera(ped)
    if studioCam then DestroyCam(studioCam, false) end
    studioCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local coords = GetEntityCoords(ped)
    SetCamCoord(studioCam, coords.x + 0.05, coords.y + 2.15, coords.z + 0.62)
    PointCamAtCoord(studioCam, coords.x, coords.y, coords.z + 0.58)
    SetCamFov(studioCam, 40.0)
    SetCamActive(studioCam, true)
    RenderScriptCams(true, false, 0, true, true)
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
    if char.appearance and next(char.appearance) then
        applyAppearance(ped, char.appearance)
    end
    return true
end

local function buildComponentList(ped)
    return {
        { id = 0, label = 'Face', max = GetNumberOfPedDrawableVariations(ped, 0) - 1 },
        { id = 2, label = 'Hair', max = GetNumberOfPedDrawableVariations(ped, 2) - 1 },
        { id = 3, label = 'Torso', max = GetNumberOfPedDrawableVariations(ped, 3) - 1 },
        { id = 4, label = 'Legs', max = GetNumberOfPedDrawableVariations(ped, 4) - 1 },
        { id = 6, label = 'Shoes', max = GetNumberOfPedDrawableVariations(ped, 6) - 1 },
        { id = 11, label = 'Top', max = GetNumberOfPedDrawableVariations(ped, 11) - 1 },
    }
end

local function prepareStudioInterior()
    local x, y, z = STUDIO.x, STUDIO.y, STUDIO.z
    RequestCollisionAtCoord(x, y, z)
    local interior = GetInteriorAtCoords(x, y, z)
    if interior ~= 0 then
        PinInteriorInMemory(interior)
        RefreshInterior(interior)
    end
end

local function enterStudio(char)
    DoScreenFadeOut(400)
    Wait(500)

    if not loadFreemodePed(char) then
        DoScreenFadeIn(500)
        exports.sunset_ui:Notify('Failed to load character model', 'error')
        return false
    end

    prepareStudioInterior()

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, STUDIO.x, STUDIO.y, STUDIO.z, false, false, false)
    pedHeading = STUDIO.w
    SetEntityHeading(ped, pedHeading)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    ClearPedTasksImmediately(ped)
    SetEntityCollision(ped, false, false)

    setupCamera(ped)
    DisplayRadar(false)
    NetworkOverrideClockTime(12, 0, 0)

    DoScreenFadeIn(700)
    return true
end

local function openEditor(char)
    if editing then return end
    pendingChar = char
    char.gender = char.gender or 0

    if not enterStudio(char) then return end

    editing = true
    local ped = PlayerPedId()

    exports.sunset_ui:Send('appearanceShow', {
        gender = char.gender,
        components = buildComponentList(ped),
    })
    exports.sunset_ui:SetFocus(true, true, true)
end

CreateThread(function()
    while true do
        if editing then
            local ped = PlayerPedId()
            if IsControlPressed(0, 34) or IsControlPressed(0, 174) then
                pedHeading = pedHeading - 1.8
                SetEntityHeading(ped, pedHeading)
            end
            if IsControlPressed(0, 35) or IsControlPressed(0, 175) then
                pedHeading = pedHeading + 1.8
                SetEntityHeading(ped, pedHeading)
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

AddEventHandler('sunset:nui:appearancePreview', function(data)
    local ped = PlayerPedId()
    SetPedComponentVariation(ped, data.component, data.drawable or 0, data.texture or 0, 0)
end)

AddEventHandler('sunset:nui:appearanceRotate', function(data)
    local ped = PlayerPedId()
    local delta = (data.direction == 'left') and -12.0 or 12.0
    pedHeading = pedHeading + delta
    SetEntityHeading(ped, pedHeading)
end)

AddEventHandler('sunset:nui:appearanceGender', function(data)
    if not pendingChar or not editing then return end
    pendingChar.gender = tonumber(data.gender) or 0
    enterStudio(pendingChar)
    local ped = PlayerPedId()
    exports.sunset_ui:Send('appearanceUpdate', {
        gender = pendingChar.gender,
        components = buildComponentList(ped),
    })
end)

AddEventHandler('sunset:nui:appearanceSave', function(data)
    if not pendingChar then return end

    local appearance = data.appearance or {}
    Sunset.AwaitCallback('sunset:saveAppearance', appearance, pendingChar.gender)
    pendingChar.appearance = appearance
    pendingChar.gender = pendingChar.gender or 0

    editing = false
    destroyStudio()
    exports.sunset_ui:SetFocus(false, false, false)
    exports.sunset_ui:Send('appearanceHide', {})

    local char = pendingChar
    pendingChar = nil

    exports.sunset_ui:Show('loading')
    TriggerEvent('sunset:client:spawnCharacter', char)
end)

exports('IsEditing', function()
    return editing
end)

AddEventHandler('sunset:client:playerSpawned', function(char)
    if char and char.appearance then
        applyAppearance(PlayerPedId(), char.appearance)
    end
end)
