SunsetWorld = SunsetWorld or {}

--- One world interaction per key press (prevents HQ + entrance both firing on E).
function SunsetWorld.tryInteract()
    local frame = GetGameTimer()
    if SunsetWorld._interactFrame == frame then
        return false
    end
    SunsetWorld._interactFrame = frame
    return true
end

function SunsetWorld.canInteract()
    if SunsetWorld.tryInteract then
        return SunsetWorld.tryInteract()
    end
    return true
end
