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

exports.sunset_core:RegisterCallback('sunset:authRegister', function(source, username, password, passwordConfirm)
    local ok, err = validateUsername(username)
    if not ok then return nil, err end
    ok, err = validatePassword(password)
    if not ok then return nil, err end
    if password ~= passwordConfirm then return nil, 'Passwords do not match' end

    local exists = MySQL.scalar.await('SELECT id FROM accounts WHERE LOWER(username) = LOWER(?)', { username })
    if exists then return nil, 'Username already taken' end

    local salt = Sunset.Password.GenerateSalt()
    local hash = Sunset.Password.Hash(password, salt)
    local accountId = MySQL.insert.await(
        'INSERT INTO accounts (username, password_hash, password_salt) VALUES (?, ?, ?)',
        { username:lower(), hash, salt }
    )

    return { accountId = accountId, username = username:lower() }
end)

exports.sunset_core:RegisterCallback('sunset:authLogin', function(source, username, password)
    local ok, err = validateUsername(username)
    if not ok then return nil, err end
    if not password or password == '' then return nil, 'Enter your password' end

    local account = MySQL.single.await(
        'SELECT id, username, password_hash, password_salt FROM accounts WHERE LOWER(username) = LOWER(?)',
        { username }
    )
    if not account then return nil, 'Invalid username or password' end
    if not Sunset.Password.Verify(password, account.password_salt, account.password_hash) then
        return nil, 'Invalid username or password'
    end

    return { accountId = account.id, username = account.username }
end)
