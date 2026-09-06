local PendingEmail = {}

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

    local salt = Sunset.Password.GenerateSalt()
    local hash = Sunset.Password.Hash(password, salt)
    local accountId = MySQL.insert.await(
        'INSERT INTO accounts (username, email, password_hash, password_salt) VALUES (?, ?, ?, ?)',
        { username:lower(), normalizedEmail, hash, salt }
    )

    clearPending(source)
    local normalized = username:lower()
    if not exports.sunset_core:CompleteAuthentication(source, accountId, normalized) then
        return nil, 'Could not establish authenticated session'
    end
    return { username = normalized, needsEmail = false }
end)

exports.sunset_core:RegisterCallback('sunset:authLogin', function(source, username, password)
    local ok, err = validateUsername(username)
    if not ok then return nil, err end
    if not password or password == '' then return nil, 'Enter your password' end

    local account = MySQL.single.await(
        'SELECT id, username, email, password_hash, password_salt FROM accounts WHERE LOWER(username) = LOWER(?)',
        { username }
    )
    if not account then return nil, 'Invalid username or password' end
    if not Sunset.Password.Verify(password, account.password_salt, account.password_hash) then
        return nil, 'Invalid username or password' end

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
    return { username = account.username, needsEmail = false }
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
    return { username = account.username, needsEmail = false }
end)
