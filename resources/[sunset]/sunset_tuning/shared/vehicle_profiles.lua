-- Explicit profiles for every player-obtainable dealership vehicle + known EV/motorcycle references.
-- Add-on vehicles: add an entry here before enabling combustion features.

SunsetTuning.VehicleProfiles = {
    -- Dealership compacts
    blista   = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'fwd', archetype = 'compact', limits = { power = 100, topSpeed = 28, shiftSpeed = 55 } },
    issi2    = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'fwd', archetype = 'compact', limits = { power = 100, topSpeed = 26, shiftSpeed = 52 } },
    prairie  = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'fwd', archetype = 'compact', limits = { power = 100, topSpeed = 30, shiftSpeed = 58 } },

    -- Sedans
    asea       = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'fwd', archetype = 'sedan', limits = { power = 100, topSpeed = 32, shiftSpeed = 58 } },
    tailgater  = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'rwd', archetype = 'sedan', limits = { power = 100, topSpeed = 38, shiftSpeed = 62 } },

    -- Sport
    buffalo = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'rwd', archetype = 'muscle', limits = { power = 100, topSpeed = 42, shiftSpeed = 68 } },
    sultan  = { propulsion = 'petrol', induction = 'turbo', drivetrain = 'awd', archetype = 'sport', limits = { power = 100, topSpeed = 45, shiftSpeed = 72 } },
    comet2  = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'rwd', archetype = 'sport', limits = { power = 100, topSpeed = 48, shiftSpeed = 75 } },

    -- SUV
    baller2 = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'awd', archetype = 'suv', limits = { power = 100, topSpeed = 35, shiftSpeed = 58 } },
    dubsta  = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'awd', archetype = 'suv', limits = { power = 100, topSpeed = 36, shiftSpeed = 60 } },

    -- Super
    adder = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'awd', archetype = 'super', limits = { power = 100, topSpeed = 58, shiftSpeed = 82 } },

    -- Motorcycle
    bati = { propulsion = 'petrol', induction = 'naturally_aspirated', drivetrain = 'rwd', archetype = 'motorcycle', limits = { power = 100, topSpeed = 52, shiftSpeed = 78 } },

    -- Reference EVs (admin givecar / future catalog)
    raiden    = { propulsion = 'electric', induction = 'electric', drivetrain = 'awd', archetype = 'ev_sport', limits = { power = 100, topSpeed = 50, regen = 80, throttle = 85 } },
    cyclone   = { propulsion = 'electric', induction = 'electric', drivetrain = 'awd', archetype = 'ev_super', limits = { power = 100, topSpeed = 60, regen = 75, throttle = 90 } },
    tezeract  = { propulsion = 'electric', induction = 'electric', drivetrain = 'awd', archetype = 'ev_super', limits = { power = 100, topSpeed = 62, regen = 70, throttle = 92 } },
    neon      = { propulsion = 'electric', induction = 'electric', drivetrain = 'awd', archetype = 'ev_sport', limits = { power = 100, topSpeed = 52, regen = 78, throttle = 88 } },
    imorgon   = { propulsion = 'electric', induction = 'electric', drivetrain = 'awd', archetype = 'ev_sport', limits = { power = 100, topSpeed = 54, regen = 76, throttle = 86 } },
    voltic    = { propulsion = 'electric', induction = 'electric', drivetrain = 'rwd', archetype = 'ev_roadster', limits = { power = 100, topSpeed = 55, regen = 72, throttle = 90 } },
    khamelion = { propulsion = 'hybrid', induction = 'electric', drivetrain = 'awd', archetype = 'ev_sport', limits = { power = 100, topSpeed = 48, regen = 85, throttle = 80 } },
}

-- Known combustion models that ship with turbo from factory (allow anti-lag only with turbo hardware or factory turbo)
SunsetTuning.FactoryTurboModels = {
    sultan = true,
}
