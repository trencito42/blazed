-- Pillbox: bob74_ipl enables rc12b_default, which shows the hospital shell with
-- closed glass doors but no walkable interior. Swap to the interior IPL instead.

local PILLBOX_CENTER = vector3(307.17, -590.81, 43.28)

-- Main entrance double doors (ground floor lobby)
local ENTRANCE_DOORS = {
    { id = 'pillbox_entrance_l', model = `v_ilev_cor_firedoor`, coords = vector3(308.13, -595.48, 43.29) },
    { id = 'pillbox_entrance_r', model = `v_ilev_cor_firedoor`, coords = vector3(310.29, -595.48, 43.29) },
}

local function unlockDoor(door)
    local doorId = GetHashKey(door.id)
    AddDoorToSystem(doorId, door.model, door.coords.x, door.coords.y, door.coords.z, false, false, false)
    DoorSystemSetDoorState(doorId, 0, false, false)
    DoorSystemSetOpenRatio(doorId, 1.0, false, false)
end

local function applyPillboxInterior()
    if GetResourceState('bob74_ipl') == 'started' then
        local pillbox = exports['bob74_ipl']:GetPillboxHospitalObject()
        if pillbox and pillbox.Enable then
            pillbox.Enable(false)
        end
    end

    RemoveIpl('rc12b_fixed')
    RemoveIpl('rc12b_destroyed')
    RemoveIpl('rc12b_default')

    RequestIpl('rc12b_hospitalinterior')
    RequestIpl('rc12b_hospitalinterior_lod')

    for _, door in ipairs(ENTRANCE_DOORS) do
        unlockDoor(door)
    end
end

CreateThread(function()
    while GetResourceState('bob74_ipl') ~= 'started' do
        Wait(200)
    end
    Wait(1000)
    applyPillboxInterior()
end)

-- Re-apply if bob74 or map streaming re-enables the blocking default IPL.
CreateThread(function()
    while true do
        Wait(10000)
        if IsIplActive('rc12b_default') then
            applyPillboxInterior()
        elseif #(GetEntityCoords(PlayerPedId()) - PILLBOX_CENTER) < 120.0 then
            for _, door in ipairs(ENTRANCE_DOORS) do
                unlockDoor(door)
            end
        end
    end
end)
