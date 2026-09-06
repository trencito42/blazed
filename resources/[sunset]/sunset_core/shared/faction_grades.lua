Sunset = Sunset or {}

local function mergePerms(...)
    local out = {}
    for i = 1, select('#', ...) do
        local row = select(i, ...)
        if type(row) == 'table' then
            for key, value in pairs(row) do
                out[key] = value
            end
        end
    end
    return out
end

function Sunset.BuildLawEnforcementGrades(salaryScale)
    salaryScale = tonumber(salaryScale) or 1.0
    local function pay(base)
        return math.floor(base * salaryScale)
    end

    local base = { cuff = true, uncuff = true, escort = true, frisk = true, members = true }
    local cite = { ticket = true, fine = true }
    local patrol = { wanted_limited = true, mdc = true, megaphone = true }
    local full = {
        wanted = true, arrest = true, clear_wanted = true, backup = true, radar = true,
        confiscate = true, vehicle_detain = true,
    }
    local command = { invite = true, giverank = true, fmotd = true, fwarn = true, uninvite = true }
    local chief = { promote = true }

    return {
        [0] = { label = 'Cadet', salary = pay(380), perms = mergePerms(base, cite) },
        [1] = { label = 'Officer I', salary = pay(480), perms = mergePerms(base, cite, { mdc = true }) },
        [2] = { label = 'Officer II', salary = pay(560), perms = mergePerms(base, cite, patrol) },
        [3] = { label = 'Sergeant', salary = pay(680), perms = mergePerms(base, cite, patrol, full) },
        [4] = { label = 'Lieutenant', salary = pay(820), perms = mergePerms(base, cite, patrol, full) },
        [5] = { label = 'Captain', salary = pay(960), perms = mergePerms(base, cite, patrol, full) },
        [6] = { label = 'Deputy Chief', salary = pay(1120), perms = mergePerms(base, cite, patrol, full, command) },
        [7] = { label = 'Chief', salary = pay(1280), perms = mergePerms(base, cite, patrol, full, command, chief) },
    }
end

function Sunset.BuildEmsGrades()
    local heal = { stabilize = true, heal = true, revive = true }
    local lead = { invite = true, giverank = true, fmotd = true, fwarn = true, uninvite = true }
    return {
        [0] = { label = 'Trainee', salary = 320, perms = { stabilize = true, members = true } },
        [1] = { label = 'EMT', salary = 420, perms = { stabilize = true, heal = true, members = true } },
        [2] = { label = 'Paramedic', salary = 520, perms = mergePerms(heal, { members = true }) },
        [3] = { label = 'Senior Paramedic', salary = 620, perms = mergePerms(heal, { members = true }) },
        [4] = { label = 'Doctor', salary = 740, perms = mergePerms(heal, { members = true }) },
        [5] = { label = 'Surgeon', salary = 860, perms = mergePerms(heal, { members = true }) },
        [6] = { label = 'Deputy Chief', salary = 980, perms = mergePerms(heal, lead) },
        [7] = { label = 'Chief Medical', salary = 1100, perms = mergePerms(heal, lead, { promote = true }) },
    }
end

function Sunset.BuildFireGrades()
    local rescue = { stabilize = true, heal = true, revive = true }
    local lead = { invite = true, giverank = true, fmotd = true, fwarn = true, uninvite = true }
    return {
        [0] = { label = 'Probationary', salary = 300, perms = { stabilize = true, members = true } },
        [1] = { label = 'Firefighter', salary = 400, perms = { stabilize = true, heal = true, members = true } },
        [2] = { label = 'Engineer', salary = 500, perms = mergePerms(rescue, { members = true }) },
        [3] = { label = 'Senior Firefighter', salary = 600, perms = mergePerms(rescue, { members = true }) },
        [4] = { label = 'Captain', salary = 720, perms = mergePerms(rescue, { members = true }) },
        [5] = { label = 'Battalion Chief', salary = 840, perms = mergePerms(rescue, { members = true }) },
        [6] = { label = 'Deputy Chief', salary = 960, perms = mergePerms(rescue, lead) },
        [7] = { label = 'Fire Chief', salary = 1080, perms = mergePerms(rescue, lead, { promote = true }) },
    }
end

function Sunset.BuildServiceGrades(permKey, labels, salaries)
    local lead = { invite = true, giverank = true, fmotd = true, fwarn = true, uninvite = true }
    local grades = {}
    for i = 0, 7 do
        local perms = {}
        if permKey then perms[permKey] = true end
        if i >= 2 then perms.invite = true end
        if i >= 6 then
            for key, value in pairs(lead) do perms[key] = value end
        end
        if i >= 7 then perms.promote = true end
        if i == 0 then perms.members = true end
        grades[i] = {
            label = labels[i + 1] or ('Rank ' .. i),
            salary = salaries[i + 1] or (200 + i * 80),
            perms = perms,
        }
    end
    return grades
end

function Sunset.BuildCriminalGrades(permsByRank)
    local lead = { invite = true, giverank = true, fmotd = true, fwarn = true, uninvite = true }
    local grades = {}
    for i = 0, 7 do
        local perms = {}
        for key, minRank in pairs(permsByRank or {}) do
            if i >= minRank then perms[key] = true end
        end
        if i >= 6 then
            for key, value in pairs(lead) do perms[key] = value end
        end
        if i >= 7 then perms.promote = true end
        if i == 0 then perms.members = true end
        grades[i] = {
            label = ({ 'Associate', 'Soldier', 'Enforcer', 'Lieutenant', 'Captain', 'Underboss', 'Consigliere', 'Boss' })[i + 1],
            salary = 0,
            perms = perms,
        }
    end
    return grades
end
