SunsetJobCreator = SunsetJobCreator or {}

SunsetJobCreator.PREFIX = 'jc_'

SunsetJobCreator.DefaultDefinition = {
    startStage = 'start',
    timeoutSec = 1800,
    salary = 140,
    locations = {},
    pools = {},
    variables = {},
    stages = {},
    progression = { xpPerTask = 15, payPerTask = 60, progressVar = 'done', progressTotalVar = 'total' },
    ui = { title = 'Work', key = 'E' },
    contracts = {},
    party = { soloEnabled = true, partyEnabled = false, minPlayers = 1, maxPlayers = 1 },
}

SunsetJobCreator.StageCategories = {
    world = true,
    interaction = true,
    player = true,
    items = true,
    vehicles = true,
    gameplay = true,
    logic = true,
    rewards = true,
}

function SunsetJobCreator.IsCreatorJobId(jobId)
    jobId = tostring(jobId or '')
    return jobId:sub(1, #SunsetJobCreator.PREFIX) == SunsetJobCreator.PREFIX
end

function SunsetJobCreator.NormalizeId(raw)
    raw = tostring(raw or ''):lower():gsub('%s+', '_'):gsub('[^a-z0-9_]', '')
    if raw == '' then return nil end
    if raw:sub(1, #SunsetJobCreator.PREFIX) ~= SunsetJobCreator.PREFIX then
        raw = SunsetJobCreator.PREFIX .. raw
    end
    return raw:sub(1, 48)
end

local function stageIndex(def)
    local map = {}
    for i, st in ipairs(def.stages or {}) do
        if st.id then map[st.id] = i end
    end
    return map
end

function SunsetJobCreator.ValidateDefinition(def)
    def = type(def) == 'table' and def or {}
    local errors = {}
    if not def.startStage or def.startStage == '' then
        errors[#errors + 1] = 'Missing startStage.'
    end
    if not def.stages or #def.stages == 0 then
        errors[#errors + 1] = 'Job needs at least one stage.'
    end
    local ids = {}
    for _, st in ipairs(def.stages or {}) do
        if not st.id or st.id == '' then
            errors[#errors + 1] = 'Every stage needs an id.'
        elseif ids[st.id] then
            errors[#errors + 1] = ('Duplicate stage id: %s'):format(st.id)
        else
            ids[st.id] = true
        end
        if not st.type or st.type == '' then
            errors[#errors + 1] = ('Stage %s missing type.'):format(st.id or '?')
        end
    end
    if def.startStage and not ids[def.startStage] then
        errors[#errors + 1] = ('startStage "%s" does not exist.'):format(def.startStage)
    end
    for _, st in ipairs(def.stages or {}) do
        for _, key in ipairs({ 'onSuccess', 'onFailure' }) do
            local target = st[key]
            if target and target ~= '' and not ids[target] and target ~= 'complete' and target ~= 'fail' then
                errors[#errors + 1] = ('Stage %s points to missing %s: %s'):format(st.id, key, target)
            end
        end
        if st.type == 'zone_interact' and not st.location and not st.coords and not st.locationVar then
            errors[#errors + 1] = ('Stage %s (zone_interact) needs location, coords, or locationVar.'):format(st.id)
        end
        if st.type == 'goto_zone' and not st.location and not st.coords and not st.locationVar then
            errors[#errors + 1] = ('Stage %s (goto_zone) needs location, coords, or locationVar.'):format(st.id)
        end
    end
    return #errors == 0, errors
end

function SunsetJobCreator.MergeDefinition(base, patch)
    base = type(base) == 'table' and base or {}
    patch = type(patch) == 'table' and patch or {}
    local out = {}
    for k, v in pairs(SunsetJobCreator.DefaultDefinition) do
        out[k] = base[k] ~= nil and base[k] or v
    end
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(patch) do out[k] = v end
    return out
end

function SunsetJobCreator.FindStage(def, stageId)
    for _, st in ipairs(def.stages or {}) do
        if st.id == stageId then return st end
    end
end

function SunsetJobCreator.ResolveLocation(def, key, variables)
    if type(key) == 'table' then return key end
    if type(key) == 'string' and variables and variables[key] and type(variables[key]) == 'table' then
        return variables[key]
    end
    return def.locations and def.locations[key]
end

function SunsetJobCreator.StageLocation(def, stage, variables)
    if stage.locationVar and variables then
        local loc = variables[stage.locationVar]
        if type(loc) == 'table' and stage.locationField then
            loc = loc[stage.locationField]
        end
        if loc then return loc end
    end
    if stage.coords then return stage.coords end
    return SunsetJobCreator.ResolveLocation(def, stage.location, variables)
end
