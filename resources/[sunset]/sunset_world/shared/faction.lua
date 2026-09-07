Sunset = Sunset or {}

-- Fallback when profile.lua was not loaded (older manifests / load order).
if type(Sunset.GetCharacterFaction) ~= 'function' then
    function Sunset.GetCharacterFaction(char)
        if not char then return nil, 0 end
        local md = char.metadata or {}
        if md.faction and Sunset.Factions and Sunset.Factions[md.faction] then
            return md.faction, tonumber(md.faction_grade) or 0
        end
        if char.job and Sunset.Factions and Sunset.Factions[char.job] then
            return char.job, char.job_grade or 0
        end
        return nil, 0
    end
end
