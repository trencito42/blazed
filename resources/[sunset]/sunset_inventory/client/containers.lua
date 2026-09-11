-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Container Client (Trunk, Glovebox, Safe)
-- ═══════════════════════════════════════════════════════════════

local ActiveContainer = nil

local function getClosestVehicle(maxDist)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, maxDist or 4.0, 0, 71)
    if veh ~= 0 and DoesEntityExist(veh) then
        return veh
    end
    return nil
end

local function printContainerList(title, data)
    TriggerClientEvent('chat:addMessage', -1, {}) -- ensure chat initialized
    TriggerEvent('chat:addMessage', {
        color = { 0, 255, 204 },
        args = { title, ('Capacitate: ^3%.1fkg / %.1fkg^7'):format(data.weight or 0, data.maxWeight or 50) }
    })
    if #data.items == 0 then
        TriggerEvent('chat:addMessage', {
            color = { 180, 180, 180 },
            args = { title, 'Compartimentul este gol.' }
        })
    else
        for _, item in ipairs(data.items) do
            TriggerEvent('chat:addMessage', {
                color = { 240, 240, 240 },
                args = { '  •', ('^2%s^7 x^3%d^7 (%.1fkg)'):format(item.label or item.item, item.count, (item.weight or 0) * item.count) }
            })
        end
    end
    TriggerEvent('chat:addMessage', {
        color = { 120, 120, 120 },
        args = { 'INFO', ('Foloseste ^3/%s put [nume_obiect] [cantitate]^7 sau ^3/%s take [nume_obiect] [cantitate]^7'):format(data.type, data.type) }
    })
end

-- ── TRUNK ───────────────────────────────────────────────────
RegisterCommand('trunk', function(source, args)
    local sub = args[1] and string.lower(args[1])
    local ped = PlayerPedId()

    local veh = getClosestVehicle(4.5)
    if not veh then
        return exports.sunset_ui:Notify('Nu exista niciun vehicul in apropiere.', 'error')
    end

    local lock = GetVehicleDoorLockStatus(veh)
    if lock > 1 then
        return exports.sunset_ui:Notify('Vehiculul este incuiat.', 'warning')
    end

    local plate = string.upper(GetVehicleNumberPlateText(veh)):gsub('%s+', '')

    if sub == 'put' or sub == 'adauga' then
        local item = args[2] and string.lower(args[2])
        local count = tonumber(args[3]) or 1
        if not item then
            return exports.sunset_ui:Notify('Utilizare: /trunk put [item] [cantitate]', 'info')
        end
        local res, err = Sunset.AwaitCallback('sunset:container:deposit', 'trunk', plate, item, count)
        if res and res.ok then
            exports.sunset_ui:Notify(('Ai depus x%d %s in portbagaj.'):format(count, item), 'success')
            printContainerList('PORTBAGAJ ' .. plate, res)
        else
            exports.sunset_ui:Notify(err or 'Eroare la depunere.', 'error')
        end
        return
    elseif sub == 'take' or sub == 'ia' then
        local item = args[2] and string.lower(args[2])
        local count = tonumber(args[3]) or 1
        if not item then
            return exports.sunset_ui:Notify('Utilizare: /trunk take [item] [cantitate]', 'info')
        end
        local res, err = Sunset.AwaitCallback('sunset:container:withdraw', 'trunk', plate, item, count)
        if res and res.ok then
            exports.sunset_ui:Notify(('Ai scos x%d %s din portbagaj.'):format(count, item), 'success')
            printContainerList('PORTBAGAJ ' .. plate, res)
        else
            exports.sunset_ui:Notify(err or 'Eroare la retragere.', 'error')
        end
        return
    end

    -- Open trunk door
    SetVehicleDoorOpen(veh, 5, false, false)
    SetTimeout(12000, function()
        if DoesEntityExist(veh) then SetVehicleDoorShut(veh, 5, false) end
    end)

    local res, err = Sunset.AwaitCallback('sunset:container:open', 'trunk', plate)
    if res then
        printContainerList('PORTBAGAJ ' .. plate, res)
    else
        exports.sunset_ui:Notify(err or 'Nu s-a putut deschide portbagajul.', 'error')
    end
end, false)

RegisterCommand('portbagaj', function(_, args)
    ExecuteCommand(('trunk %s'):format(table.concat(args, ' ')))
end, false)

TriggerEvent('chat:addSuggestion', '/trunk', 'Deschide sau gestioneaza portbagajul vehiculului', {
    { name = 'put/take', help = 'Operatiune optionala: "put" sau "take"' },
    { name = 'obiect', help = 'Numele obiectului (ex: water, repairkit)' },
    { name = 'cantitate', help = 'Numarul de bucati' }
})
TriggerEvent('chat:addSuggestion', '/portbagaj', 'Alias pentru /trunk')

-- ── GLOVEBOX ────────────────────────────────────────────────
RegisterCommand('glovebox', function(source, args)
    local sub = args[1] and string.lower(args[1])
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = getClosestVehicle(2.5) end

    if not veh or veh == 0 then
        return exports.sunset_ui:Notify('Trebuie sa fii in vehicul sau langa el.', 'error')
    end

    local plate = string.upper(GetVehicleNumberPlateText(veh)):gsub('%s+', '')

    if sub == 'put' or sub == 'adauga' then
        local item = args[2] and string.lower(args[2])
        local count = tonumber(args[3]) or 1
        if not item then
            return exports.sunset_ui:Notify('Utilizare: /glovebox put [item] [cantitate]', 'info')
        end
        local res, err = Sunset.AwaitCallback('sunset:container:deposit', 'glovebox', plate, item, count)
        if res and res.ok then
            exports.sunset_ui:Notify(('Ai pus x%d %s in torpedou.'):format(count, item), 'success')
            printContainerList('TORPEDOU ' .. plate, res)
        else
            exports.sunset_ui:Notify(err or 'Eroare la depunere.', 'error')
        end
        return
    elseif sub == 'take' or sub == 'ia' then
        local item = args[2] and string.lower(args[2])
        local count = tonumber(args[3]) or 1
        if not item then
            return exports.sunset_ui:Notify('Utilizare: /glovebox take [item] [cantitate]', 'info')
        end
        local res, err = Sunset.AwaitCallback('sunset:container:withdraw', 'glovebox', plate, item, count)
        if res and res.ok then
            exports.sunset_ui:Notify(('Ai scos x%d %s din torpedou.'):format(count, item), 'success')
            printContainerList('TORPEDOU ' .. plate, res)
        else
            exports.sunset_ui:Notify(err or 'Eroare la retragere.', 'error')
        end
        return
    end

    local res, err = Sunset.AwaitCallback('sunset:container:open', 'glovebox', plate)
    if res then
        printContainerList('TORPEDOU ' .. plate, res)
    else
        exports.sunset_ui:Notify(err or 'Nu s-a putut deschide torpedoul.', 'error')
    end
end, false)

RegisterCommand('torpedou', function(_, args)
    ExecuteCommand(('glovebox %s'):format(table.concat(args, ' ')))
end, false)

TriggerEvent('chat:addSuggestion', '/glovebox', 'Deschide sau gestioneaza torpedoul vehiculului', {
    { name = 'put/take', help = 'Operatiune: "put" sau "take"' },
    { name = 'obiect', help = 'Numele obiectului' },
    { name = 'cantitate', help = 'Numarul de bucati' }
})
TriggerEvent('chat:addSuggestion', '/torpedou', 'Alias pentru /glovebox')
