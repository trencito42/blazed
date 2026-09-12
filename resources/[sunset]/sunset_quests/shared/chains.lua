Sunset = Sunset or {}

-- ============================================================
--  Quest chains — docs/product/RPG_PROGRESSION.md §2
--  Data-driven: a chain is an ordered list of quests; each quest
--  has objectives driven by server events (Sunset.QuestEvents).
--  `enabled=false` chains are DESIGNED but not shipped yet
--  (Phase 7 decision: onboarding + first_job + driving only).
-- ============================================================

-- Event types emitted by gameplay systems (see server/events wiring):
--   job_hired, job_shift_completed, license_obtained, vehicle_purchased,
--   property_rented, first_trade, sms_sent, contact_added, faction_joined,
--   help_opened, spawned_in_city
Sunset.QuestChains = {
    onboarding = {
        label = 'Welcome to Los Santos',
        description = 'Learn the basics of life in the city.',
        order = 1,
        enabled = true,
        quests = {
            {
                key = 'onb_orientation',
                label = 'City Orientation',
                description = 'Open the help menu (/help) and the M menu to learn your controls.',
                objectives = {
                    { type = 'help_opened', target = 1, label = 'Open the help menu (/help)' },
                },
                reward = { money = 100, xp = 20, rp = 1, reason = 'quest_onboarding' },
            },
            {
                key = 'onb_jobcenter',
                label = 'Find Work',
                description = 'Visit the Job Center at City Hall and get hired for any job.',
                objectives = {
                    { type = 'job_hired', target = 1, label = 'Get hired at the Job Center' },
                },
                reward = { money = 150, xp = 30, rp = 1, reason = 'quest_jobcenter' },
                unlocksChain = 'first_job',
            },
        },
    },

    first_job = {
        label = 'Earning a Living',
        description = 'Complete honest work and earn your first paycheck.',
        order = 2,
        enabled = true,
        requiresChain = 'onboarding',
        quests = {
            {
                key = 'fj_first_shift',
                label = 'First Shift',
                description = 'Complete one work shift (delivery, catch, collection...).',
                objectives = {
                    { type = 'job_shift_completed', target = 1, label = 'Complete a work shift' },
                },
                reward = { money = 250, xp = 40, rp = 2, reason = 'quest_first_shift' },
            },
            {
                key = 'fj_dedication',
                label = 'Dedication',
                description = 'Complete 5 work shifts to prove your worth.',
                objectives = {
                    { type = 'job_shift_completed', target = 5, label = 'Complete 5 work shifts' },
                },
                reward = { money = 500, xp = 60, rp = 3, reason = 'quest_dedication' },
                unlocksChain = 'driving',
            },
        },
    },

    driving = {
        label = 'Behind the Wheel',
        description = 'Get your driving license and your first set of wheels.',
        order = 3,
        enabled = true,
        requiresChain = 'first_job',
        quests = {
            {
                key = 'drv_license',
                label = 'Driving License',
                description = 'Pass the driving exam at the LSSI to obtain your license.',
                objectives = {
                    { type = 'license_obtained', target = 1, license = 'driving', label = 'Obtain a driving license' },
                },
                reward = { money = 300, xp = 50, rp = 2, reason = 'quest_license' },
            },
            {
                key = 'drv_first_car',
                label = 'First Car',
                description = 'Purchase a vehicle from the dealership.',
                objectives = {
                    { type = 'vehicle_purchased', target = 1, label = 'Buy a vehicle' },
                },
                reward = { money = 750, xp = 80, rp = 3, reason = 'quest_first_car' },
            },
        },
    },

    -- ── DESIGNED, NOT YET ENABLED (future phases) ────────────────
    social = {
        label = 'Making Connections', order = 4, enabled = false, requiresChain = 'driving',
        quests = {
            { key = 'soc_contact', label = 'Stay in Touch', description = 'Add another player as a phone contact.',
              objectives = { { type = 'contact_added', target = 1, label = 'Add a contact' } },
              reward = { money = 100, xp = 20, rp = 1, reason = 'quest_contact' } },
            { key = 'soc_trade', label = 'A Deal is a Deal', description = 'Complete a trade with another player.',
              objectives = { { type = 'first_trade', target = 1, label = 'Complete a player trade' } },
              reward = { money = 200, xp = 30, rp = 2, reason = 'quest_trade' }, unlocksChain = 'housing' },
        },
    },
    housing = {
        label = 'A Place to Call Home', order = 5, enabled = false, requiresChain = 'social',
        quests = {
            { key = 'hou_rent', label = 'First Rental', description = 'Rent a property to call home.',
              objectives = { { type = 'property_rented', target = 1, label = 'Rent a property' } },
              reward = { money = 400, xp = 50, rp = 2, reason = 'quest_rental' } },
        },
    },
    faction = {
        label = 'Joining the Ranks', order = 6, enabled = false, requiresChain = 'housing',
        quests = {
            { key = 'fac_join', label = 'Application', description = 'Join a faction.',
              objectives = { { type = 'faction_joined', target = 1, label = 'Join a faction' } },
              reward = { money = 300, xp = 60, rp = 3, reason = 'quest_faction' } },
        },
    },
    advanced = {
        label = 'Master of Your Craft', order = 7, enabled = false, requiresChain = 'faction',
        quests = {},
    },
    criminal = {
        label = 'The Other Side', order = 8, enabled = false, requiresChain = 'advanced',
        quests = {},
    },
    clan = {
        label = 'Blood and Territory', order = 9, enabled = false, requiresChain = 'criminal',
        quests = {},
    },
}

-- Flatten quest lookup: questKey -> {chain, quest, chainKey}
Sunset.QuestIndex = {}
for chainKey, chain in pairs(Sunset.QuestChains) do
    for i, quest in ipairs(chain.quests or {}) do
        Sunset.QuestIndex[quest.key] = { chainKey = chainKey, chain = chain, quest = quest, order = i }
    end
end
