local function prepareJewelryInterior()
    RemoveIpl('jewel2fake')
    RequestIpl('post_hiest_unload')
    local interior = GetInteriorAtCoords(-622.25, -230.93, 38.06)
    if interior and interior ~= 0 then
        PinInteriorInMemory(interior)
        RefreshInterior(interior)
    end
end

local doorStates = {}

local function setStoreDoors(loc, unlocked)
    if not loc then return end
    doorStates[loc.id] = unlocked == true
    for _, door in ipairs(loc.doors or {}) do
        local model = door.model
        local c = door.coords
        SetStateOfClosestDoorOfType(model, c.x, c.y, c.z, not unlocked, 1.0, false)
        local doorId = joaat(('sunset_rob_%s_%s'):format(loc.id, tostring(model)))
        AddDoorToSystem(doorId, model, c.x, c.y, c.z, false, false, false)
        DoorSystemSetDoorState(doorId, unlocked and 0 or 1, false, false)
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, 2.2, model, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            SetEntityCollision(obj, true, true)
        end
    end
end

RegisterNetEvent('sunset:robbery:doorState', function(locationId, unlocked)
    local loc = SunsetRobbery.Locations[tostring(locationId or '')]
    if loc then setStoreDoors(loc, unlocked == true) end
end)

CreateThread(function()
    prepareJewelryInterior()
    while true do
        for _, loc in pairs(SunsetRobbery.Locations or {}) do
            if loc.doors then setStoreDoors(loc, doorStates[loc.id] == true) end
        end
        Wait(2000)
    end
end)
