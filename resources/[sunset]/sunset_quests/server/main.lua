-- ============================================================
--  sunset_quests — canonical quest/progression service
--  DOMAIN_OWNERSHIP: owns character_quests. Other resources emit
--  gameplay events; this service advances quests and grants
--  rewards atomically through sunset_core (never writes money).
-- ============================================================

-- In-memory active-quest cache per character: [charId] = { [questKey] = row }
local Cache = {}

local function decodeProgress(row) return row end

local function loadCharacterQuests(charId)
    local rows = MySQL.query.await(
        'SELECT quest_key, chain_key, stage, progress, target, status FROM character_quests WHERE character_id = ?',
        { charId }) or {}
    local map = {}
    for _, r in ipairs(rows) do map[r.quest_key] = r end
    Cache[charId] = map
    return map
end

local function getQuestState(charId, questKey)
    local map = Cache[charId] or loadCharacterQuests(charId)
    return map[questKey]
end

local function chainUnlocked(charId, chain)
    if not chain.requiresChain then return true end
    local req = Sunset.QuestChains[chain.requiresChain]
    if not req then return true end
    -- required chain complete when all its quests are claimed/complete
    local map = Cache[charId] or loadCharacterQuests(charId)
    for _, q in ipairs(req.quests or {}) do
        local st = map[q.key]
        if not st or st.status ~= 'claimed' then return false end
    end
    return true
end

-- Start (activate) the next available quest in an unlocked, enabled chain.
local function ensureActiveQuest(charId)
    local map = Cache[charId] or loadCharacterQuests(charId)
    -- Build ordered list of enabled chains
    local chains = {}
    for key, chain in pairs(Sunset.QuestChains) do
        if chain.enabled then chains[#chains + 1] = { key = key, chain = chain } end
    end
    table.sort(chains, function(a, b) return (a.chain.order or 99) < (b.chain.order or 99) end)

    for _, entry in ipairs(chains) do
        local chain = entry.chain
        if chainUnlocked(charId, chain) then
            for _, quest in ipairs(chain.quests or {}) do
                local st = map[quest.key]
                if not st then
                    -- not started: activate it
                    local target = (quest.objectives and quest.objectives[1] and quest.objectives[1].target) or 1
                    MySQL.insert.await([[
                        INSERT INTO character_quests (character_id, quest_key, chain_key, stage, progress, target, status)
                        VALUES (?, ?, ?, 0, 0, ?, 'active')
                    ]], { charId, quest.key, entry.key, target })
                    map[quest.key] = { quest_key = quest.key, chain_key = entry.key, stage = 0,
                        progress = 0, target = target, status = 'active' }
                    return quest.key
                elseif st.status == 'active' then
                    return quest.key -- already in progress
                end
                -- if claimed, continue to next quest in chain
            end
        end
    end
    return nil
end

-- Public API ---------------------------------------------------

function StartQuest(source, questKey)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'No character' end
    local def = Sunset.QuestIndex[questKey]
    if not def or not def.chain.enabled then return false, 'Unknown quest' end
    local existing = getQuestState(char.id, questKey)
    if existing then return true end -- idempotent
    ensureActiveQuest(char.id)
    return true
end
exports('StartQuest', StartQuest)

-- Advance progress for an event type. Called by internal event wiring below
-- AND available to other resources via the AddProgress export.
function AddProgress(source, eventType, amount, context)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    context = type(context) == 'table' and context or {}

    local map = Cache[char.id] or loadCharacterQuests(char.id)
    local advanced = false
    for questKey, st in pairs(map) do
        if st.status == 'active' then
            local def = Sunset.QuestIndex[questKey]
            local obj = def and def.quest.objectives and def.quest.objectives[1]
            if obj and obj.type == eventType then
                -- optional sub-filter (e.g. license type)
                if (not obj.license or obj.license == context.license) then
                    local newProgress = math.min(st.target, (st.progress or 0) + amount)
                    if newProgress ~= st.progress then
                        st.progress = newProgress
                        advanced = true
                        if newProgress >= st.target then
                            st.status = 'complete'
                            MySQL.update.await(
                                "UPDATE character_quests SET progress = ?, status = 'complete', completed_at = NOW() WHERE character_id = ? AND quest_key = ?",
                                { newProgress, char.id, questKey })
                            TriggerClientEvent('sunset:quests:objectiveComplete', source, questKey)
                            local label = def.quest.label or questKey
                            TriggerClientEvent('sunset:client:notify', source,
                                ('Quest complete: %s — open /quests to claim.'):format(label), 'success', 7000)
                        else
                            MySQL.update.await(
                                'UPDATE character_quests SET progress = ? WHERE character_id = ? AND quest_key = ?',
                                { newProgress, char.id, questKey })
                            TriggerClientEvent('sunset:quests:progress', source, questKey, newProgress, st.target)
                        end
                    end
                end
            end
        end
    end

    if not advanced then
        -- Make sure a quest is active so progress isn't silently dropped on
        -- a freshly-loaded character whose first quest wasn't created yet.
        ensureActiveQuest(char.id)
    end
    return advanced
end
exports('AddProgress', AddProgress)

function CompleteObjective(source, questKey)
    return AddProgress(source, questKey, 1)
end
exports('CompleteObjective', CompleteObjective)

function IsQuestComplete(source, questKey)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false end
    local st = getQuestState(char.id, questKey)
    return st ~= nil and (st.status == 'complete' or st.status == 'claimed')
end
exports('IsQuestComplete', IsQuestComplete)

function GetProgress(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    local map = Cache[char.id] or loadCharacterQuests(char.id)
    ensureActiveQuest(char.id)
    map = Cache[char.id] or {}
    local out = {}
    for questKey, st in pairs(map) do
        local def = Sunset.QuestIndex[questKey]
        out[#out + 1] = {
            questKey = questKey,
            chainKey = st.chain_key,
            chainLabel = def and def.chain.label or st.chain_key,
            label = def and def.quest.label or questKey,
            description = def and def.quest.description or '',
            progress = st.progress or 0,
            target = st.target or 1,
            status = st.status,
            objectiveLabel = def and def.quest.objectives and def.quest.objectives[1] and def.quest.objectives[1].label or '',
            reward = def and def.quest.reward or nil,
        }
    end
    table.sort(out, function(a, b)
        if a.status == b.status then return a.questKey < b.questKey end
        local rank = { active = 1, complete = 2, claimed = 3 }
        return (rank[a.status] or 9) < (rank[b.status] or 9)
    end)
    return out
end
exports('GetProgress', GetProgress)

-- Claim reward atomically through core (INVARIANT M2: money via API + ledger).
function ClaimReward(source, questKey)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return false, 'No character' end
    local st = getQuestState(char.id, questKey)
    if not st then return false, 'Quest not started.' end
    if st.status == 'claimed' then return false, 'Reward already claimed.' end
    if st.status ~= 'complete' then return false, 'Quest not complete yet.' end

    local def = Sunset.QuestIndex[questKey]
    local reward = def and def.quest.reward or {}

    -- Mark claimed FIRST (guarded) so concurrent claims can't double-pay.
    local changed = MySQL.update.await(
        "UPDATE character_quests SET status = 'claimed', claimed_at = NOW() WHERE character_id = ? AND quest_key = ? AND status = 'complete'",
        { char.id, questKey })
    if not changed or changed < 1 then
        return false, 'Reward already claimed.'
    end
    st.status = 'claimed'

    if reward.money and reward.money > 0 then
        exports.sunset_core:AddMoney(source, 'bank', reward.money, reward.reason or ('quest_' .. questKey))
    end
    if reward.xp and reward.xp > 0 then
        pcall(function() exports.sunset_core:AddXP(source, reward.xp) end)
    end
    if reward.rp and reward.rp > 0 then
        pcall(function() exports.sunset_core:AddRespectPoints(source, reward.rp) end)
    end

    -- Unlock the next quest in the chain / next chain.
    ensureActiveQuest(char.id)
    if def and def.quest.unlocksChain then
        TriggerClientEvent('sunset:client:notify', source,
            ('New quest chain unlocked: %s'):format(Sunset.QuestChains[def.quest.unlocksChain] and Sunset.QuestChains[def.quest.unlocksChain].label or def.quest.unlocksChain),
            'success', 8000)
    end
    TriggerClientEvent('sunset:quests:claimed', source, questKey, reward)
    return true, reward
end
exports('ClaimReward', ClaimReward)

-- Callbacks ----------------------------------------------------
exports.sunset_core:RegisterCallback('sunset:quests:list', function(source)
    return GetProgress(source)
end)

exports.sunset_core:RegisterCallback('sunset:quests:claim', function(source, questKey)
    local ok, res = ClaimReward(source, tostring(questKey or ''))
    if ok then return true end
    return nil, type(res) == 'string' and res or 'Could not claim reward.'
end)

-- Lifecycle ----------------------------------------------------
AddEventHandler('sunset:server:characterSelected', function(source, characterId)
    local charId = tonumber(characterId)
    if not charId then
        local char = exports.sunset_core:GetCharacter(source)
        charId = char and char.id
    end
    if not charId then return end
    Cache[charId] = nil -- force reload
    loadCharacterQuests(charId)
    ensureActiveQuest(charId)
end)

AddEventHandler('playerDropped', function()
    local ok, char = pcall(function() return exports.sunset_core:GetCharacter(source) end)
    if ok and char and char.id then Cache[char.id] = nil end
end)

-- ============================================================
--  Event wiring: translate gameplay events into quest progress.
--  Each is guarded so a missing dependency never errors.
-- ============================================================
local function progressSource(src, eventType, amount, ctx)
    if not src or src == 0 then return end
    pcall(AddProgress, src, eventType, amount or 1, ctx)
end

AddEventHandler('sunset:quest:progress', function(charId, eventType, amount, ctx)
    -- charId-based emitter (systems that know charId but not source)
    charId = tonumber(charId)
    if not charId then return end
    -- find online source for charId
    for _, pid in ipairs(GetPlayers()) do
        local s = tonumber(pid)
        local c = exports.sunset_core:GetCharacter(s)
        if c and c.id == charId then
            progressSource(s, eventType, amount, ctx)
            return
        end
    end
end)

print('^2[sunset_quests]^7 quest service online')
