local TestSessions = {}
local AuthorizedTests = {}
local ServerLicenseCache = {}
local LastWeaponWarning = {}

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

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function near(source, position, radius)
    local coords = playerCoords(source)
    if not coords or not position then return false end
    return #(coords - vector3(position.x, position.y, position.z)) <= radius
end

local function sessionTimedOut(session)
    if not session then return true end
    local practical = SunsetLicenses.Practical[session.licenseType]
    local maxSeconds = practical and tonumber(practical.maxTimeSec) or 600
    local began = tonumber(session.practicalStartedAt or session.startedAt) or 0
    return began <= 0 or os.time() - began > maxSeconds + 30
end

local function sanitizedTheory(theory)
    local result = {
        title = theory.title,
        intro = theory.intro,
        passScore = theory.passScore,
        questions = {},
    }
    for i, question in ipairs(theory.questions or {}) do
        result.questions[i] = { q = question.q, options = question.options }
    end
    return result
end

local function bindTheoryAnswerKeys()
    for licenseType, key in pairs(SunsetLicenseTheoryAnswers or {}) do
        local theory = SunsetLicenses.Theory[licenseType]
        if not theory then goto continue end
        for i, question in ipairs(theory.questions or {}) do
            question.serverAnswer = tonumber(key[i])
        end
        ::continue::
    end
end

bindTheoryAnswerKeys()

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

local function loadLicenseCache(source)
    local cid = charId(source)
    if not cid then ServerLicenseCache[source] = nil return nil end
    local paydays = currentPaydays(source)
    local cache = { characterId = cid, paydays = paydays, licenses = {} }
    for _, row in ipairs(loadLicenseRows(cid)) do
        cache.licenses[tostring(row.license_type)] = rowValid(row, paydays)
    end
    ServerLicenseCache[source] = cache
    return cache
end

local function licenseCache(source)
    local cid = charId(source)
    if not cid then return nil end
    local cache = ServerLicenseCache[source]
    if not cache or cache.characterId ~= cid or cache.paydays ~= currentPaydays(source) then
        cache = loadLicenseCache(source)
    end
    return cache
end

AddEventHandler('sunset:server:characterSelected', function(source)
    loadLicenseCache(tonumber(source))
end)

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
        if session and session.licenseType == licenseType
            and (session.phase == 'practical' or session.phase == 'validated') then
            return true, 'test'
        end
    end
    local cache = licenseCache(source)
    if not cache then return false, 'Character not loaded.' end
    if cache.licenses[licenseType] ~= true then
        return false, ('You need a valid %s. Visit the %s.'):format(def.label, def.label)
    end
    return true
end
exports('HasLicense', HasLicense)

local function cachedHasLicense(source, licenseType)
    local session = TestSessions[source]
    if session and session.licenseType == licenseType
        and (session.phase == 'practical' or session.phase == 'validated') then return true end
    local cache = licenseCache(source)
    return cache and cache.licenses[licenseType] == true or false
end

local meleeHashes = {}
SunsetLicenses.MeleeWeaponHashes = meleeHashes
for weaponName in pairs(SunsetLicenses.MeleeWeapons or {}) do
    local hash = SunsetLicenses.normalizeWeaponHash(GetHashKey(weaponName))
    meleeHashes[hash] = true
    if hash < 0 then
        meleeHashes[hash + 4294967296] = true
    end
end

local function isMeleeWeaponHash(weaponHash)
    if SunsetLicenses.isMeleeWeaponHash(weaponHash) then return true end
    return meleeHashes[SunsetLicenses.normalizeWeaponHash(weaponHash)] == true
end

local function isLawEnforcementOnDuty(source)
    if GetResourceState('sunset_factions') ~= 'started' then return false end
    if exports.sunset_factions:IsOnDuty(source) ~= true then return false end
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    local factionId = select(1, Sunset.GetCharacterFaction(char))
    return Sunset.FactionTypeMatches
        and Sunset.FactionTypeMatches(factionId, 'law_enforcement') == true
end

local function canDealWeaponDamage(source)
    if IsInLicenseTest(source) then return true end
    if isLawEnforcementOnDuty(source) then return true end
    if cachedHasLicense(source, 'weapon') then return true end
    return false
end

local function resyncVictimTo(source, data)
    local netId = tonumber(data.hitGlobalId)
    if not netId or netId == 0 then return end
    local victim = NetworkGetEntityFromNetworkId(netId)
    if not victim or victim == 0 then return end
    -- [AUDIT 3-8.2] Only resync player peds: vehicles/objects return odd values
    -- from GetEntityHealth that would be pushed into a client health-set event.
    if GetEntityType(victim) ~= 1 or not IsPedAPlayer(victim) then return end
    TriggerClientEvent('sunset:combat:resyncPed', source, netId, GetEntityHealth(victim), GetPedArmour(victim))
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    if type(data) ~= 'table' then return end
    local weaponHash = tonumber(data.weaponType)
    if isMeleeWeaponHash(weaponHash) then return end
    if not canDealWeaponDamage(sender) then
        CancelEvent()
        resyncVictimTo(sender, data)
        local now = os.time()
        if now - (LastWeaponWarning[sender] or 0) >= 5 then
            LastWeaponWarning[sender] = now
            notify(sender, 'Firearm damage blocked: you need a valid Firearm License.', 'error')
        end
        return
    end
    local victimNet = tonumber(data.hitGlobalId)
    if victimNet and victimNet ~= 0 then
        local victimEnt = NetworkGetEntityFromNetworkId(victimNet)
        if victimEnt and victimEnt ~= 0 and GetEntityType(victimEnt) == 1 and IsPedAPlayer(victimEnt) then
            local victimSrc = NetworkGetEntityOwner(victimEnt)
            if victimSrc and victimSrc > 0 and victimSrc ~= sender then
                TriggerEvent('sunset:death:recordAttacker', victimSrc, sender)
            end
        end
    end
end)

function GrantLicense(source, licenseType, issuedByCharacterId)
    licenseType = tostring(licenseType or '')
    if not SunsetLicenses.Types[licenseType] then return false, 'Invalid license type.' end
    local cid = charId(source)
    if not cid then return false, 'Character not loaded.' end
    local paydays = currentPaydays(source)
    local expires = paydays + (SunsetLicenses.PaydayExpiry or 150)
    local saved, result = pcall(MySQL.insert.await, [[
        INSERT INTO character_licenses (character_id, license_type, issued_at_payday, expires_at_payday, issued_by_character_id)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            issued_at = CURRENT_TIMESTAMP,
            issued_at_payday = VALUES(issued_at_payday),
            expires_at_payday = VALUES(expires_at_payday),
            issued_by_character_id = VALUES(issued_by_character_id)
    ]], { cid, licenseType, paydays, expires, issuedByCharacterId })
    if not saved or result == nil then
        print(('[sunset_licenses] Failed to persist %s for character %d: %s'):format(
            licenseType, cid, tostring(result)))
        return false, 'The license could not be saved. No license was issued; contact an administrator.'
    end
    notify(source, ('%s issued — valid until payday #%d.'):format(
        SunsetLicenses.Types[licenseType].label, expires), 'success')
    TriggerClientEvent('sunset:licenses:refresh', source)
    loadLicenseCache(source)
    -- [QUESTS] driving chain: license acquisition progress.
    TriggerEvent('sunset:quest:progress', cid, 'license_obtained', 1, { license = licenseType })
    return true
end
exports('GrantLicense', GrantLicense)

function RevokeLicense(source, licenseType)
    licenseType = tostring(licenseType or '')
    local cid = charId(source)
    if not cid then
        -- Attempt fallback if source passed is already a character ID
        local num = tonumber(source)
        if num and num > 0 then
            return RevokeLicenseByCharacterId(num, licenseType)
        end
        return false, 'Character not loaded.'
    end
    MySQL.update.await(
        'DELETE FROM character_licenses WHERE character_id = ? AND license_type = ?',
        { cid, licenseType }
    )
    TriggerClientEvent('sunset:licenses:refresh', source)
    loadLicenseCache(source)
    return true
end
exports('RevokeLicense', RevokeLicense)

function RevokeLicenseByCharacterId(cid, licenseType)
    cid = tonumber(cid)
    if not cid or cid <= 0 then return false, 'Invalid character ID' end
    licenseType = tostring(licenseType or '')
    MySQL.update.await(
        'DELETE FROM character_licenses WHERE character_id = ? AND license_type = ?',
        { cid, licenseType }
    )
    -- If player is currently online, clear cache & trigger refresh
    for src, cache in pairs(ServerLicenseCache) do
        local c = exports.sunset_core:GetCharacter(src)
        if c and tonumber(c.id) == cid then
            loadLicenseCache(src)
            TriggerClientEvent('sunset:licenses:refresh', src)
            break
        end
    end
    return true
end
exports('RevokeLicenseByCharacterId', RevokeLicenseByCharacterId)

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

local function resolveExamFee(licenseType)
    local def = SunsetLicenses.Types[licenseType]
    if def and tonumber(def.examFee) then
        return math.floor(tonumber(def.examFee))
    end
    local starting = tonumber(Sunset.Config and Sunset.Config.StartingCash) or 500
    local pct = tonumber(def and def.examFeePercent)
        or tonumber(SunsetLicenses.ExamFeePercentOfStartingCash)
        or 0.10
    local fee = math.floor(starting * pct)
    local minFee = tonumber(SunsetLicenses.ExamFeeMin) or 40
    local maxFee = tonumber(SunsetLicenses.ExamFeeMax) or 100
    return math.max(minFee, math.min(maxFee, fee))
end

local function chargeExamFee(source, licenseType)
    local fee = resolveExamFee(licenseType)
    if fee <= 0 then return true, 0, nil end
    if exports.sunset_core:RemoveMoney(source, 'cash', fee, 'license_exam') then
        return true, fee, 'cash'
    end
    if exports.sunset_core:RemoveMoney(source, 'bank', fee, 'license_exam') then
        return true, fee, 'bank'
    end
    return false, fee, nil
end

local function canStartTest(source, licenseType)
    licenseType = tostring(licenseType or '')
    local def = SunsetLicenses.Types[licenseType]
    if not def then return false, 'Invalid license type.' end
    if TestSessions[source] then return false, 'You already have a license test in progress.' end
    local ok, err = HasLicense(source, licenseType)
    if ok and err ~= 'test' then
        return false, ('You already hold a valid %s.'):format(def.label)
    end
    local facility = SunsetLicenses.Facilities[def.facility]
    if not facility or not near(source, facility.marker, (facility.markerRadius or 3.0) + 2.0) then
        return false, ('Stand at the %s marker to start this exam.'):format(
            facility and facility.label or 'license school')
    end
    if def.instructorFaction then
        local authorization = AuthorizedTests[source]
        if not authorization or authorization.licenseType ~= licenseType
            or authorization.expiresAt < os.time() then
            AuthorizedTests[source] = nil
            return false, ('An on-duty LSSI instructor must authorize your %s exam first.'):format(def.label)
        end
        local instructor = authorization.instructor
        if not GetPlayerName(instructor) or not isInstructor(instructor) then
            AuthorizedTests[source] = nil
            return false, 'Your LSSI instructor is no longer available or on duty.'
        end
        local sourcePos, instructorPos = playerCoords(source), playerCoords(instructor)
        if not sourcePos or not instructorPos
            or #(sourcePos - instructorPos) > (SunsetLicenses.InstructorMaxDistance or 12.0)
            or not near(instructor, facility.marker, (facility.markerRadius or 3.0) + 8.0) then
            return false, 'Stay beside your LSSI instructor at the exam facility.'
        end
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

exports.sunset_core:RegisterCallback('sunset:license:getExamOffer', function(source, licenseType)
    licenseType = tostring(licenseType or '')
    local def = SunsetLicenses.Types[licenseType]
    if not def then return nil, 'Invalid license type.' end
    local fee = resolveExamFee(licenseType)
    return {
        licenseType = licenseType,
        label = def.label,
        fee = fee,
        startingCash = tonumber(Sunset.Config and Sunset.Config.StartingCash) or 500,
        theoryTimeSec = tonumber(SunsetLicenses.TheoryTimeSec) or 600,
    }
end)

exports.sunset_core:RegisterCallback('sunset:license:startTheory', function(source, licenseType)
    licenseType = tostring(licenseType or '')
    local ok, err = canStartTest(source, licenseType)
    if not ok then return nil, err end
    local theory = SunsetLicenses.Theory[licenseType]
    if not theory then return nil, 'No theory exam configured for this license.' end
    local fee = resolveExamFee(licenseType)
    local paid, charged, chargedAccount = chargeExamFee(source, licenseType)
    if not paid then
        return nil, ('Exam fee is $%d. You need enough cash or bank balance.'):format(fee)
    end
    local def = SunsetLicenses.Types[licenseType]
    local authorization = AuthorizedTests[source]
    local theoryTimeSec = tonumber(SunsetLicenses.TheoryTimeSec) or 600
    TestSessions[source] = {
        licenseType = licenseType,
        phase = 'theory',
        startedAt = os.time(),
        theoryDeadline = os.time() + theoryTimeSec,
        theoryAnswers = {},
        theoryAnswerKey = SunsetLicenseTheoryAnswers and SunsetLicenseTheoryAnswers[licenseType],
        examFee = charged,
        instructor = authorization and authorization.instructor or nil,
        issuerCharacterId = authorization and authorization.issuerCharacterId or nil,
    }
    if def and def.instructorFaction then
        local reportId = type(CreateLicenseExamReport) == 'function'
            and CreateLicenseExamReport(source, TestSessions[source]) or nil
        if not reportId then
            TestSessions[source] = nil
            AuthorizedTests[source] = nil
            if charged > 0 and chargedAccount then
                exports.sunset_core:AddMoney(source, chargedAccount, charged, 'license_exam_refund')
            end
            return nil, 'The supervised exam audit record could not be created. No test started; contact staff.'
        end
    end
    AuthorizedTests[source] = nil
    local payload = sanitizedTheory(theory)
    payload.examFee = charged
    payload.theoryTimeSec = theoryTimeSec
    payload.deadlineAt = TestSessions[source].theoryDeadline
    return payload
end)

exports.sunset_core:RegisterCallback('sunset:license:gradeTheoryAnswer', function(source, licenseType, questionIndex, answer)
    licenseType = tostring(licenseType or '')
    questionIndex = tonumber(questionIndex)
    answer = tonumber(answer)
    local session = TestSessions[source]
    if not session or session.licenseType ~= licenseType or session.phase ~= 'theory' then
        return nil, 'No active theory exam.'
    end
    if session.theoryDeadline and os.time() > session.theoryDeadline then
        return nil, 'Theory time expired.'
    end
    if not questionIndex or answer == nil then return nil, 'Invalid answer.' end
    local theory = SunsetLicenses.Theory[licenseType]
    if not theory or not theory.questions[questionIndex] then return nil, 'Invalid question.' end
    session.theoryAnswers = session.theoryAnswers or {}
    if session.theoryAnswers[questionIndex] ~= nil then
        return nil, 'You already answered this question.'
    end
    local answerKey = session.theoryAnswerKey
        or (SunsetLicenseTheoryAnswers and SunsetLicenseTheoryAnswers[licenseType])
    local question = theory.questions[questionIndex]
    local expected = tonumber(question and question.serverAnswer) or tonumber(answerKey and answerKey[questionIndex])
    if expected == nil then return nil, 'The server answer key is not configured for this exam.' end
    local correct = tonumber(answer) == expected
    session.theoryAnswers[questionIndex] = answer
    return { correct = correct, questionIndex = questionIndex }
end)

exports.sunset_core:RegisterCallback('sunset:license:submitTheory', function(source, licenseType, answers)
    licenseType = tostring(licenseType or '')
    local session = TestSessions[source]
    if not session or session.licenseType ~= licenseType or session.phase ~= 'theory' then
        return nil, 'No active theory exam. Start again at the school marker.'
    end
    if session.theoryDeadline and os.time() > session.theoryDeadline then
        if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'failed') end
        TestSessions[source] = nil
        return nil, 'Theory time expired — exam failed.'
    end
    local theory = SunsetLicenses.Theory[licenseType]
    if not theory then return nil, 'Invalid exam.' end
    answers = type(answers) == 'table' and answers or session.theoryAnswers or {}
    session.theoryAnswers = answers
    local answerKey = session.theoryAnswerKey
        or (SunsetLicenseTheoryAnswers and SunsetLicenseTheoryAnswers[licenseType])
    if not answerKey then return nil, 'The server answer key is not configured for this exam.' end
    local score = 0
    for i, q in ipairs(theory.questions or {}) do
        local expected = tonumber(q.serverAnswer) or tonumber(answerKey[i])
        if tonumber(answers[i] or answers[tostring(i)]) == expected then
            score = score + 1
        end
    end
    local need = tonumber(theory.passScore) or math.ceil(#(theory.questions or {}) * 0.75)
    if type(RecordLicenseTheoryResult) == 'function' then
        RecordLicenseTheoryResult(session, score, #(theory.questions or {}), score >= need)
    end
    if score < need then
        if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'failed') end
        TestSessions[source] = nil
        return nil, ('Theory failed (%d/%d). Study the rules and try again.'):format(score, #(theory.questions or {}))
    end
    session.phase = 'practical'
    session.theoryPassedAt = os.time()
    session.practicalStartedAt = os.time()
    session.lastCheckpoint = 0
    session.allCheckpoints = false
    session.practicalValidatedAt = nil
    local practical = SunsetLicenses.Practical[licenseType]
    local facilityKey = SunsetLicenses.Types[licenseType].facility
    local facility = facilityKey and SunsetLicenses.Facilities[facilityKey]
    local practicalTimeSec = practical and tonumber(practical.maxTimeSec) or 1200
    if session.instructor then
        notify(session.instructor, ('Candidate #%d passed the %s theory test. Supervise the practical until completion.'):format(
            source, SunsetLicenses.Types[licenseType].label), 'success')
    end
    return {
        practical = practical,
        facility = facility,
        licenseType = licenseType,
        examFee = session.examFee or 0,
        practicalTimeSec = practicalTimeSec,
        practicalDeadlineAt = session.practicalStartedAt + practicalTimeSec,
    }
end)

exports.sunset_core:RegisterCallback('sunset:license:abortTest', function(source)
    local session = TestSessions[source]
    if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'aborted') end
    if type(CleanupLicenseTestEntities) == 'function' then CleanupLicenseTestEntities(source) end
    TestSessions[source] = nil
    TriggerClientEvent('sunset:licenses:testAbort', source)
    return true
end)

exports.sunset_core:RegisterCallback('sunset:license:completePractical', function(source, licenseType)
    licenseType = tostring(licenseType or '')
    local session = TestSessions[source]
    if not session or session.licenseType ~= licenseType or session.phase ~= 'validated'
        or not session.practicalValidatedAt then
        return nil, 'The practical test has not been validated by the server.'
    end
    if sessionTimedOut(session) or os.time() - session.practicalValidatedAt > 20 then
        if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'aborted') end
        if type(CleanupLicenseTestEntities) == 'function' then CleanupLicenseTestEntities(source) end
        TestSessions[source] = nil
        return nil, 'The practical result expired. Start the exam again.'
    end
    local def = SunsetLicenses.Types[licenseType]
    if def and def.instructorFaction then
        if not session.instructor or not GetPlayerName(session.instructor) or not isInstructor(session.instructor) then
            if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'aborted') end
            if type(CleanupLicenseTestEntities) == 'function' then CleanupLicenseTestEntities(source) end
            TestSessions[source] = nil
            return nil, 'Your LSSI instructor must remain online and on duty until the exam is completed.'
        end
    end
    local candidateMistakes = tonumber(session.candidateMistakes) or 0
    local failAt = tonumber(SunsetLicenses.CandidateFailMistakes) or 3.0
    if def and def.instructorFaction and candidateMistakes >= failAt then
        if type(CleanupLicenseTestEntities) == 'function' then CleanupLicenseTestEntities(source) end
        if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'failed') end
        TestSessions[source] = nil
        notify(session.instructor, ('Candidate #%d failed the practical with %.1f/%.1f recorded mistakes.'):format(
            source, candidateMistakes, failAt), 'warning')
        return nil, ('Practical failed: the instructor recorded %.1f/%.1f mistakes. Ask LSSI management to review the report if needed.'):format(
            candidateMistakes, failAt)
    end
    if type(CleanupLicenseTestEntities) == 'function' then CleanupLicenseTestEntities(source) end
    TestSessions[source] = nil
    local issuer = session.issuerCharacterId
    local ok, err = GrantLicense(source, licenseType, issuer)
    if not ok then
        if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'aborted') end
        return nil, err
    end
    if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'passed') end
    TriggerClientEvent('sunset:licenses:testComplete', source, licenseType)
    return { licenseType = licenseType }
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
                def and def.label or row.license_type, SunsetLicenses.PaydayExpiry or 150), 'warning')
            TriggerClientEvent('sunset:licenses:refresh', source)
            loadLicenseCache(source)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local droppedSource = source
    local session = TestSessions[source]
    if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(session, 'aborted') end
    if type(CleanupLicenseTestEntities) == 'function' then CleanupLicenseTestEntities(source) end
    TestSessions[source] = nil
    AuthorizedTests[source] = nil
    ServerLicenseCache[source] = nil
    LastWeaponWarning[source] = nil
    for target, authorization in pairs(AuthorizedTests) do
        if authorization.instructor == droppedSource then AuthorizedTests[target] = nil end
    end
    for target, activeSession in pairs(TestSessions) do
        if activeSession.instructor == droppedSource then
            if type(FinalizeLicenseExamReport) == 'function' then FinalizeLicenseExamReport(activeSession, 'aborted') end
            if type(CleanupLicenseTestEntities) == 'function' then CleanupLicenseTestEntities(target) end
            TestSessions[target] = nil
            notify(target, 'Your LSSI exam ended because the supervising instructor disconnected.', 'error')
            TriggerClientEvent('sunset:licenses:testAbort', target)
        end
    end
end)

function RunInstructorLicenseCommand(source, args)
    if source == 0 then
        print('[sunset_licenses] /issuelicense must be used in game by an LSSI instructor. Admins can use /agivelicense.')
        return true
    end
    if not isInstructor(source) then
        notify(source, 'LSSI instructors on duty only.', 'error')
        return true
    end
    local target = tonumber(args[1])
    local licenseType = string.lower(tostring(args[2] or ''))
    if not target or not GetPlayerName(target) then
        notify(source, 'Usage: /issuelicense [player id] [pilot|boat|weapon]', 'error')
        return true
    end
    local def = SunsetLicenses.Types[licenseType]
    if not def or not def.instructorFaction then
        notify(source, 'LSSI may conduct tests for: pilot, boat, weapon. Driving tests are self-service.', 'error')
        return true
    end
    if target == source then
        notify(source, 'You cannot conduct your own license test.', 'error')
        return true
    end
    local facility = SunsetLicenses.Facilities[def.facility]
    local instructorPos, targetPos = playerCoords(source), playerCoords(target)
    if not instructorPos or not targetPos
        or #(instructorPos - targetPos) > (SunsetLicenses.InstructorMaxDistance or 12.0) then
        notify(source, 'The candidate must be beside you.', 'error')
        return true
    end
    if not facility or not near(source, facility.marker, (facility.markerRadius or 3.0) + 8.0)
        or not near(target, facility.marker, (facility.markerRadius or 3.0) + 8.0) then
        notify(source, ('You and the candidate must be at %s.'):format(
            facility and facility.label or 'the exam facility'), 'error')
        return true
    end
    local has, hasErr = HasLicense(target, licenseType)
    if has and hasErr ~= 'test' then
        notify(source, ('Player #%d already has a valid %s.'):format(target, def.label), 'error')
        return true
    end
    AuthorizedTests[target] = {
        licenseType = licenseType,
        instructor = source,
        issuerCharacterId = charId(source),
        expiresAt = os.time() + (SunsetLicenses.InstructorAuthorizationSeconds or 300),
    }
    notify(source, ('Authorized %s exam for player #%d. They must press E at the marker within 5 minutes.'):format(
        def.label, target), 'success')
    notify(target, ('LSSI instructor #%d authorized your %s exam. Press E at this marker to begin.'):format(
        source, def.label), 'success')
    return true
end

RegisterCommand('issuelicense', function(source, args)
    RunInstructorLicenseCommand(source, args or {})
end, false)

-- Used by tests.lua server validation
function GetTestSession(source)
    return TestSessions[source]
end
