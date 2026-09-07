SunsetClans.MaxRank = 7
SunsetClans.MaxWarns = 3

SunsetClans.DefaultRankLabels = {
    [1] = 'Recruit',
    [2] = 'Member',
    [3] = 'Veteran',
    [4] = 'Senior',
    [5] = 'Officer',
    [6] = 'Co-Leader',
    [7] = 'Leader',
}

function SunsetClans.normalizeRank(rank)
    rank = math.floor(tonumber(rank) or 1)
    if rank < 1 then return 1 end
    if rank > SunsetClans.MaxRank then return SunsetClans.MaxRank end
    return rank
end

function SunsetClans.defaultRankLabels()
    local out = {}
    for i = 1, SunsetClans.MaxRank do
        out[i] = SunsetClans.DefaultRankLabels[i] or ('Rank ' .. i)
    end
    return out
end

function SunsetClans.encodeRankLabels(labels)
    local out = {}
    labels = labels or SunsetClans.defaultRankLabels()
    for i = 1, SunsetClans.MaxRank do
        local label = labels[i] or labels[tostring(i)]
        if type(label) == 'string' then
            label = label:gsub('^%s+', ''):gsub('%s+$', '')
        end
        if type(label) == 'string' and label ~= '' then
            out[tostring(i)] = label:sub(1, 48)
        else
            out[tostring(i)] = SunsetClans.DefaultRankLabels[i] or ('Rank ' .. i)
        end
    end
    return json.encode(out)
end

function SunsetClans.decodeRankLabels(raw)
    local defaults = SunsetClans.defaultRankLabels()
    if type(raw) == 'string' and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        raw = ok and decoded or nil
    end
    if type(raw) ~= 'table' then return defaults end

    local out = {}
    for i = 1, SunsetClans.MaxRank do
        local label = raw[tostring(i)] or raw[i]
        if type(label) == 'string' then
            label = label:gsub('^%s+', ''):gsub('%s+$', '')
        end
        if type(label) == 'string' and label ~= '' then
            out[i] = label:sub(1, 48)
        else
            out[i] = defaults[i]
        end
    end
    return out
end

function SunsetClans.getRankLabel(labels, rank)
    labels = labels or SunsetClans.defaultRankLabels()
    rank = SunsetClans.normalizeRank(rank)
    return labels[rank] or ('Rank ' .. rank)
end
