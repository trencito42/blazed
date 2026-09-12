local PendingEmail = {}

-- [AUDIT P2-04] Brute-force protection: per-source failed-login counter with
-- exponential lockout. Generic callback rate limit (12/s) alone allowed fast
-- online password guessing and cheap scrypt CPU-DoS.
local LoginFails = {}
local LOCKOUT_STEP_MS = 5000 -- 5s, 10s, 20s, ... capped at 5 minutes

local function loginLocked(source)
    local rec = LoginFails[source]
    if not rec or rec.count < 5 then return false end
    local backoff = math.min(300000, LOCKOUT_STEP_MS * (2 ^ (rec.count - 5)))
    return (GetGameTimer() - rec.lastAt) < backoff, backoff
end

local function recordLoginFail(source)
    local rec = LoginFails[source]
    if not rec then rec = { count = 0, lastAt = 0 } LoginFails[source] = rec end
    rec.count = rec.count + 1
    rec.lastAt = GetGameTimer()
end

local function clearLoginFails(source)
    LoginFails[source] = nil
end

AddEventHandler('playerDropped', function()
    LoginFails[source] = nil
end)

local function deviceHash(source)
    local license = GetPlayerIdentifierByType(source, 'license') or ''
    return exports.sunset_auth:HashToken(license)
end

local function issueQuickToken(source, accountId)
    local token = exports.sunset_auth:GenerateQuickToken()
    if type(token) ~= 'string' or token == '' then return nil end
    local hash = exports.sunset_auth:HashToken(token)
    MySQL.update.await('DELETE FROM auth_quick_tokens WHERE account_id = ? AND (device_hash = ? OR expires_at <= NOW())', {
        accountId, deviceHash(source),
    })
    local id = MySQL.insert.await([[
        INSERT INTO auth_quick_tokens (account_id, token_hash, device_hash, expires_at)
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))
    ]], { accountId, hash, deviceHash(source) })
    return id and token or nil
end

local function clearPending(source)
    PendingEmail[source] = nil
end

AddEventHandler('playerDropped', function()
    clearPending(source)
end)

local function normalizeEmail(email)
    if type(email) ~= 'string' then return nil end
    email = email:match('^%s*(.-)%s*$')
    if not email or email == '' then return nil end
    return email:lower()
end

local function validateEmail(email)
    local normalized = normalizeEmail(email)
    if not normalized then
        return false, 'Enter a valid email address'
    end
    if #normalized > 254 then
        return false, 'Email is too long'
    end
    if not normalized:match('^[%w%.%+%-]+@[%w%-]+%.[%a%.]+$') then
        return false, 'Enter a valid email address'
    end
    return true, normalized
end

local function emailMissing(value)
    return type(value) ~= 'string' or value:match('^%s*$')
end

local function validateUsername(username)
    if not username or #username < 3 or #username > 20 then
        return false, 'Username must be 3-20 characters'
    end
    if not username:match('^[%w_]+$') then
        return false, 'Username: letters, numbers, underscore only'
    end
    return true
end

local function validatePassword(password)
    if not password or #password < 6 then
        return false, 'Password must be at least 6 characters'
    end
    return true
end

local function emailTaken(email, ignoreAccountId)
    local query = 'SELECT id FROM accounts WHERE LOWER(email) = LOWER(?)'
    local params = { email }
    if ignoreAccountId then
        query = query .. ' AND id <> ?'
        params[#params + 1] = ignoreAccountId
    end
    return MySQL.scalar.await(query, params)
end

exports.sunset_core:RegisterCallback('sunset:authRegister', function(source, username, password, passwordConfirm, email)
    local ok, err = validateUsername(username)
    if not ok then return nil, err end
    ok, err = validatePassword(password)
    if not ok then return nil, err end
    if password ~= passwordConfirm then return nil, 'Passwords do not match' end

    ok, err = validateEmail(email)
    if not ok then return nil, err end
    local normalizedEmail = err

    local exists = MySQL.scalar.await('SELECT id FROM accounts WHERE LOWER(username) = LOWER(?)', { username })
    if exists then return nil, 'Username already taken' end
    if emailTaken(normalizedEmail) then return nil, 'That email is already linked to another account' end

    local hash = exports.sunset_auth:HashPassword(password)
    if not hash then return nil, 'Password protection could not be initialized. Try again.' end
    local accountId = MySQL.insert.await(
        'INSERT INTO accounts (username, email, password_hash, password_salt) VALUES (?, ?, ?, ?)',
        { username:lower(), normalizedEmail, hash, '' }
    )

    clearPending(source)
    local normalized = username:lower()
    if not exports.sunset_core:CompleteAuthentication(source, accountId, normalized) then
        return nil, 'Could not establish authenticated session'
    end
    return { username = normalized, needsEmail = false, quickToken = issueQuickToken(source, accountId) }
end)
exports.sunset_core:RegisterCallback('sunset:authLogin', function(source, username, password)
    local ok, err = validateUsername(username)
    if not ok then return nil, err end
    if not password or password == '' then return nil, 'Enter your password' end

    local locked, backoff = loginLocked(source)
    if locked then
        return nil, ('Too many failed attempts. Try again in %d seconds.'):format(math.ceil(backoff / 1000))
    end

    local account = MySQL.single.await(
        'SELECT id, username, email, password_hash, password_salt FROM accounts WHERE LOWER(username) = LOWER(?)',
        { username }
    )
    if not account then recordLoginFail(source) return nil, 'Invalid username or password' end
    local modern = type(account.password_hash) == 'string' and account.password_hash:sub(1, 8) == '$scrypt$'
    local valid = modern and exports.sunset_auth:VerifyPassword(password, account.password_hash)
        or Sunset.Password.Verify(password, account.password_salt, account.password_hash)
    if not valid then
        recordLoginFail(source)
        return nil, 'Invalid username or password'
    end
    clearLoginFails(source)

    if not modern then
        local upgraded = exports.sunset_auth:HashPassword(password)
        if upgraded then
            MySQL.update.await('UPDATE accounts SET password_hash = ?, password_salt = ? WHERE id = ?', {
                upgraded, '', account.id,
            })
        end
    end

    if emailMissing(account.email) then
        PendingEmail[source] = account.id
        return {
            username = account.username,
            needsEmail = true,
        }
    end

    clearPending(source)
    if not exports.sunset_core:CompleteAuthentication(source, account.id, account.username) then
        return nil, 'Could not establish authenticated session'
    end
    return { username = account.username, needsEmail = false, quickToken = issueQuickToken(source, account.id) }
end)

exports.sunset_core:RegisterCallback('sunset:authQuickLogin', function(source, username, token)
    if type(username) ~= 'string' or type(token) ~= 'string' or #token < 32 or #token > 128 then
        return nil, 'Saved login expired. Enter your password again.'
    end
    local tokenHash = exports.sunset_auth:HashToken(token)
    local row = MySQL.single.await([[
        SELECT a.id, a.username, a.email
        FROM auth_quick_tokens q
        JOIN accounts a ON a.id = q.account_id
        WHERE LOWER(a.username) = LOWER(?) AND q.token_hash = ? AND q.device_hash = ?
          AND q.revoked_at IS NULL AND q.expires_at > NOW()
        LIMIT 1
    ]], { username, tokenHash, deviceHash(source) })
    if not row then return nil, 'Saved login expired. Enter your password again.' end
    MySQL.update.await('UPDATE auth_quick_tokens SET last_used_at = NOW() WHERE token_hash = ?', { tokenHash })
    if emailMissing(row.email) then
        PendingEmail[source] = row.id
        return { username = row.username, needsEmail = true }
    end
    if not exports.sunset_core:CompleteAuthentication(source, row.id, row.username) then
        return nil, 'Could not establish authenticated session'
    end
    return { username = row.username, needsEmail = emailMissing(row.email), quickToken = issueQuickToken(source, row.id) }
end)

exports.sunset_core:RegisterCallback('sunset:authSetEmail', function(source, email)
    local accountId = PendingEmail[source]
    if not accountId then
        return nil, 'Your login session expired. Sign in again.'
    end

    local ok, err = validateEmail(email)
    if not ok then return nil, err end
    local normalizedEmail = err

    if emailTaken(normalizedEmail, accountId) then
        return nil, 'That email is already linked to another account'
    end

    local account = MySQL.single.await('SELECT id, username FROM accounts WHERE id = ?', { accountId })
    if not account then
        clearPending(source)
        return nil, 'Account not found. Sign in again.'
    end

    MySQL.update.await('UPDATE accounts SET email = ? WHERE id = ?', { normalizedEmail, accountId })
    clearPending(source)

    if not exports.sunset_core:CompleteAuthentication(source, account.id, account.username) then
        return nil, 'Could not establish authenticated session'
    end
    return { username = account.username, needsEmail = false, quickToken = issueQuickToken(source, account.id) }
end)
