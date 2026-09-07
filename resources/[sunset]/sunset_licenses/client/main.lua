local blips = {}
local activeTest = nil
local licenseCache = {}
local cacheAt = {}

local function notify(msg, kind)
    exports.sunset_ui:Notify(msg, kind or 'info', 7000)
end

local function drawMarker(pos, r, g, b)
    DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        1.8, 1.8, 1.0, r or 0, g or 200, b or 80, 120, false, false, 2, false, nil, nil, false)
end

local function setupBlips()
    for key, facility in pairs(SunsetLicenses.Facilities or {}) do
        if facility.blip and facility.marker then
            local blip = AddBlipForCoord(facility.marker.x, facility.marker.y, facility.marker.z)
            SetBlipSprite(blip, facility.blip.sprite or 1)
            SetBlipColour(blip, facility.blip.color or 2)
            SetBlipScale(blip, facility.blip.scale or 0.85)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(facility.label or key)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end

function HasLicense(licenseType)
    local now = GetGameTimer()
    if licenseCache[licenseType] ~= nil and (now - (cacheAt[licenseType] or 0)) < 30000 then
        return licenseCache[licenseType]
    end
    local ok = Sunset.AwaitCallback('sunset:license:has', licenseType)
    licenseCache[licenseType] = ok == true
    cacheAt[licenseType] = now
    return licenseCache[licenseType]
end

function IsInLicenseTest(licenseType)
    if not activeTest then return false end
    if licenseType then return activeTest.licenseType == tostring(licenseType) end
    return true
end

exports('HasLicense', HasLicense)
exports('IsInLicenseTest', IsInLicenseTest)
exports('IsInLocalTest', IsInLicenseTest)

local function startAtFacility(facility)
    if activeTest then
        return notify('Finish or cancel your current license test first.', 'error')
    end
    local licenseType = facility.license
    local theory, err = Sunset.AwaitCallback('sunset:license:startTheory', licenseType)
    if not theory then
        return notify(err or 'Could not start theory exam.', 'error')
    end
    activeTest = { licenseType = licenseType, phase = 'theory' }
    if theory.examFee and theory.examFee > 0 then
        notify(('Exam fee paid: $%d'):format(theory.examFee), 'info', 5000)
    end
    OpenTheoryQuiz(licenseType, theory)
end

local examOfferCache = {}

CreateThread(function()
    Wait(2000)
    setupBlips()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        for _, facility in pairs(SunsetLicenses.Facilities or {}) do
            if facility.marker then
                local dist = #(coords - facility.marker)
                if dist < 40.0 then
                    sleep = 0
                    if not activeTest then
                        drawMarker(facility.marker, 50, 200, 80)
                    end
                    if dist < (facility.markerRadius or 2.5) and not activeTest then
                        local licenseType = facility.license
                        local now = GetGameTimer()
                        local cached = examOfferCache[licenseType]
                        if not cached or (now - cached.at) > 15000 then
                            local offer = Sunset.AwaitCallback('sunset:license:getExamOffer', licenseType)
                            if offer then
                                examOfferCache[licenseType] = { at = now, fee = offer.fee or 0 }
                                cached = examOfferCache[licenseType]
                            end
                        end
                        local fee = cached and cached.fee or 0
                        local feeText = fee > 0 and (' — fee $%d'):format(fee) or ''
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentString(('Press ~INPUT_CONTEXT~ — %s exam%s'):format(
                            facility.label or 'License', feeText))
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustReleased(0, 38) then
                            startAtFacility(facility)
                            Wait(500)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('sunset:licenses:beginPractical', function(licenseType, payload)
    licenseCache[licenseType] = nil
    cacheAt[licenseType] = nil
    activeTest = { licenseType = licenseType, data = payload }
    StartPracticalTest(licenseType, payload)
end)

RegisterNetEvent('sunset:licenses:testAbort', function()
    licenseCache = {}
    cacheAt = {}
    activeTest = nil
    CleanupPracticalTest()
end)

RegisterNetEvent('sunset:licenses:testComplete', function()
    licenseCache = {}
    cacheAt = {}
    activeTest = nil
    CleanupPracticalTest()
end)

RegisterNetEvent('sunset:licenses:refresh', function()
    licenseCache = {}
    cacheAt = {}
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    CleanupPracticalTest()
end)
