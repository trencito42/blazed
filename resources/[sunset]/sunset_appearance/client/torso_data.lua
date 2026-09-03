TorsoData = { male = {}, female = {} }

local function loadJson(path)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return ok and data or {}
end

CreateThread(function()
    TorsoData.male = loadJson('data/besttorso_male.json')
    TorsoData.female = loadJson('data/besttorso_female.json')
end)

function TorsoData.getBestTorso(gender, topDrawable, topTexture)
    topDrawable = math.floor(topDrawable or 0)
    topTexture = math.floor(topTexture or 0)
    local bank = (gender == 1) and TorsoData.female or TorsoData.male

    local topEntry = bank[tostring(topDrawable)] or bank[topDrawable]
    if not topEntry then return nil, nil end

    local texEntry = topEntry[tostring(topTexture)] or topEntry[topTexture] or topEntry['0'] or topEntry[0]
    if not texEntry then return nil, nil end

    local torso = texEntry.BestTorsoDrawable
    local tex = texEntry.BestTorsoTexture or 0
    if torso == nil or torso == -1 then return nil, nil end
    return torso, tex
end
