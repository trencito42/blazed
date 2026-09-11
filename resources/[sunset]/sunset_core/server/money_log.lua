Sunset = Sunset or {}

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
