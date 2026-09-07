local TestSessions = {}

local function notify(source, message, kind)
    TriggerClientEvent('sunset:client:notify', source, message, kind or 'info', 7000)
end

local function charId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id)
end

local function currentPaydays(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.paydays_received) or 0
end

local function playtimeMinutes(source)
    local player = exports.sunset_core:GetPlayer(source)
    return player and tonumber(player.playtime) or 0
end

local function isInstructor(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    local factionId = Sunset.GetCharacterFaction(char)
    if factionId ~= 'lssi' then return false end
    if not exports.sunset_factions:IsOnDuty(source) then return false end
    local grade = select(2, Sunset.GetCharacterFaction(char))
    return Sunset.HasFactionPerm('lssi', grade, 'issue_license')
        or Sunset.HasFactionPerm('lssi', grade, 'conduct_test')
end

function IsInLicenseTest(source)
    return TestSessions[source] ~= nil
end
exports('IsInLicenseTest', IsInLicenseTest)

local function loadLicenseRows(characterId)
    return MySQL.query.await([[
        SELECT license_type, issued_at, issued_at_payday, expires_at_payday, issued_by_character_id
        FROM character_licenses WHERE character_id = ?
    ]], { characterId }) or {}
end

local function rowValid(row, paydays)
    if not row then return false end
    local exp = tonumber(row.expires_at_payday)
    if not exp then return true end
    return paydays < exp
end

function GetLicenseRows(source)
    local cid = charId(source)
    if not cid then return {} end
    return loadLicenseRows(cid)
end
exports('GetLicenseRows', GetLicenseRows)

function HasLicense(source, licenseType)
    licenseType = tostring(licenseType or '')
    local def = SunsetLicenses.Types[licenseType]
    if not def then return false, 'Unknown license type.' end
    if IsInLicenseTest(source) then
        local session = TestSessions[source]
        if session and session.licenseType == licenseType then
            return true, 'test'
        end
    end
    local cid = charId(source)
    if not cid then return false, 'Character not loaded.' end
    local paydays = currentPaydays(source)
    local row = MySQL.single.await(
        'SELECT * FROM character_licenses WHERE character_id = ? AND license_type = ? LIMIT 1',
        { cid, licenseType }
    )
    if not row then
        return false, ('You need a valid %s. Visit the %s.'):format(def.label, def.label)
    end
    if not rowValid(row, paydays) then
        return false, ('Your %s expired. Retake the test at the school.'):format(def.label)
    end
    return true
end
exports('HasLicense', HasLicense)

function GrantLicense(source, licenseType, issuedByCharacterId)
    licenseType = tostring(licenseType or '')
    if not SunsetLicenses.Types[licenseType] then return false, 'Invalid license type.' end
    local cid = charId(source)
    if not cid then return false, 'Character not loaded.' end
    local paydays = currentPaydays(source)
    local expires = paydays + (SunsetLicenses.PaydayExpiry or 200)
    MySQL.insert.await([[
        INSERT INTO character_licenses (character_id, license_type, issued_at_payday, expires_at_payday, issued_by_character_id)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            issued_at = CURRENT_TIMESTAMP,
            issued_at_payday = VALUES(issued_at_payday),
            expires_at_payday = VALUES(expires_at_payday),
            issued_by_character_id = VALUES(issued_by_character_id)
    ]], { cid, licenseType, paydays, expires, issuedByCharacterId })
    notify(source, ('%s issued — valid until payday #%d.'):format(
        SunsetLicenses.Types[licenseType].label, expires), 'success')
    TriggerClientEvent('sunset:licenses:refresh', source)
    return true
end
exports('GrantLicense', GrantLicense)

function RevokeLicense(source, licenseType)
    licenseType = tostring(licenseType or '')
    local cid = charId(source)
    if not cid then return false, 'Character not loaded.' end
    MySQL.update.await(
        'DELETE FROM character_licenses WHERE character_id = ? AND license_type = ?',
        { cid, licenseType }
    )
    TriggerClientEvent('sunset:licenses:refresh', source)
    return true
end
exports('RevokeLicense', RevokeLicense)

function GetLicenses(source)
    local cid = charId(source)
    if not cid then return {} end
    local paydays = currentPaydays(source)
    local rows = loadLicenseRows(cid)
    local out = {}
    for _, row in ipairs(rows) do
        local def = SunsetLicenses.Types[row.license_type]
        local valid = rowValid(row, paydays)
        out[#out + 1] = {
            license_type = row.license_type,
            label = def and def.label or row.license_type,
            issued_at = row.issued_at,
            issued_at_payday = row.issued_at_payday,
            expires_at_payday = row.expires_at_payday,
            valid = valid,
        }
    end
    return out
end
exports('GetLicenses', GetLicenses)

local function canStartTest(source, licenseType)
    licenseType = tostring(licenseType or '')
    local def = SunsetLicenses.Types[licenseType]
    if not def then return false, 'Invalid license type.' end
    if TestSessions[source] then return false, 'You already have a license test in progress.' end
    local ok, err = HasLicense(source, licenseType)
    if ok and err ~= 'test' then
        return false, ('You already hold a valid %s.'):format(def.label)
    end
    return true
end

exports.sunset_core:RegisterCallback('sunset:license:has', function(source, licenseType)
    local ok = HasLicense(source, tostring(licenseType or ''))
    return ok == true
end)

exports.sunset_core:RegisterCallback('sunset:license:getStatus', function(source)
    local cid = charId(source)
    if not cid then return nil, 'Character not loaded.' end
    return {
        licenses = GetLicenses(source),
        playtimeMinutes = playtimeMinutes(source),
        paydays = currentPaydays(source),
        instructor = isInstructor(source),
        inTest = IsInLicenseTest(source),
    }
end)

exports.sunset_core:RegisterCallback('sunset:license:startTheory', function(source, licenseType)
    licenseType = tostring(licenseType or '')
    local ok, err = canStartTest(source, licenseType)
    if not ok then return nil, err end
    local theory = SunsetLicenses.Theory[licenseType]
    if not theory then return nil, 'No theory exam configured for this license.' end
    TestSessions[source] = {
        licenseType = licenseType,
        phase = 'theory',
        startedAt = os.time(),
    }
    return theory
end)

exports.sunset_core:RegisterCallback('sunset:license:submitTheory', function(source, licenseType, answers)
    licenseType = tostring(licenseType or '')
    local session = TestSessions[source]
    if not session or session.licenseType ~= licenseType or session.phase ~= 'theory' then
        return nil, 'No active theory exam. Start again at the school marker.'
    end
    local theory = SunsetLicenses.Theory[licenseType]
    if not theory then return nil, 'Invalid exam.' end
    answers = type(answers) == 'table' and answers or {}
    local score = 0
    for i, q in ipairs(theory.questions or {}) do
        if tonumber(answers[i] or answers[tostring(i)]) == tonumber(q.correct) then
            score = score + 1
        end
    end
    local need = tonumber(theory.passScore) or math.ceil(#(theory.questions or {}) * 0.75)
    if score < need then
        TestSessions[source] = nil
        return nil, ('Theory failed (%d/%d). Study the rules and try again.'):format(score, #(theory.questions or {}))
    end
    session.phase = 'practical'
    session.theoryPassedAt = os.time()
    local practical = SunsetLicenses.Practical[licenseType]
    local facilityKey = SunsetLicenses.Types[licenseType].facility
    local facility = facilityKey and SunsetLicenses.Facilities[facilityKey]
    return {
        practical = practical,
        facility = facility,
        licenseType = licenseType,
    }
end)

exports.sunset_core:RegisterCallback('sunset:license:abortTest', function(source)
    TestSessions[source] = nil
    TriggerClientEvent('sunset:licenses:testAbort', source)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:license:completePractical', function(source, licenseType)
    licenseType = tostring(licenseType or '')
    local session = TestSessions[source]
    if not session or session.licenseType ~= licenseType or session.phase ~= 'practical' then
        return nil, 'No active practical test to complete.'
    end
    TestSessions[source] = nil
    local issuer = charId(source)
    local ok, err = GrantLicense(source, licenseType, issuer)
    if not ok then return nil, err end
    TriggerClientEvent('sunset:licenses:testComplete', source, licenseType)
    return { licenseType = licenseType }
end)

RegisterNetEvent('sunset:licenses:registerTestVehicle', function(netId)
    local src = source
    local session = TestSessions[src]
    if not session then return end
    session.testVehicleNet = tonumber(netId)
end)

AddEventHandler('sunset:payday:processed', function(source)
    local cid = charId(source)
    if not cid then return end
    local paydays = currentPaydays(source)
    local rows = loadLicenseRows(cid)
    for _, row in ipairs(rows) do
        local exp = tonumber(row.expires_at_payday)
        if exp and paydays >= exp then
            MySQL.update.await(
                'DELETE FROM character_licenses WHERE character_id = ? AND license_type = ?',
                { cid, row.license_type }
            )
            local def = SunsetLicenses.Types[row.license_type]
            notify(source, ('Your %s expired after %d paydays.'):format(
                def and def.label or row.license_type, SunsetLicenses.PaydayExpiry or 200), 'warning')
            TriggerClientEvent('sunset:licenses:refresh', source)
        end
    end
end)

AddEventHandler('playerDropped', function()
    TestSessions[source] = nil
end)

RegisterCommand('issuelicense', function(source, args)
    if source ~= 0 and not isInstructor(source) then
        notify(source, 'LSSI instructors on duty only.', 'error')
        return
    end
    local target = tonumber(args[1])
    local licenseType = string.lower(tostring(args[2] or ''))
    if not target or not GetPlayerName(target) then
        notify(source, 'Usage: /issuelicense [player id] [pilot|boat|weapon]', 'error')
        return
    end
    local def = SunsetLicenses.Types[licenseType]
    if not def or not def.instructorFaction then
        notify(source, 'Instructors may issue: pilot, boat, weapon.', 'error')
        return
    end
    local issuer = source ~= 0 and charId(source)
    local ok, err = GrantLicense(target, licenseType, issuer)
    if ok then
        notify(source, ('Issued %s to player #%d.'):format(licenseType, target), 'success')
    else
        notify(source, err or 'Could not issue license.', 'error')
    end
end, false)

-- Used by tests.lua server validation
function GetTestSession(source)
    return TestSessions[source]
end
