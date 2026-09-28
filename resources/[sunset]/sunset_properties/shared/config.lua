SunsetProperties = SunsetProperties or {}

SunsetProperties.RentMin = 50
SunsetProperties.RentMax = 5000
SunsetProperties.DefaultRentPrice = 500
SunsetProperties.MaxRentersMin = 1
SunsetProperties.MaxRentersMax = 10
SunsetProperties.AdminLevel = 3
SunsetProperties.BucketBase = 20000
-- 0 = unlimited owned houses per character
SunsetProperties.MaxOwnedPerCharacter = 0

-- Stable GTA Online interiors. Routing buckets isolate each physical house.
SunsetProperties.Interiors = {
    standard        = { label = 'Standard Apartment', coords = vector4(266.03, -1007.26, -101.01, 357.0) },
    motel           = { label = 'Motel Room', coords = vector4(151.31, -1007.74, -99.00, 340.0) },
    modern          = { label = 'Modern Apartment', coords = vector4(-786.87, 315.75, 217.64, 268.0) },
    highend         = { label = 'High-end Apartment', coords = vector4(-774.17, 342.04, 196.69, 90.0) },
    executive       = { label = 'Executive Suite', coords = vector4(-787.16, 315.81, 187.91, 270.0) },
    mansion         = { label = 'Luxury Mansion', coords = vector4(-774.17, 342.04, 196.69, 90.0) },
    villa           = { label = 'Vinewood Villa', coords = vector4(-787.16, 315.81, 187.91, 270.0) },
    penthouse       = { label = 'Casino Penthouse', coords = vector4(964.03, 58.73, 112.55, 59.0) },
    stilt           = { label = 'Stilt House', coords = vector4(373.88, 412.37, 145.7, 180.0) },
    low             = { label = 'Low-end Apartment', coords = vector4(261.45, -998.81, -99.01, 90.0) },
    low_apartment   = { label = 'Low-end Apartment', coords = vector4(261.45, -998.81, -99.01, 90.0) },
    small_apartment = { label = 'Small Apartment', coords = vector4(261.45, -998.81, -99.01, 90.0) },
    medium          = { label = 'Medium House', coords = vector4(266.03, -1007.26, -101.01, 357.0) },
    medium_house    = { label = 'Medium House', coords = vector4(266.03, -1007.26, -101.01, 357.0) },
}
