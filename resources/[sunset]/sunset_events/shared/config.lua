-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Server Events (shared/config.lua)
-- ═══════════════════════════════════════════════════════════════

SunsetEvents = SunsetEvents or {}

SunsetEvents.Config = {
    -- Event schedule (hour = server hour, 0-23)
    schedule = {
        { hour = 18, type = 'car_meet', label = 'Car Meet', duration = 3600 },
        { hour = 20, type = 'race_night', label = 'Race Night', duration = 3600 },
        { hour = 14, type = 'fishing_tournament', label = 'Fishing Tournament', duration = 3600 },
    },

    -- Event locations
    locations = {
        car_meet = vector3(-1060.00, -2580.00, 20.00),   -- LS Customs parking
        race_night = vector3(-75.00, -826.00, 243.00),     -- Racing start
        fishing_tournament = vector3(-1593.23, 5207.74, 3.31), -- Paleto Bay
    },

    -- Rewards
    rewards = {
        car_meet = { cash = 5000, xp = 200 },
        race_night = { cash = 10000, xp = 300 },
        fishing_tournament = { cash = 7500, xp = 250 },
    },

    -- Announcement interval (seconds)
    announceInterval = 300,
}
