local Accounts = {}

local MAX_ACCOUNTS = 6
local STORE_KEY = 'saved_accounts_v2'
local LEGACY_PREFIX = 'auth_'

local function legacyKeyFor(license)
    local id = tostring(license or ''):gsub('[^%w]', '_')
    if id == '' then return nil end
    if #id > 96 then id = id:sub(1, 96) end
    return LEGACY_PREFIX .. id
end

local function normalizeStore(data)
    if type(data) ~= 'table' then
        return { quickLogin = true, accounts = {} }
    end
    -- Stores written before quickLogin existed implicitly had it enabled.
    data.quickLogin = data.quickLogin ~= false
    if type(data.accounts) ~= 'table' then
        data.accounts = {}
    end
    -- Remove credentials written by legacy builds. Only opaque revocable tokens
    -- are allowed in client KVP from this point forward.
    for _, row in ipairs(data.accounts) do
        row.password = nil
    end
    return data
end

local function flushKvp()
    if type(FlushResourceKvp) == 'function' then
        FlushResourceKvp()
    end
end

function Accounts.load(license)
    local raw = GetResourceKvpString(STORE_KEY)
    if not raw or raw == '' then
        local legacyKey = legacyKeyFor(license)
        local legacy = legacyKey and GetResourceKvpString(legacyKey) or nil
        if not legacy or legacy == '' then
            legacyKey = 'auth_default'
            legacy = GetResourceKvpString(legacyKey)
        end
        if legacy and legacy ~= '' then
            SetResourceKvp(STORE_KEY, legacy)
            if legacyKey then DeleteResourceKvp(legacyKey) end
            flushKvp()
            raw = legacy
        else
            return { quickLogin = true, accounts = {} }
        end
    end
    local ok, decoded = pcall(json.decode, raw)
    if not ok then
        return { quickLogin = true, accounts = {} }
    end
    return normalizeStore(decoded)
end

function Accounts.save(license, store)
    local encoded = json.encode(normalizeStore(store))
    SetResourceKvp(STORE_KEY, encoded)
    flushKvp()
    local persisted = GetResourceKvpString(STORE_KEY)
    if persisted ~= encoded then
        print('[sunset_auth] Saved-account verification failed')
        return false
    end
    return true
end

function Accounts.publicList(store)
    local out = {}
    for _, row in ipairs(store.accounts) do
        local username = tostring(row.username or '')
        if username ~= '' then
            out[#out + 1] = {
                username = username,
                hasPassword = type(row.token) == 'string' and row.token ~= '',
                lastLogin = tonumber(row.lastLogin) or 0,
                avatar = type(row.avatar) == 'string' and row.avatar or nil,
                characterName = type(row.characterName) == 'string' and row.characterName or nil,
                level = tonumber(row.level),
                cash = tonumber(row.cash),
                bank = tonumber(row.bank),
            }
        end
    end
    return out
end

function Accounts.find(store, username)
    local target = string.lower(tostring(username or ''))
    for _, row in ipairs(store.accounts) do
        if string.lower(tostring(row.username or '')) == target then
            return row
        end
    end
end

function Accounts.remove(license, username)
    local store = Accounts.load(license)
    local target = string.lower(tostring(username or ''))
    local nextAccounts = {}
    for _, row in ipairs(store.accounts) do
        if string.lower(tostring(row.username or '')) ~= target then
            nextAccounts[#nextAccounts + 1] = row
        end
    end
    store.accounts = nextAccounts
    return store, Accounts.save(license, store)
end

function Accounts.setQuickLogin(license, enabled)
    local store = Accounts.load(license)
    store.quickLogin = enabled == true
    return store, Accounts.save(license, store)
end

function Accounts.upsert(license, username, token, quickLogin)
    local store = Accounts.load(license)
    local name = tostring(username or '')
    local savedToken = tostring(token or '')
    if name == '' or savedToken == '' then
        return store, Accounts.save(license, store)
    end

    local target = string.lower(name)
    if quickLogin == false then
        local kept = {}
        for _, row in ipairs(store.accounts) do
            if string.lower(tostring(row.username or '')) ~= target then
                kept[#kept + 1] = row
            end
        end
        store.accounts = kept
        return store, Accounts.save(license, store)
    end

    store.quickLogin = true
    local now = GetCloudTimeAsInt()
    local found = false
    for index, row in ipairs(store.accounts) do
        if string.lower(tostring(row.username or '')) == target then
            store.accounts[index] = {
                username = name,
                token = savedToken,
                lastLogin = now,
                avatar = row.avatar,
                characterName = row.characterName,
                characterId = row.characterId,
                level = row.level,
                cash = row.cash,
                bank = row.bank,
            }
            found = true
            break
        end
    end
    if not found then
        table.insert(store.accounts, 1, {
            username = name,
            token = savedToken,
            lastLogin = now,
        })
    end

    table.sort(store.accounts, function(a, b)
        return (tonumber(a.lastLogin) or 0) > (tonumber(b.lastLogin) or 0)
    end)
    while #store.accounts > MAX_ACCOUNTS do
        table.remove(store.accounts)
    end

    return store, Accounts.save(license, store)
end

function Accounts.updateProfile(license, username, profile)
    local store = Accounts.load(license)
    local row = Accounts.find(store, username)
    if not row then return store, false end

    profile = type(profile) == 'table' and profile or {}
    local avatar = tostring(profile.avatar or '')
    if #avatar <= 180000 and avatar:match('^data:image/[a-zA-Z0-9.+-]+;base64,') then
        row.avatar = avatar
    end

    local characterName = tostring(profile.characterName or ''):sub(1, 80)
    if characterName ~= '' then row.characterName = characterName end
    local characterId = tonumber(profile.characterId)
    if characterId and characterId > 0 then row.characterId = math.floor(characterId) end

    local level = tonumber(profile.level)
    if level and level >= 1 then row.level = math.floor(math.min(level, 9999)) end
    local cash = tonumber(profile.cash)
    if cash and cash >= 0 then row.cash = math.floor(cash) end
    local bank = tonumber(profile.bank)
    if bank and bank >= 0 then row.bank = math.floor(bank) end

    return store, Accounts.save(license, store)
end

function Accounts.mostRecent(store)
    if type(store.accounts) ~= 'table' or #store.accounts == 0 then return nil end
    local best = store.accounts[1]
    for _, row in ipairs(store.accounts) do
        if (tonumber(row.lastLogin) or 0) > (tonumber(best.lastLogin) or 0) then
            best = row
        end
    end
    return best
end

SunsetAuthAccounts = Accounts
