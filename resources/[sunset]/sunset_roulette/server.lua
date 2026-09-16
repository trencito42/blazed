-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — 3D Diamond Casino Roulette (server.lua)
-- ═══════════════════════════════════════════════════════════════

local takenChair, activeTables = {}, {}

local function countChips(source)
    if GetResourceState('sunset_inventory') ~= 'started' then return 0 end
    local ok, count = pcall(function()
        return exports.sunset_inventory:CountItem(source, 'casino_chips')
    end)
    return ok and (tonumber(count) or 0) or 0
end

local function giveChips(source, amount)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports.sunset_inventory:AddItem(source, 'casino_chips', math.floor(amount))
    end)
    return ok and res ~= false
end

local function takeChips(source, amount)
    if GetResourceState('sunset_inventory') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports.sunset_inventory:RemoveItem(source, 'casino_chips', math.floor(amount))
    end)
    return ok and res == true
end

local function notify(source, msg, kind)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', 5000)
end

RegisterNetEvent('dc-casino:roulette:server:syncChairs', function(actionType, chairCoords)
    local src = source
    local playerCoords = GetEntityCoords(GetPlayerPed(src))

    if actionType == 'enter' and #(playerCoords - chairCoords) >= 5 then return end

    if actionType == 'enter' then
        if takenChair[src] then
            TriggerClientEvent('dc-casino:roulette:client:syncChairs', -1, 'leave', takenChair[src])
        end
        takenChair[src] = chairCoords
    elseif actionType == 'leave' then
        takenChair[src] = nil
    end
    TriggerClientEvent('dc-casino:roulette:client:syncChairs', -1, actionType, chairCoords)
end)

local function checkActivePlayers(tableIndex)
    ::redo::
    for i = 1, #activeTables[tableIndex] do
        local pSrc = activeTables[tableIndex][i]
        if not DoesPlayerExist(pSrc) or not takenChair[pSrc] then
            table.remove(activeTables[tableIndex], i)
            goto redo
        end
    end

    return #activeTables[tableIndex] > 0
end

local function startTableHandler(tableIndex)
    CreateThread(function()
        while #activeTables[tableIndex] > 0 do
            if not checkActivePlayers(tableIndex) then break end

            for i = 1, #activeTables[tableIndex] do
                TriggerClientEvent('dc-casino:roulette:client:startBetting', activeTables[tableIndex][i], tableIndex)
            end

            Wait(30000)

            if not checkActivePlayers(tableIndex) then break end

            local randomResult = math.random(1, 38)
            TriggerClientEvent('dc-casino:roulette:client:startRoulette', -1, randomResult, tableIndex)
            lib.callback.await('dc-casino:roulette:callback:checkObject', activeTables[tableIndex][1])

            local playerBets = {}

            for i = 1, #activeTables[tableIndex] do
                local pSrc = activeTables[tableIndex][i]
                local clientInput = lib.callback.await('dc-casino:roulette:callback:getClientInput', pSrc)
                playerBets[#playerBets + 1] = {
                    source = pSrc,
                    chosen = clientInput or {}
                }
            end

            for i = 1, #playerBets do
                local pSrc = playerBets[i].source
                local bettingAmount, potentialReward = 0, 0
                for j = 1, #playerBets[i].chosen do
                    bettingAmount = bettingAmount + (playerBets[i].chosen[j].amount or 0)
                    for k = 1, #(playerBets[i].chosen[j].bets or {}) do
                        if playerBets[i].chosen[j].bets[k] == randomResult then
                            local mult = RouletteRewards[#playerBets[i].chosen[j].bets] or 1
                            potentialReward = potentialReward + (playerBets[i].chosen[j].amount * mult + playerBets[i].chosen[j].amount)
                        end
                    end
                end

                if bettingAmount > 0 then
                    local chips = countChips(pSrc)
                    if chips >= bettingAmount and takeChips(pSrc, bettingAmount) then
                        if potentialReward > 0 then
                            giveChips(pSrc, potentialReward)
                            notify(pSrc, ('You won %d chips on Roulette!'):format(potentialReward), 'success')
                        else
                            notify(pSrc, 'No win this round.', 'info')
                        end
                    else
                        notify(pSrc, 'You do not have enough chips for these bets.', 'error')
                    end
                end
            end

            Wait(1000)
        end
    end)
end

RegisterNetEvent('dc-casino:roulette:server:enterTable', function(rouletteIndex)
    local src = source
    local playerCoords = GetEntityCoords(GetPlayerPed(src))

    if not takenChair[src] then return end
    if not RouletteLocations[rouletteIndex] or #(playerCoords - RouletteLocations[rouletteIndex].coords.xyz) >= 8 then return end

    if activeTables[rouletteIndex] and activeTables[rouletteIndex][1] then
        activeTables[rouletteIndex][#activeTables[rouletteIndex]+1] = src
    else
        activeTables[rouletteIndex] = { src }
        startTableHandler(rouletteIndex)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if takenChair[src] then
        TriggerClientEvent('dc-casino:roulette:client:syncChairs', -1, 'leave', takenChair[src])
        takenChair[src] = nil
    end
end)
