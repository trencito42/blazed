local Accounts = {}

local MAX_ACCOUNTS = 6
local KVP_PREFIX = 'auth_'

local function keyFor(license)
    local id = tostring(license or ''):gsub('[^%w]', '_')
    if id == '' then return nil end
    if #id > 96 then id = id:sub(1, 96) end
    return KVP_PREFIX .. id
end

local function normalizeStore(data)
    if type(data) ~= 'table' then
        return { quickLogin = true, accounts = {} }
    end
    data.quickLogin = data.quickLogin == true
    if type(data.accounts) ~= 'table' then
        data.accounts = {}
    end
    return data
end

local function flushKvp()
    if type(FlushResourceKvp) == 'function' then
        FlushResourceKvp()
    end
end

function Accounts.load(license)
    local key = keyFor(license)
    if not key then
        return { quickLogin = true, accounts = {} }
    end
    local raw = GetResourceKvpString(key)
    if not raw or raw == '' then
        local legacy = GetResourceKvpString('auth_default')
        if legacy and legacy ~= '' then
            SetResourceKvp(key, legacy)
            DeleteResourceKvp('auth_default')
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
    local key = keyFor(license)
    if not key then
        print('[sunset_auth] Skipped auth account save: license not ready yet')
        return false
    end
    SetResourceKvp(key, json.encode(normalizeStore(store)))
    flushKvp()
    return true
end

function Accounts.publicList(store)
    local out = {}
    for _, row in ipairs(store.accounts) do
        local username = tostring(row.username or '')
        if username ~= '' then
            out[#out + 1] = {
                username = username,
                hasPassword = type(row.password) == 'string' and row.password ~= '',
                lastLogin = tonumber(row.lastLogin) or 0,
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
    Accounts.save(license, store)
    return store
end

function Accounts.setQuickLogin(license, enabled)
    local store = Accounts.load(license)
    store.quickLogin = enabled == true
    Accounts.save(license, store)
    return store
end

function Accounts.upsert(license, username, password, quickLogin)
    local store = Accounts.load(license)
    if quickLogin ~= nil then
        store.quickLogin = quickLogin == true
    end
    if not store.quickLogin then
        Accounts.save(license, store)
        return store
    end

    local name = tostring(username or '')
    local pass = tostring(password or '')
    if name == '' or pass == '' then
        Accounts.save(license, store)
        return store
    end

    local target = string.lower(name)
    local now = os.time()
    local found = false
    for index, row in ipairs(store.accounts) do
        if string.lower(tostring(row.username or '')) == target then
            store.accounts[index] = {
                username = name,
                password = pass,
                lastLogin = now,
            }
            found = true
            break
        end
    end
    if not found then
        table.insert(store.accounts, 1, {
            username = name,
            password = pass,
            lastLogin = now,
        })
    end

    table.sort(store.accounts, function(a, b)
        return (tonumber(a.lastLogin) or 0) > (tonumber(b.lastLogin) or 0)
    end)
    while #store.accounts > MAX_ACCOUNTS do
        table.remove(store.accounts)
    end

    Accounts.save(license, store)
    return store
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
