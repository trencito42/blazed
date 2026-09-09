Sunset = Sunset or {}

CreateThread(function()
    Wait(500)
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `money_transactions` (
                `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `character_id` INT UNSIGNED NOT NULL,
                `account` ENUM('cash', 'bank') NOT NULL DEFAULT 'bank',
                `direction` ENUM('in', 'out') NOT NULL,
                `amount` INT NOT NULL,
                `reason` VARCHAR(64) NOT NULL DEFAULT 'unknown',
                `balance_after` INT NOT NULL DEFAULT 0,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                KEY `idx_money_tx_char` (`character_id`, `created_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])
    end)
end)

function Sunset.LogMoneyTransaction(characterId, account, direction, amount, reason, balanceAfter)
    characterId = tonumber(characterId)
    amount = math.floor(tonumber(amount) or 0)
    if not characterId or characterId < 1 or amount <= 0 then return end
    direction = direction == 'in' and 'in' or 'out'
    account = account == 'cash' and 'cash' or 'bank'
    reason = tostring(reason or 'unknown'):sub(1, 64)
    balanceAfter = math.floor(tonumber(balanceAfter) or 0)
    CreateThread(function()
        pcall(function()
            MySQL.insert.await([[
                INSERT INTO money_transactions (character_id, account, direction, amount, reason, balance_after)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], { characterId, account, direction, amount, reason, balanceAfter })
        end)
    end)
end

function Sunset.GetMoneyHistory(characterId, limit)
    characterId = tonumber(characterId)
    limit = math.min(50, math.max(1, tonumber(limit) or 30))
    if not characterId then return {} end
    local rows = MySQL.query.await([[
        SELECT account, direction, amount, reason, balance_after, created_at
        FROM money_transactions
        WHERE character_id = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { characterId, limit })
    return rows or {}
end

exports('LogMoneyTransaction', Sunset.LogMoneyTransaction)
exports('GetMoneyHistory', Sunset.GetMoneyHistory)
