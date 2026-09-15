-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Server Events (client/main.lua)
--  Event blip + participation marker.
--
--  OWNERSHIP: For race_night, sunset_racing owns the world interaction
--  (marker + E) at the race hub. This resource only shows a blip and
--  announces — it does NOT create a competing marker.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetEvents.Config
local eventData = nil
local eventBlip = nil

RegisterNetEvent('sunset:events:start', function(data)
    eventData = data

    -- Create event blip
    if eventBlip and DoesBlipExist(eventBlip) then
        RemoveBlip(eventBlip)
    end
    if data.location then
        eventBlip = AddBlipForCoord(data.location.x, data.location.y, data.location.z)
        SetBlipSprite(eventBlip, 162) -- star
        SetBlipColour(eventBlip, 5) -- yellow
        SetBlipScale(eventBlip, 1.2)
        SetBlipRoute(eventBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(data.label or 'Event')
        EndTextCommandSetBlipName(eventBlip)
    end
end)

RegisterNetEvent('sunset:events:end', function(data)
    eventData = nil
    if eventBlip and DoesBlipExist(eventBlip) then
        RemoveBlip(eventBlip)
        eventBlip = nil
    end
end)

-- ── Event marker + join (NON-race events only) ──
-- For race_night, sunset_racing owns the marker at the race hub.
CreateThread(function()
    while true do
        if eventData and eventData.location and eventData.type ~= 'race_night' then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local loc = eventData.location

            if #(coords - loc) < 50.0 then
                DrawMarker(1, loc.x, loc.y, loc.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    3.0, 3.0, 1.5,
                    255, 200, 0, 100,
                    false, false, 2, false, nil, nil, false)

                if IsControlJustReleased(0, 38) then
                    local res, err = Sunset.AwaitCallback('sunset:events:join')
                    if not res then
                        exports.sunset_ui:Notify(err or 'Could not join the event.', 'error')
                    end
                end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if eventBlip and DoesBlipExist(eventBlip) then
        RemoveBlip(eventBlip)
        eventBlip = nil
    end
end)

exports('GetEventData', function() return eventData end)
