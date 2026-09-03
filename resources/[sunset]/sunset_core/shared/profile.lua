Sunset = Sunset or {}

--- Faction membership lives in character.metadata (SAMP-style: job + faction are separate).
function Sunset.GetCharacterFaction(char)
    if not char then return nil, 0 end
    local md = char.metadata or {}
    if md.faction and Sunset.Factions and Sunset.Factions[md.faction] then
        return md.faction, tonumber(md.faction_grade) or 0
    end
    -- Legacy: job column was used for factions
    if char.job and Sunset.Factions and Sunset.Factions[char.job] then
        return char.job, char.job_grade or 0
    end
    return nil, 0
end

function Sunset.GetCharacterJob(char)
    if not char then return 'unemployed', 0 end
    if char.job and Sunset.Factions and Sunset.Factions[char.job] then
        return 'unemployed', 0
    end
    return char.job or 'unemployed', char.job_grade or 0
end

function Sunset.MigrateCharacterProfile(char)
    if not char then return char end
    char.metadata = char.metadata or {}
    if char.job and Sunset.Factions and Sunset.Factions[char.job] and not char.metadata.faction then
        char.metadata.faction = char.job
        char.metadata.faction_grade = char.job_grade or 0
        char.job = 'unemployed'
        char.job_grade = 0
        char._profileMigrated = true
    end
    return char
end

function Sunset.GetFactionGradeForChar(char)
    local factionId, grade = Sunset.GetCharacterFaction(char)
    if not factionId then return nil end
    return Sunset.GetFactionGrade(factionId, grade), factionId, grade
end
