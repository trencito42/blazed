-- [FORMAT FIX] Lua's string.format does NOT support the %'d digit-grouping
-- conversion (C99-only): it crashed with "invalid conversion '%'' to 'format'"
-- on every /loto, /barbut and money Discord log. Helper instead:
local function groupDigits(n)
    local s = ('%d'):format(math.floor(tonumber(n) or 0))
    local formatted = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (formatted:gsub('^,', ''))
end

-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Hourly Lottery Engine
--  SA:MP-style RPG jackpot with roll-over and anti-inflation tax
-- ═══════════════════════════════════════════════════════════════

SunsetLottery = SunsetLottery or {}
SunsetLottery.TicketPrice = 500
SunsetLottery.TaxBurnRate = 0.15 -- 15% burned
SunsetLottery.StartingJackpot = 15000
SunsetLottery.MaxTicketsPerPlayer = 3

local CurrentJackpot = SunsetLottery.StartingJackpot
local LastWinner = nil
local LastPrize = 0
local LastNumber = nil

CreateThread(function()
    Wait(500)
    pcall(function()
        local state = MySQL.single.await('SELECT * FROM `lottery_state` WHERE `id` = 1')
        if state then
            CurrentJackpot = math.max(SunsetLottery.StartingJackpot, tonumber(state.jackpot) or SunsetLottery.StartingJackpot)
            LastWinner = state.last_winner_name
            LastPrize = tonumber(state.last_winner_prize) or 0
            LastNumber = tonumber(state.last_winning_number)
        else
            MySQL.insert.await('INSERT IGNORE INTO `lottery_state` (`id`, `jackpot`) VALUES (1, ?)', { SunsetLottery.StartingJackpot })
        end
    end)
end)

local function saveState()
    MySQL.update.await([[
        INSERT INTO `lottery_state` (`id`, `jackpot`, `last_winner_name`, `last_winner_prize`, `last_winning_number`)
        VALUES (1, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `jackpot` = VALUES(`jackpot`),
            `last_winner_name` = VALUES(`last_winner_name`),
            `last_winner_prize` = VALUES(`last_winner_prize`),
            `last_winning_number` = VALUES(`last_winning_number`)
    ]], { CurrentJackpot, LastWinner, LastPrize, LastNumber })
end

function SunsetLottery.GetJackpot()
    return CurrentJackpot
end

function SunsetLottery.BuyTicket(source, number)
    number = tonumber(number)
    if not number or number < 1 or number > 100 then
        return false, 'Pick a number between 1 and 100.'
    end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'Character is not loaded.' end

    local cost = SunsetLottery.TicketPrice
    local prizeCut = math.floor(cost * (1 - SunsetLottery.TaxBurnRate))
    local account = (tonumber(char.cash) or 0) >= cost and 'cash'
        or ((tonumber(char.bank) or 0) >= cost and 'bank' or nil)
    if not account then return false, ('You need $%s to buy a ticket.'):format(cost) end
    local newJackpot
    local callOk, committed = pcall(function()
        return MySQL.startTransaction(function(query)
            local stateRows = query.await('SELECT jackpot FROM lottery_state WHERE id=1 FOR UPDATE')
            local state = stateRows and stateRows[1]
            if not state then return false end
            local countRows = query.await('SELECT COUNT(*) AS total FROM lottery_tickets WHERE character_id=?', { char.id })
            if tonumber(countRows and countRows[1] and countRows[1].total) >= SunsetLottery.MaxTicketsPerPlayer then
                return false
            end
            local charged = query.await(
                ('UPDATE characters SET %s=%s-? WHERE id=? AND %s>=?'):format(account, account, account),
                { cost, char.id, cost })
            if tonumber(charged) ~= 1 then return false end
            local ticketId = query.await('INSERT INTO lottery_tickets(character_id,number) VALUES(?,?)', { char.id, number })
            if not ticketId then return false end
            newJackpot = (tonumber(state.jackpot) or SunsetLottery.StartingJackpot) + prizeCut
            local saved = query.await('UPDATE lottery_state SET jackpot=? WHERE id=1', { newJackpot })
            return tonumber(saved) == 1
        end)
    end)
    if not callOk or not committed then
        return false, ('Ticket not purchased: you need $%d and can hold a maximum of %d tickets per round. You were not charged.'):format(
            cost, SunsetLottery.MaxTicketsPerPlayer)
    end
    CurrentJackpot = newJackpot
    exports.sunset_core:RefreshMoney(source)

    TriggerClientEvent('sunset:client:notify', source,
        ('You bought ticket number #%d for $%d! Current jackpot: $%s.'):format(
            number, cost, groupDigits(CurrentJackpot)
        ), 'success', 6000)

    return true
end

function SunsetLottery.Draw()
    local periodKey = os.date('%Y%m%d%H')
    if MySQL.scalar.await('SELECT 1 FROM lottery_draws WHERE period_key=? LIMIT 1', { periodKey }) then return false end
    local winningNumber = math.random(1, 100)
    local draw = { tickets = {}, total = 0, jackpot = CurrentJackpot, share = 0 }
    local callOk, committed = pcall(function()
        return MySQL.startTransaction(function(query)
            local stateRows = query.await('SELECT jackpot FROM lottery_state WHERE id=1 FOR UPDATE')
            local state = stateRows and stateRows[1]
            if not state then return false end
            draw.jackpot = tonumber(state.jackpot) or SunsetLottery.StartingJackpot
            draw.tickets = query.await([[SELECT lt.character_id,c.firstname,c.lastname FROM lottery_tickets lt
                JOIN characters c ON c.id=lt.character_id WHERE lt.number=?]], { winningNumber }) or {}
            local totals = query.await('SELECT COUNT(*) AS total FROM lottery_tickets')
            draw.total = tonumber(totals and totals[1] and totals[1].total) or 0
            draw.share = #draw.tickets > 0 and math.floor(draw.jackpot / #draw.tickets) or 0
            local names = {}
            for _, winner in ipairs(draw.tickets) do
                local paid = query.await('UPDATE characters SET bank=bank+? WHERE id=?', { draw.share, winner.character_id })
                if tonumber(paid) ~= 1 then return false end
                names[#names + 1] = ((winner.firstname or '') .. ' ' .. (winner.lastname or '')):gsub('^%s+',''):gsub('%s+$','')
            end
            local nextJackpot = #draw.tickets > 0 and SunsetLottery.StartingJackpot or draw.jackpot
            query.await('DELETE FROM lottery_tickets')
            local stateSaved = query.await([[UPDATE lottery_state SET jackpot=?,last_winner_name=?,
                last_winner_prize=?,last_winning_number=? WHERE id=1]],
                { nextJackpot, #names > 0 and table.concat(names, ', ') or nil,
                    #names > 0 and draw.jackpot or 0, winningNumber })
            if tonumber(stateSaved) ~= 1 then return false end
            query.await([[INSERT INTO lottery_draws(period_key,winning_number,prize,total_tickets,winners_json)
                VALUES(?,?,?,?,?)]], { periodKey, winningNumber, #names > 0 and draw.jackpot or 0,
                    draw.total, json.encode(names) })
            draw.names = names
            draw.nextJackpot = nextJackpot
            return true
        end)
    end)
    if not callOk or not committed then
        print(('^1[sunset_lottery]^7 draw %s failed safely; tickets and jackpot were kept'):format(periodKey))
        return false
    end
    LastNumber = winningNumber
    CurrentJackpot = draw.nextJackpot

    if #draw.tickets > 0 then
        for _, winner in ipairs(draw.tickets) do
            for _, pid in ipairs(GetPlayers()) do
                local onlineSrc = tonumber(pid)
                local online = exports.sunset_core:GetCharacter(onlineSrc)
                if online and tonumber(online.id) == tonumber(winner.character_id) then
                    exports.sunset_core:RefreshMoney(onlineSrc)
                    TriggerClientEvent('sunset:client:notify', onlineSrc,
                        ('YOU WON THE LOTTERY! $%s has been paid to your bank account!'):format(
                            groupDigits(draw.share)), 'success', 15000)
                    break
                end
            end
        end
        local namesStr = table.concat(draw.names, ', ')
        LastWinner = namesStr
        LastPrize = draw.jackpot

        -- Server broadcast
        local msg = ('^2[LOTTO] ^7Winning number: ^3#%d^7! Congratulations to the winners: ^2%s^7! Total prize: ^2$%s^7!'):format(
            winningNumber, namesStr, groupDigits(draw.jackpot)
        )
        TriggerClientEvent('chat:addMessage', -1, { color = { 0, 255, 204 }, args = { 'LOTTERY', msg } })

        CurrentJackpot = SunsetLottery.StartingJackpot
    else
        LastWinner = nil
        LastPrize = 0

        -- Roll-over
        local msg = ('^3[LOTTO] ^7The drawn number was ^3#%d^7 (%d tickets played). No winner! The ^2$%s^7 jackpot rolls over to the next hour!'):format(
            winningNumber, draw.total, groupDigits(CurrentJackpot)
        )
        TriggerClientEvent('chat:addMessage', -1, { color = { 0, 255, 204 }, args = { 'LOTTERY', msg } })
    end

    return true
end

-- Commands
local function runLotteryCommand(source, args)
    local sub = args[1] and string.lower(args[1])
    if sub == 'info' then
        local tickets = 0
        local char = exports.sunset_core:GetCharacter(source)
        local myNumbers = {}
        if char then
            local myRows = MySQL.query.await('SELECT `number` FROM `lottery_tickets` WHERE `character_id` = ?', { char.id }) or {}
            for _, r in ipairs(myRows) do table.insert(myNumbers, '#' .. r.number) end
        end
        local totalTickets = MySQL.scalar.await('SELECT COUNT(*) FROM `lottery_tickets`') or 0
        local myStr = #myNumbers > 0 and table.concat(myNumbers, ', ') or 'None'

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 204 },
            args = { 'LOTTERY', ('Current jackpot: ^2$%s^7 | Ticket price: ^3$%d^7 | Tickets sold: ^3%d^7 | Your tickets: ^2%s^7'):format(
                groupDigits(CurrentJackpot),
                SunsetLottery.TicketPrice,
                totalTickets,
                myStr
            ) }
        })
        return
    end

    local num = tonumber(sub)
    if not num then
        TriggerClientEvent('sunset:client:notify', source, 'Usage: /loto [1-100] or /loto info', 'info')
        return
    end

    local ok, err = SunsetLottery.BuyTicket(source, num)
    if not ok and err then
        TriggerClientEvent('sunset:client:notify', source, err, 'error')
    end
end

RegisterCommand('loto', runLotteryCommand, false)

RegisterCommand('lottery', function(source, args)
    runLotteryCommand(source, args or {})
end, false)

TriggerEvent('chat:addSuggestion', '/loto', 'Buy a ticket for the hourly lottery or view the jackpot', {
    { name = 'number/info', help = 'Number (1-100) or "info"' }
})
TriggerEvent('chat:addSuggestion', '/lottery', 'Alias for /loto', {
    { name = 'number/info', help = 'Number (1-100) or "info"' }
})
