Sunset = Sunset or {}

--- Faction archetypes — use capabilities instead of hardcoded faction id checks.
Sunset.FactionTypes = {
    law_enforcement = 'law_enforcement',
    ems = 'ems',
    fire_rescue = 'fire_rescue',
    transport = 'transport',
    mechanic = 'mechanic',
    criminal_org = 'criminal_org',
    government = 'government',
}

--- Capability keys referenced by rank perms and faction type defaults.
Sunset.FactionCapabilities = {
    cuff = 'law_enforcement',
    uncuff = 'law_enforcement',
    fine = 'law_enforcement',
    wanted = 'law_enforcement',
    arrest = 'law_enforcement',
    frisk = 'law_enforcement',
    escort = 'law_enforcement',
    vehicle_detain = 'law_enforcement',
    backup = 'law_enforcement',
    mdc = 'law_enforcement',
    megaphone = 'law_enforcement',
    heal = { 'ems', 'fire_rescue' },
    revive = { 'ems', 'fire_rescue' },
    fare = 'transport',
    repair = 'mechanic',
    craft_illegal = 'criminal_org',
    sell = 'criminal_org',
    fence = 'criminal_org',
    invite = '*',
    promote = '*',
    uninvite = '*',
    giverank = '*',
    fwarn = '*',
    fmotd = '*',
    members = '*',
}

local function normalizeCapTypes(capDef)
    if capDef == '*' then return { '*' } end
    if type(capDef) == 'string' then return { capDef } end
    if type(capDef) == 'table' then return capDef end
    return {}
end

function Sunset.GetFactionType(factionId)
    local f = Sunset.Factions and Sunset.Factions[factionId]
    return f and (f.factionType or f.type) or nil
end

function Sunset.FactionTypeMatches(factionId, archetype)
    return Sunset.GetFactionType(factionId) == archetype
end

function Sunset.CapabilityAllowedForFaction(factionId, capability)
    local capDef = Sunset.FactionCapabilities[capability]
    if not capDef then return false end
    local types = normalizeCapTypes(capDef)
    if types[1] == '*' then return true end
    local fType = Sunset.GetFactionType(factionId)
    for _, t in ipairs(types) do
        if t == fType then return true end
    end
    return false
end

function Sunset.HasFactionPerm(jobId, grade, perm)
    local g = Sunset.GetFactionGrade(jobId, grade)
    if not g or not g.perms then return false end
    return g.perms[perm] == true
end

function Sunset.HasFactionCapability(factionId, grade, capability)
    if not factionId or not Sunset.Factions[factionId] then return false end
    if not Sunset.CapabilityAllowedForFaction(factionId, capability) then return false end
    return Sunset.HasFactionPerm(factionId, grade, capability)
end

function Sunset.IsLegalFaction(factionId)
    local f = Sunset.Factions and Sunset.Factions[factionId]
    return f and f.type == 'legal'
end

function Sunset.IsGovernmentFaction(factionId)
    return Sunset.FactionTypeMatches(factionId, 'government')
        or Sunset.FactionTypeMatches(factionId, 'law_enforcement')
end

function Sunset.GetGovernmentFactions()
    local list = {}
    for id, f in pairs(Sunset.Factions or {}) do
        local fType = f.factionType or f.type
        if fType == 'government' or fType == 'law_enforcement' or fType == 'ems' or fType == 'fire_rescue' then
            list[#list + 1] = id
        end
    end
    return list
end
