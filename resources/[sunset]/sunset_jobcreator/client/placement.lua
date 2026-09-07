local placing = false
local heading = 0.0

function JCPlacement_Start(cb)
    if placing then return end
    placing = true
    heading = GetEntityHeading(PlayerPedId())
    exports.sunset_ui:Notify(SunsetJobCreator.L('placement_hint'), 'info', 9000)

    CreateThread(function()
        while placing do
            Wait(0)
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            DrawMarker(28, coords.x, coords.y, coords.z + 0.05, 0, 0, 0, 0, 0, heading,
                0.45, 0.45, 0.45, 255, 153, 51, 180, false, false, 2, false, nil, nil, false)
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentString('ENTER confirm · BACKSPACE cancel · SCROLL rotate heading')
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustReleased(0, 191) then -- ENTER
                placing = false
                cb({
                    x = coords.x, y = coords.y, z = coords.z,
                    heading = heading,
                    radius = 3.0,
                    zTolerance = 5.0,
                })
                exports.sunset_ui:Notify(SunsetJobCreator.L('placement_saved'), 'success')
                return
            end
            if IsControlJustReleased(0, 194) then -- BACKSPACE
                placing = false
                cb(nil)
                return
            end
            if IsControlJustReleased(0, 241) then heading = heading + 5.0 end
            if IsControlJustReleased(0, 242) then heading = heading - 5.0 end
        end
    end)
end

function JCPlacement_Cancel()
    placing = false
end

exports('StartPlacement', JCPlacement_Start)
