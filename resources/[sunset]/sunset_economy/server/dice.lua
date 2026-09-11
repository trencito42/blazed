-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Dice / Barbut System
--  Multiplayer wagering with anti-inflation house burn
-- ═══════════════════════════════════════════════════════════════

local PendingChallenges = {}
local DICE_TAX_RATE = 0.03 -- 3% burned
local MAX_DICE_BET = 500000 -- $500,000 max bet
local MIN_DICE_BET = 100

local function getDist(src1, src2)
    local p1 = GetPlayerPed(src1)
    local p2 = GetPlayerPed(src2)
    if not p1 or not p2 or p1 == 0 or p2 == 0 then return 999.0 end
    local c1 = GetEntityCoords(p1)
    local c2 = GetEntityCoords(p2)
    return #(c1 - c2)
end

local function broadcastNearby(src, msg)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    for _, pid in ipairs(GetPlayers()) do
        local targetSrc = tonumber(pid)
        if targetSrc then
            local tPed = GetPlayerPed(targetSrc)
            if tPed and tPed ~= 0 and #(GetEntityCoords(tPed) - coords) <= 15.0 then
                TriggerClientEvent('chat:addMessage', targetSrc, {
                    color = { 255, 180, 0 },
                    args = { 'BARBUT', msg }
                })
            end
        end
    end
end

local function executeDiceMatch(challengerSrc, targetSrc, bet)
    local cChar = exports.sunset_core:GetCharacter(challengerSrc)
    local tChar = exports.sunset_core:GetCharacter(targetSrc)
    if not cChar or not tChar then return end

    if not exports.sunset_core:RemoveMoney(challengerSrc, 'cash', bet, 'dice_wager') then
        TriggerClientEvent('sunset:client:notify', challengerSrc, 'Nu mai ai banii necesari.', 'error')
        TriggerClientEvent('sunset:client:notify', targetSrc, 'Adversarul nu mai are banii necesari.', 'error')
        return
    end

    if not exports.sunset_core:RemoveMoney(targetSrc, 'cash', bet, 'dice_wager') then
        exports.sunset_core:AddMoney(challengerSrc, 'cash', bet, 'dice_refund')
        TriggerClientEvent('sunset:client:notify', targetSrc, 'Nu mai ai banii necesari.', 'error')
        TriggerClientEvent('sunset:client:notify', challengerSrc, 'Adversarul nu mai are banii necesari.', 'error')
        return
    end

    TriggerClientEvent('sunset:economy:playDiceAnim', challengerSrc)
    TriggerClientEvent('sunset:economy:playDiceAnim', targetSrc)

    SetTimeout(1800, function()
        if not GetPlayerName(challengerSrc) or not GetPlayerName(targetSrc) then
            -- Fallback refund if someone disconnected during roll
            if GetPlayerName(challengerSrc) then exports.sunset_core:AddMoney(challengerSrc, 'cash', bet, 'dice_refund') end
            if GetPlayerName(targetSrc) then exports.sunset_core:AddMoney(targetSrc, 'cash', bet, 'dice_refund') end
            return
        end

        local cDie1, cDie2 = math.random(1, 6), math.random(1, 6)
        local tDie1, tDie2 = math.random(1, 6), math.random(1, 6)
        local cTotal = cDie1 + cDie2
        local tTotal = tDie1 + tDie2

        while cTotal == tTotal do
            cDie1, cDie2 = math.random(1, 6), math.random(1, 6)
            tDie1, tDie2 = math.random(1, 6), math.random(1, 6)
            cTotal = cDie1 + cDie2
            tTotal = tDie1 + tDie2
        end

        local cName = (cChar.firstname or '') .. ' ' .. (cChar.lastname or '')
        local tName = (tChar.firstname or '') .. ' ' .. (tChar.lastname or '')

        local totalPot = bet * 2
        local tax = math.floor(totalPot * DICE_TAX_RATE)
        local prize = totalPot - tax

        local winnerSrc, winnerName, winnerScore, loserScore, loserName
        if cTotal > tTotal then
            winnerSrc = challengerSrc
            winnerName = cName
            winnerScore = ('%d (%d+%d)'):format(cTotal, cDie1, cDie2)
            loserScore = ('%d (%d+%d)'):format(tTotal, tDie1, tDie2)
            loserName = tName
        else
            winnerSrc = targetSrc
            winnerName = tName
            winnerScore = ('%d (%d+%d)'):format(tTotal, tDie1, tDie2)
            loserScore = ('%d (%d+%d)'):format(cTotal, cDie1, cDie2)
            loserName = cName
        end

        exports.sunset_core:AddMoney(winnerSrc, 'cash', prize, 'dice_win')

        local broadcastMsg = ('^3%s^7 a dat ^2%s^7 vs ^3%s^7 a dat ^1%s^7. ^2%s a castigat $%s^7! (Taxa arsa: $%s)'):format(
            winnerName, winnerScore, loserName, loserScore, winnerName,
            string.format('%\'d', prize):gsub('\'', ','),
            string.format('%\'d', tax):gsub('\'', ',')
        )
        broadcastNearby(winnerSrc, broadcastMsg)
    end)
end

RegisterCommand('barbut', function(source, args)
    local sub = args[1] and string.lower(args[1])
    if sub == 'accept' then
        local challenge = PendingChallenges[source]
        if not challenge then
            TriggerClientEvent('sunset:client:notify', source, 'Nu ai nicio cerere activa de barbut.', 'error')
            return
        end
        PendingChallenges[source] = nil

        local challenger = challenge.from
        if not GetPlayerName(challenger) then
            TriggerClientEvent('sunset:client:notify', source, 'Jucatorul care te-a provocat s-a deconectat.', 'error')
            return
        end

        if getDist(source, challenger) > 5.0 then
            TriggerClientEvent('sunset:client:notify', source, 'Trebuie sa fii langa jucator pentru a juca.', 'error')
            return
        end

        executeDiceMatch(challenger, source, challenge.bet)
        return
    elseif sub == 'decline' then
        if PendingChallenges[source] then
            local challenger = PendingChallenges[source].from
            PendingChallenges[source] = nil
            TriggerClientEvent('sunset:client:notify', source, 'Ai refuzat partida de barbut.', 'info')
            if GetPlayerName(challenger) then
                TriggerClientEvent('sunset:client:notify', challenger, 'Provocarea de barbut a fost refuzata.', 'warning')
            end
        end
        return
    end

    local targetId = tonumber(args[1])
    local bet = tonumber(args[2])

    if not targetId or not bet or bet < MIN_DICE_BET then
        TriggerClientEvent('sunset:client:notify', source, ('Utilizare: /barbut [id_jucator] [suma min. $%d]'):format(MIN_DICE_BET), 'info')
        return
    end

    if bet > MAX_DICE_BET then
        TriggerClientEvent('sunset:client:notify', source, ('Miza maxima este de $%s.'):format(string.format('%\'d', MAX_DICE_BET):gsub('\'', ',')), 'error')
        return
    end

    if targetId == source then
        TriggerClientEvent('sunset:client:notify', source, 'Nu poti juca barbut cu tine insuti.', 'error')
        return
    end

    if not GetPlayerName(targetId) then
        TriggerClientEvent('sunset:client:notify', source, 'Jucatorul nu a fost gasit.', 'error')
        return
    end

    if getDist(source, targetId) > 4.0 then
        TriggerClientEvent('sunset:client:notify', source, 'Jucatorul este prea departe (trebuie sa fiti aproape).', 'error')
        return
    end

    local cCash = exports.sunset_core:GetCharacter(source)
    local tCash = exports.sunset_core:GetCharacter(targetId)
    if not cCash or (tonumber(cCash.cash) or 0) < bet then
        TriggerClientEvent('sunset:client:notify', source, 'Nu ai destui bani cash la tine.', 'error')
        return
    end
    if not tCash or (tonumber(tCash.cash) or 0) < bet then
        TriggerClientEvent('sunset:client:notify', source, 'Jucatorul provocat nu are destui bani cash.', 'error')
        return
    end

    PendingChallenges[targetId] = { from = source, bet = bet, expires = os.time() + 30 }

    local cName = (cCash.firstname or '') .. ' ' .. (cCash.lastname or '')
    TriggerClientEvent('sunset:client:notify', source, ('I-ai trimis o provocare de barbut lui %s pe $%s.'):format(
        (tCash.firstname or '') .. ' ' .. (tCash.lastname or ''),
        string.format('%\'d', bet):gsub('\'', ',')
    ), 'info')

    TriggerClientEvent('chat:addMessage', targetId, {
        color = { 255, 180, 0 },
        args = { 'BARBUT', ('^2%s^7 te-a provocat la barbut pe ^2$%s^7! Scrie ^3/barbut accept^7 sau ^1/barbut decline^7 (30s).'):format(
            cName, string.format('%\'d', bet):gsub('\'', ',')
        ) }
    })

    SetTimeout(30000, function()
        if PendingChallenges[targetId] and PendingChallenges[targetId].from == source then
            PendingChallenges[targetId] = nil
        end
    end)
end, false)

RegisterCommand('dice', function(source, args)
    ExecuteCommand(('barbut %s'):format(table.concat(args, ' ')))
end, false)

TriggerEvent('chat:addSuggestion', '/barbut', 'Provoaca un jucator din apropiere la barbut', {
    { name = 'id/accept/decline', help = 'ID-ul jucatorului sau accept/decline' },
    { name = 'suma', help = 'Suma pariata (cash)' }
})
TriggerEvent('chat:addSuggestion', '/dice', 'Alias pentru /barbut', {
    { name = 'id/accept/decline', help = 'ID-ul jucatorului sau accept/decline' },
    { name = 'suma', help = 'Suma pariata (cash)' }
})
