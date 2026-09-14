-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Marriage System (server/main.lua)
--  Propose, accept, divorce, shared bank account.
-- ═══════════════════════════════════════════════════════════════

local Cfg = SunsetMarriage.Config
local PendingProposals = {} -- [targetSrc] = { from = src, expiresAt }

local function notify(source, msg, kind, duration)
    TriggerClientEvent('sunset:client:notify', source, msg, kind or 'info', duration or 5000)
end

local function getCharId(source)
    local char = exports.sunset_core:GetCharacter(source)
    return char and tonumber(char.id) or nil
end

local function getMarriage(charId)
    return MySQL.single.await([[
        SELECT * FROM marriages
        WHERE (partner1_id = ? OR partner2_id = ?) AND status = 'active'
        LIMIT 1
    ]], { charId, charId })
end

local function getPartnerId(marriage, charId)
    if tonumber(marriage.partner1_id) == charId then
        return tonumber(marriage.partner2_id)
    end
    return tonumber(marriage.partner1_id)
end

-- ═══ PROPOSE ═══

exports.sunset_core:RegisterCallback('sunset:marriage:propose', function(source, targetId)
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        return nil, 'Player not found or offline.'
    end
    if targetId == source then return nil, 'You cannot marry yourself.' end

    local myCharId = getCharId(source)
    local targetCharId = getCharId(targetId)
    if not myCharId or not targetCharId then
        return nil, 'Both players must have a loaded character.'
    end

    -- Check if either is already married
    if getMarriage(myCharId) then
        return nil, 'You are already married.'
    end
    if getMarriage(targetCharId) then
        return nil, 'That player is already married.'
    end

    -- Check pending proposal
    if PendingProposals[targetId] and PendingProposals[targetId].expiresAt > os.time() then
        return nil, 'That player already has a pending proposal.'
    end

    -- Check proximity
    local near = false
    pcall(function()
        local ped1 = GetPlayerPed(source)
        local ped2 = GetPlayerPed(targetId)
        if ped1 ~= 0 and ped2 ~= 0 then
            near = #(GetEntityCoords(ped1) - GetEntityCoords(ped2)) < 10.0
        end
    end)
    if not near then
        return nil, 'You must be near the player to propose.'
    end

    -- Charge proposal fee
    if not exports.sunset_core:RemoveMoney(source, 'cash', Cfg.proposalFee or 25000, 'marriage_proposal') then
        return nil, ('Not enough cash. Proposal fee: $%s.'):format(Cfg.proposalFee or 25000)
    end

    PendingProposals[targetId] = { from = source, expiresAt = os.time() + 120 }

    local myName = exports.sunset_core:GetPlayerDisplayName(source) or 'Someone'
    notify(targetId, ('💍 %s proposed to you! Accept or decline within 2 minutes.'):format(myName), 'success', 15000)
    notify(source, 'Proposal sent! Waiting for their answer...', 'info')

    TriggerClientEvent('sunset:marriage:proposalReceived', targetId, {
        from = source,
        fromName = myName,
    })

    return true
end)

-- ═══ ACCEPT / DECLINE ═══

exports.sunset_core:RegisterCallback('sunset:marriage:respond', function(source, accept)
    local proposal = PendingProposals[source]
    if not proposal or proposal.expiresAt < os.time() then
        return nil, 'No pending proposal.'
    end
    PendingProposals[source] = nil

    local fromSrc = proposal.from
    if not GetPlayerName(fromSrc) then
        return nil, 'The proposer is no longer online.'
    end

    if not accept then
        -- Refund proposal fee
        exports.sunset_core:AddMoney(fromSrc, 'cash', Cfg.proposalFee or 25000, 'marriage_refund')
        notify(fromSrc, 'Your proposal was declined. Fee refunded.', 'warning')
        notify(source, 'You declined the proposal.', 'info')
        return { accepted = false }
    end

    -- Double-check neither is married
    local myCharId = getCharId(source)
    local fromCharId = getCharId(fromSrc)
    if not myCharId or not fromCharId then
        return nil, 'Character not loaded.'
    end
    if getMarriage(myCharId) or getMarriage(fromCharId) then
        exports.sunset_core:AddMoney(fromSrc, 'cash', Cfg.proposalFee or 25000, 'marriage_refund')
        return nil, 'One of you is already married. Fee refunded.'
    end

    -- Create marriage
    MySQL.insert.await([[
        INSERT INTO marriages (partner1_id, partner2_id) VALUES (?, ?)
    ]], { fromCharId, myCharId })

    local myName = exports.sunset_core:GetPlayerDisplayName(source) or 'Someone'
    local fromName = exports.sunset_core:GetPlayerDisplayName(fromSrc) or 'Someone'

    -- Broadcast to all players
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('sunset:client:notify', tonumber(id),
            ('💍 %s and %s are now married! Congratulations!'):format(fromName, myName), 'success', 10000)
    end

    return { accepted = true, partner = fromName }
end)

-- ═══ DIVORCE ═══

exports.sunset_core:RegisterCallback('sunset:marriage:divorce', function(source)
    local myCharId = getCharId(source)
    if not myCharId then return nil, 'No character loaded.' end

    local marriage = getMarriage(myCharId)
    if not marriage then return nil, 'You are not married.' end

    -- Charge divorce fee
    if not exports.sunset_core:RemoveMoney(source, 'cash', Cfg.divorceFee or 10000, 'marriage_divorce') then
        return nil, ('Not enough cash. Divorce fee: $%s.'):format(Cfg.divorceFee or 10000)
    end

    MySQL.update.await('UPDATE marriages SET status = "divorced" WHERE id = ?', { marriage.id })

    local partnerId = getPartnerId(marriage, myCharId)
    -- Notify partner if online
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if getCharId(src) == partnerId then
            notify(src, '💔 Your partner filed for divorce. You are now single.', 'warning', 10000)
        end
    end

    notify(source, 'Divorce finalized. You are now single.', 'info')
    return true
end)

-- ═══ STATUS ══

exports.sunset_core:RegisterCallback('sunset:marriage:status', function(source)
    local myCharId = getCharId(source)
    if not myCharId then return nil end

    local marriage = getMarriage(myCharId)
    if not marriage then
        return { married = false, hasProposal = PendingProposals[source] ~= nil }
    end

    local partnerId = getPartnerId(marriage, myCharId)
    local partnerName = 'Unknown'
    local partnerOnline = false
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if getCharId(src) == partnerId then
            partnerName = exports.sunset_core:GetPlayerDisplayName(src) or 'Unknown'
            partnerOnline = true
            break
        end
    end

    return {
        married = true,
        partnerName = partnerName,
        partnerOnline = partnerOnline,
        marriedAt = tostring(marriage.married_at or ''),
    }
end)

AddEventHandler('playerDropped', function()
    PendingProposals[source] = nil
end)

print('^2[sunset_marriage]^7 Marriage system online')
