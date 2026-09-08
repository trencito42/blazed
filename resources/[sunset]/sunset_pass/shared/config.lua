SunsetPass = SunsetPass or {}

SunsetPass.SeasonId = 'season_01'
SunsetPass.SeasonLabel = 'Season 01'
SunsetPass.XpPerTier = 500
SunsetPass.PremiumCost = 250

SunsetPass.Tiers = {
    {
        level = 1,
        free = { type = 'cash', amount = 800, label = '$800 Cash', icon = 'cash' },
        premium = { type = 'premium_points', amount = 15, label = '15 Blaze Points', icon = 'coins' },
    },
    {
        level = 2,
        free = { type = 'item', item = 'water', count = 5, label = 'Water x5', icon = 'water_bottle' },
        premium = { type = 'item', item = 'lockpick', count = 2, label = 'Lockpick x2', icon = 'lockpick' },
    },
    {
        level = 3,
        free = { type = 'item', item = 'bread', count = 5, label = 'Bread x5', icon = 'bread' },
        premium = { type = 'bank', amount = 4000, label = '$4,000 Bank', icon = 'bank' },
    },
    {
        level = 4,
        free = { type = 'item', item = 'bandage', count = 3, label = 'Bandage x3', icon = 'bandage' },
        premium = { type = 'premium_points', amount = 35, label = '35 Blaze Points', icon = 'coins' },
    },
    {
        level = 5,
        free = { type = 'bank', amount = 3000, label = '$3,000 Bank', icon = 'bank' },
        premium = { type = 'cash', amount = 6000, label = '$6,000 Cash', icon = 'cash' },
    },
    {
        level = 6,
        free = { type = 'premium_points', amount = 10, label = '10 Blaze Points', icon = 'coins' },
        premium = { type = 'item', item = 'bandage', count = 5, label = 'Bandage x5', icon = 'bandage' },
    },
}

SunsetPass.Missions = {
    {
        id = 'robbery_complete',
        type = 'weekly',
        title = 'Jewelry Run',
        description = 'Complete a luxury-store robbery and sell loot at the fence.',
        goal = 1,
        xp = 500,
        icon = 'golden_watch',
    },
    {
        id = 'fish_catch',
        type = 'daily',
        title = 'Angler',
        description = 'Catch 10 fish while on a fisherman shift.',
        goal = 10,
        xp = 400,
        icon = 'cooked_fish',
    },
    {
        id = 'courier_deliveries',
        type = 'daily',
        title = 'Dedicated Courier',
        description = 'Complete 5 courier deliveries.',
        goal = 5,
        xp = 600,
        icon = 'backpack',
    },
    {
        id = 'paydays',
        type = 'daily',
        title = 'Steady Earner',
        description = 'Receive 2 paydays.',
        goal = 2,
        xp = 350,
        icon = 'cash_stack',
    },
}

