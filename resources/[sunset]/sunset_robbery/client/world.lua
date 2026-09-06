local function prepareJewelryInterior()
    RemoveIpl('jewel2fake')
    RequestIpl('post_hiest_unload')
    local interior = GetInteriorAtCoords(-622.25, -230.93, 38.06)
    if interior and interior ~= 0 then
        PinInteriorInMemory(interior)
        RefreshInterior(interior)
    end
end

local function unlockStoreDoors(loc)
    for _, door in ipairs(loc.doors or {}) do
        local model = door.model
        local c = door.coords
        SetStateOfClosestDoorOfType(model, c.x, c.y, c.z, false, 1.0, false)
        local doorId = joaat(('sunset_rob_%s_%s'):format(loc.id, tostring(model)))
        AddDoorToSystem(doorId, model, c.x, c.y, c.z, false, false, false)
        DoorSystemSetDoorState(doorId, 0, false, false)
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, 2.2, model, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            FreezeEntityPosition(obj, false)
            SetEntityCollision(obj, false, true)
        end
    end
end

CreateThread(function()
    prepareJewelryInterior()
    while true do
        for _, loc in pairs(SunsetRobbery.Locations or {}) do
            if loc.doors then unlockStoreDoors(loc) end
        end
        Wait(2000)
    end
end)
