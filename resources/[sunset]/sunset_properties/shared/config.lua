SunsetProperties = SunsetProperties or {}

SunsetProperties.RentMin = 50
SunsetProperties.RentMax = 5000
SunsetProperties.MaxRentersMin = 1
SunsetProperties.MaxRentersMax = 10
SunsetProperties.AdminLevel = 3
SunsetProperties.BucketBase = 20000

-- Stable GTA Online interiors. Routing buckets isolate each physical house.
SunsetProperties.Interiors = {
    standard = { label = 'Standard Apartment', coords = vector4(266.03, -1007.26, -101.01, 357.0) },
    motel = { label = 'Motel Room', coords = vector4(151.31, -1007.74, -99.00, 340.0) },
    modern = { label = 'Modern Apartment', coords = vector4(-786.87, 315.75, 217.64, 268.0) },
    highend = { label = 'High-end Apartment', coords = vector4(-774.17, 342.04, 196.69, 90.0) },
    executive = { label = 'Executive Suite', coords = vector4(-787.16, 315.81, 187.91, 270.0) },
}
