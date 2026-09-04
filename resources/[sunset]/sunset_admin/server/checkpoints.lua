SunsetAdmin = SunsetAdmin or {}

local cache

local function normalizeId(name)
    if not name or name == '' then return nil end
    name = tostring(name):gsub('^%s+', ''):gsub('%s+$', ''):lower()
    name = name:gsub('%s+', '_')
    name = name:gsub('[^a-z0-9_%-]', '')
    if name == '' or #name > 64 then return nil end
    return name
end

function SunsetAdmin.NormalizeCheckpointId(name)
    return normalizeId(name)
end

function SunsetAdmin.RefreshCheckpoints()
    cache = MySQL.query.await([[
        SELECT id, label, x, y, z, heading, created_by
        FROM admin_checkpoints
        ORDER BY id ASC
    ]]) or {}
    return cache
end

function SunsetAdmin.GetCheckpoints()
    if not cache then
        SunsetAdmin.RefreshCheckpoints()
    end
    return cache
end

function SunsetAdmin.FindPlacedCheckpoint(query)
    if not query or query == '' then return nil end
    query = string.lower(tostring(query))

    local partial
    for _, cp in ipairs(SunsetAdmin.GetCheckpoints()) do
        if string.lower(cp.id) == query then
            return cp
        end
        local label = cp.label and string.lower(cp.label) or ''
        if label == query then
            return cp
        end
        if not partial and label ~= '' and string.find(label, query, 1, true) then
            partial = cp
        end
    end
    return partial
end

function SunsetAdmin.SaveCheckpoint(id, label, x, y, z, heading, createdBy)
    id = normalizeId(id)
    if not id then return false, 'Invalid checkpoint name (use letters, numbers, _ or -).' end

    label = label and tostring(label):gsub('^%s+', ''):gsub('%s+$', '') or id
    if label == '' then label = id end
    if #label > 128 then label = label:sub(1, 128) end

    MySQL.insert.await([[
        INSERT INTO admin_checkpoints (id, label, x, y, z, heading, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            label = VALUES(label),
            x = VALUES(x),
            y = VALUES(y),
            z = VALUES(z),
            heading = VALUES(heading),
            created_by = VALUES(created_by)
    ]], { id, label, x + 0.0, y + 0.0, z + 0.0, heading, createdBy })

    SunsetAdmin.RefreshCheckpoints()
    return true, id
end

function SunsetAdmin.DeleteCheckpoint(id)
    id = normalizeId(id)
    if not id then return false, 'Invalid checkpoint name.' end

    local removed = MySQL.update.await('DELETE FROM admin_checkpoints WHERE id = ?', { id })
    if removed and removed > 0 then
        SunsetAdmin.RefreshCheckpoints()
        return true, id
    end
    return false, ('No checkpoint named "%s".'):format(id)
end

CreateThread(function()
    Wait(500)
    SunsetAdmin.RefreshCheckpoints()
end)
