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
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `lottery_state` (
                `id` INT PRIMARY KEY DEFAULT 1,
                `jackpot` INT UNSIGNED NOT NULL DEFAULT 15000,
                `last_winner_name` VARCHAR(64) DEFAULT NULL,
                `last_winner_prize` INT UNSIGNED DEFAULT 0,
                `last_winning_number` INT DEFAULT NULL,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            );
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `lottery_tickets` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `character_id` INT NOT NULL,
                `number` INT NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                KEY `idx_char_ticket` (`character_id`)
            );
        ]])
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
        return false, 'Alege un numar intre 1 si 100.'
    end

    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'Caracterul nu este incarcat.' end

    local existing = MySQL.scalar.await(
        'SELECT COUNT(*) FROM `lottery_tickets` WHERE `character_id` = ?',
        { char.id }
    )
    if tonumber(existing) >= SunsetLottery.MaxTicketsPerPlayer then
        return false, ('Ai atins limita maxima de %d bilete pe runda.'):format(SunsetLottery.MaxTicketsPerPlayer)
    end

    local cost = SunsetLottery.TicketPrice
    if not exports.sunset_core:RemoveMoney(source, 'cash', cost, 'lottery_ticket') then
        if not exports.sunset_core:RemoveMoney(source, 'bank', cost, 'lottery_ticket') then
            return false, ('Ai nevoie de $%s pentru a cumpara un bilet.'):format(cost)
        end
    end

    local prizeCut = math.floor(cost * (1 - SunsetLottery.TaxBurnRate))
    CurrentJackpot = CurrentJackpot + prizeCut
    saveState()

    MySQL.insert.await(
        'INSERT INTO `lottery_tickets` (`character_id`, `number`) VALUES (?, ?)',
        { char.id, number }
    )

    TriggerClientEvent('sunset:client:notify', source,
        ('Ai cumparat biletul cu numarul #%d pentru $%d! Potul actual: $%s.'):format(
            number, cost, string.format('%\'d', CurrentJackpot):gsub('\'', ',')
        ), 'success', 6000)

    return true
end

function SunsetLottery.Draw()
    local winningNumber = math.random(1, 100)
    LastNumber = winningNumber

    local tickets = MySQL.query.await([[
        SELECT lt.character_id, c.firstname, c.lastname
        FROM `lottery_tickets` lt
        JOIN `characters` c ON c.id = lt.character_id
        WHERE lt.number = ?
    ]], { winningNumber }) or {}

    local totalTickets = MySQL.scalar.await('SELECT COUNT(*) FROM `lottery_tickets`') or 0

    if #tickets > 0 then
        local share = math.floor(CurrentJackpot / #tickets)
        local winnerNames = {}

        for _, winner in ipairs(tickets) do
            local fullName = (winner.firstname or '') .. ' ' .. (winner.lastname or '')
            table.insert(winnerNames, fullName)

            local onlineSrc = nil
            for _, pid in ipairs(GetPlayers()) do
                local s = tonumber(pid)
                local pChar = exports.sunset_core:GetCharacter(s)
                if pChar and pChar.id == winner.character_id then
                    onlineSrc = s
                    break
                end
            end

            if onlineSrc then
                exports.sunset_core:AddMoney(onlineSrc, 'bank', share, 'lottery_jackpot')
                TriggerClientEvent('sunset:client:notify', onlineSrc,
                    ('AI CASTIGAT LA LOTERIE! Ai incasat $%s in contul bancar!'):format(
                        string.format('%\'d', share):gsub('\'', ',')
                    ), 'success', 15000)
            else
                MySQL.update.await('UPDATE `characters` SET `bank` = `bank` + ? WHERE `id` = ?', {
                    share, winner.character_id
                })
            end
        end

        local namesStr = table.concat(winnerNames, ', ')
        LastWinner = namesStr
        LastPrize = CurrentJackpot

        -- Server broadcast
        local msg = ('^2[LOTTO] ^7Numarul extras: ^3#%d^7! Felicitari castigatorilor: ^2%s^7! Premiu total: ^2$%s^7!'):format(
            winningNumber, namesStr, string.format('%\'d', CurrentJackpot):gsub('\'', ',')
        )
        TriggerClientEvent('chat:addMessage', -1, { color = { 0, 255, 204 }, args = { 'LOTERIE', msg } })

        CurrentJackpot = SunsetLottery.StartingJackpot
    else
        LastWinner = nil
        LastPrize = 0

        -- Roll-over
        local msg = ('^3[LOTTO] ^7Numarul extras a fost ^3#%d^7 (%d bilete jucate). Niciun castigator! Potul de ^2$%s^7 se reporteaza pentru ora urmatoare!'):format(
            winningNumber, totalTickets, string.format('%\'d', CurrentJackpot):gsub('\'', ',')
        )
        TriggerClientEvent('chat:addMessage', -1, { color = { 0, 255, 204 }, args = { 'LOTERIE', msg } })
    end

    -- Clear round tickets
    MySQL.query.await('TRUNCATE TABLE `lottery_tickets`')
    saveState()
end

-- Commands
RegisterCommand('loto', function(source, args)
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
        local myStr = #myNumbers > 0 and table.concat(myNumbers, ', ') or 'Niciunul'

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 204 },
            args = { 'LOTERIE', ('Pot actual: ^2$%s^7 | Pret bilet: ^3$%d^7 | Bilete vandute: ^3%d^7 | Biletele tale: ^2%s^7'):format(
                string.format('%\'d', CurrentJackpot):gsub('\'', ','),
                SunsetLottery.TicketPrice,
                totalTickets,
                myStr
            ) }
        })
        return
    end

    local num = tonumber(sub)
    if not num then
        TriggerClientEvent('sunset:client:notify', source, 'Foloseste: /loto [1-100] sau /loto info', 'info')
        return
    end

    local ok, err = SunsetLottery.BuyTicket(source, num)
    if not ok and err then
        TriggerClientEvent('sunset:client:notify', source, err, 'error')
    end
end, false)

RegisterCommand('lottery', function(source, args)
    ExecuteCommand(('loto %s'):format(table.concat(args, ' ')))
end, false)

TriggerEvent('chat:addSuggestion', '/loto', 'Cumpara un bilet la loteria orara sau vezi potul', {
    { name = 'numar/info', help = 'Numar (1-100) sau "info"' }
})
TriggerEvent('chat:addSuggestion', '/lottery', 'Alias pentru /loto', {
    { name = 'numar/info', help = 'Numar (1-100) sau "info"' }
})
