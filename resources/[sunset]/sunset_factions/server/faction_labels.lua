FactionLabels = FactionLabels or {}

local Cache = {}

local function defaultLabel(factionId, grade)
    local row = Sunset.GetFactionGrade(factionId, grade)
    return row and row.label or ('Rank ' .. tostring(grade))
end

function FactionLabels.refresh()
    Cache = {}
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT faction_id, grade, label FROM faction_grade_labels', {})
    end)
    if not ok or not rows then return end
    for _, row in ipairs(rows) do
        local factionId = row.faction_id
        local grade = tonumber(row.grade)
        if factionId and grade ~= nil then
            Cache[factionId] = Cache[factionId] or {}
            Cache[factionId][grade] = tostring(row.label or '')
        end
    end
end

function FactionLabels.get(factionId, grade)
    grade = tonumber(grade) or 0
    local custom = Cache[factionId] and Cache[factionId][grade]
    if custom and custom ~= '' then return custom end
    return defaultLabel(factionId, grade)
end

function FactionLabels.listForFaction(factionId)
    local faction = Sunset.Factions[factionId]
    local out = {}
    for grade, row in pairs(faction and faction.grades or {}) do
        if type(grade) == 'number' then
            out[#out + 1] = {
                grade = grade,
                label = FactionLabels.get(factionId, grade),
                defaultLabel = row.label or ('Rank ' .. grade),
                isCustom = Cache[factionId] and Cache[factionId][grade] ~= nil,
            }
        end
    end
    table.sort(out, function(a, b) return a.grade < b.grade end)
    return out
end

function FactionLabels.save(factionId, labels, updatedBy)
    factionId = tostring(factionId or '')
    if not Sunset.Factions[factionId] then return false, 'Unknown faction' end
    if type(labels) ~= 'table' then return false, 'Invalid rank labels' end

    for grade, label in pairs(labels) do
        grade = tonumber(grade)
        if grade == nil then goto continue end
        local faction = Sunset.Factions[factionId]
        if not faction.grades[grade] then goto continue end
        label = tostring(label or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 64)
        local def = defaultLabel(factionId, grade)
        if label == '' or label == def then
            MySQL.update.await(
                'DELETE FROM faction_grade_labels WHERE faction_id = ? AND grade = ?',
                { factionId, grade }
            )
            if Cache[factionId] then Cache[factionId][grade] = nil end
        else
            MySQL.insert.await([[
                INSERT INTO faction_grade_labels (faction_id, grade, label, updated_by)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE label = VALUES(label), updated_by = VALUES(updated_by)
            ]], { factionId, grade, label, updatedBy })
            Cache[factionId] = Cache[factionId] or {}
            Cache[factionId][grade] = label
        end
        ::continue::
    end
    return true
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    FactionLabels.refresh()
end)
